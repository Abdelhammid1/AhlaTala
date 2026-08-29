"""`flask seed` CLI — populates the DB with an admin user, 3 categories, and sample items.

The sample data exercises every option-group kind so that E1 acceptance can be
run without having to touch the admin panel first.
"""
from __future__ import annotations

from decimal import Decimal

from datetime import datetime, timezone

import click
from flask import Flask
from sqlalchemy.orm import selectinload

from app.extensions import db
from app.models import (
    AdminUser,
    Category,
    Customer,
    DeviceToken,
    DiscountCode,
    DiscountKind,
    FulfillmentType,
    Item,
    ItemCrossSell,
    LoyaltyLedger,
    LoyaltySettings,
    Notification,
    NotificationDelivery,
    NotificationTarget,
    Offer,
    Option,
    OptionGroup,
    OptionGroupKind,
    Order,
    OrderLine,
    OrderLineSelection,
    OrderStatus,
    OtpCode,
    PaymentMethod,
    SavedAddress,
    SelectionType,
)
from app.observers import recompute_item_display_price


def register_cli(app: Flask) -> None:
    @app.cli.command("seed")
    @click.option("--wipe", is_flag=True, help="Delete existing rows first.")
    def seed_cmd(wipe: bool) -> None:  # noqa: D401 - Click command
        """Seed the database with sample menu data."""
        if wipe:
            _wipe_all()
        _seed_admin(app)
        _seed_loyalty_defaults()
        _seed_menu()
        if wipe:
            _seed_discount_codes()
            _seed_sample_customer_and_orders()
            _seed_offers()
            _seed_welcome_notification()
        # Bulk-insert order can leave the before_flush observer with a stale
        # `item.option_groups` view (pending inserts not yet visible via the
        # relationship), so flush + expire, then re-query each item with
        # eager-loaded groups/options and recompute cleanly.
        db.session.flush()
        db.session.expire_all()
        items = (
            db.session.query(Item)
            .options(selectinload(Item.option_groups).selectinload(OptionGroup.options))
            .all()
        )
        for item in items:
            recompute_item_display_price(item)
        db.session.commit()
        click.echo("✅ Seed complete.")


# ---------- helpers ----------


def _wipe_all() -> None:
    # Cascades from Category -> Item -> OptionGroup -> Option are handled by FK ON DELETE CASCADE
    db.session.query(OtpCode).delete()
    db.session.query(SavedAddress).delete()
    db.session.query(NotificationDelivery).delete()
    db.session.query(Notification).delete()
    db.session.query(DeviceToken).delete()
    db.session.query(Offer).delete()
    db.session.query(LoyaltyLedger).delete()
    db.session.query(OrderLineSelection).delete()
    db.session.query(OrderLine).delete()
    db.session.query(Order).delete()
    db.session.query(DiscountCode).delete()
    db.session.query(Customer).delete()
    db.session.query(LoyaltySettings).delete()
    db.session.query(ItemCrossSell).delete()
    db.session.query(Option).delete()
    db.session.query(OptionGroup).delete()
    db.session.query(Item).delete()
    db.session.query(Category).delete()
    db.session.query(AdminUser).delete()
    db.session.commit()


def _seed_admin(app: Flask) -> None:
    email = app.config["ADMIN_EMAIL"]
    if db.session.query(AdminUser).filter_by(email=email).first():
        return
    admin = AdminUser(email=email, display_name="Admin")
    admin.set_password(app.config["ADMIN_PASSWORD"])
    db.session.add(admin)


def _seed_menu() -> None:
    # Don't reseed if there are already categories
    if db.session.query(Category).count() > 0:
        return

    pizza = Category(name_ar="بيتزا", name_en="Pizza", sort_order=1, is_active=True)
    pasta = Category(name_ar="باستا", name_en="Pasta", sort_order=2, is_active=True)
    drinks = Category(name_ar="مشروبات", name_en="Drinks", sort_order=3, is_active=True)
    db.session.add_all([pizza, pasta, drinks])
    db.session.flush()  # get PKs

    # --- Pizza: exercises variant + size + remove + add ---
    margherita = Item(
        category_id=pizza.id,
        name_ar="بيتزا مارجريتا",
        name_en="Margherita Pizza",
        description_ar="عجينة إيطالية طازجة مع صلصة طماطم وجبنة موزاريلا وريحان.",
        base_price=Decimal("30.00"),
        calories=850,
        sort_order=1,
    )
    db.session.add(margherita)
    db.session.flush()

    # variant (choose type) — single, required, changes price + image
    g_variant = OptionGroup(
        item_id=margherita.id,
        name_ar="نوع البيتزا",
        kind=OptionGroupKind.variant,
        selection_type=SelectionType.single,
        is_required=True,
        sort_order=1,
    )
    db.session.add(g_variant)
    db.session.flush()
    db.session.add_all([
        Option(option_group_id=g_variant.id, name_ar="مارجريتا", price_delta=Decimal("0"), is_default=True, sort_order=1),
        Option(option_group_id=g_variant.id, name_ar="بيبروني", price_delta=Decimal("10.00"), sort_order=2),
        Option(option_group_id=g_variant.id, name_ar="خضار", price_delta=Decimal("5.00"), sort_order=3),
    ])

    # size — single, required, changes price
    g_size = OptionGroup(
        item_id=margherita.id,
        name_ar="الحجم",
        kind=OptionGroupKind.size,
        selection_type=SelectionType.single,
        is_required=True,
        sort_order=2,
    )
    db.session.add(g_size)
    db.session.flush()
    db.session.add_all([
        Option(option_group_id=g_size.id, name_ar="صغير", price_delta=Decimal("0"), is_default=True, sort_order=1),
        Option(option_group_id=g_size.id, name_ar="وسط", price_delta=Decimal("12.00"), sort_order=2),
        Option(option_group_id=g_size.id, name_ar="كبير", price_delta=Decimal("22.00"), sort_order=3),
    ])

    # remove — multi, optional, price_delta=0
    g_remove = OptionGroup(
        item_id=margherita.id,
        name_ar="حذف مكونات",
        kind=OptionGroupKind.remove,
        selection_type=SelectionType.multi,
        is_required=False,
        sort_order=3,
    )
    db.session.add(g_remove)
    db.session.flush()
    db.session.add_all([
        Option(option_group_id=g_remove.id, name_ar="بدون زيتون", price_delta=Decimal("0"), sort_order=1),
        Option(option_group_id=g_remove.id, name_ar="بدون جبنة", price_delta=Decimal("0"), sort_order=2),
        Option(option_group_id=g_remove.id, name_ar="بدون طماطم", price_delta=Decimal("0"), sort_order=3),
    ])

    # add — multi, optional, price_delta > 0
    g_add = OptionGroup(
        item_id=margherita.id,
        name_ar="إضافات",
        kind=OptionGroupKind.add,
        selection_type=SelectionType.multi,
        is_required=False,
        sort_order=4,
    )
    db.session.add(g_add)
    db.session.flush()
    db.session.add_all([
        Option(option_group_id=g_add.id, name_ar="جبنة إضافية", price_delta=Decimal("5.00"), sort_order=1),
        Option(option_group_id=g_add.id, name_ar="فطر", price_delta=Decimal("4.00"), sort_order=2),
        Option(option_group_id=g_add.id, name_ar="زيتون أسود", price_delta=Decimal("3.00"), sort_order=3),
    ])

    # --- Pasta: size only ---
    pasta_arrabiata = Item(
        category_id=pasta.id,
        name_ar="باستا أرابياتا",
        name_en="Pasta Arrabiata",
        description_ar="باستا حارة بصلصة الطماطم والفلفل.",
        base_price=Decimal("28.00"),
        calories=620,
        sort_order=1,
    )
    db.session.add(pasta_arrabiata)
    db.session.flush()

    g_pasta_size = OptionGroup(
        item_id=pasta_arrabiata.id,
        name_ar="الحجم",
        kind=OptionGroupKind.size,
        selection_type=SelectionType.single,
        is_required=True,
        sort_order=1,
    )
    db.session.add(g_pasta_size)
    db.session.flush()
    db.session.add_all([
        Option(option_group_id=g_pasta_size.id, name_ar="وسط", price_delta=Decimal("0"), is_default=True, sort_order=1),
        Option(option_group_id=g_pasta_size.id, name_ar="كبير", price_delta=Decimal("10.00"), sort_order=2),
    ])

    # --- Drink: no option groups at all ---
    drink = Item(
        category_id=drinks.id,
        name_ar="كوكاكولا",
        name_en="Coca-Cola",
        description_ar="مشروب غازي منعش.",
        base_price=Decimal("6.00"),
        calories=140,
        sort_order=1,
    )
    db.session.add(drink)
    db.session.flush()

    # --- Cross-sell (US2.4): pizza recommends pasta + drink ---
    db.session.add_all([
        ItemCrossSell(item_id=margherita.id, recommended_item_id=pasta_arrabiata.id, sort_order=1),
        ItemCrossSell(item_id=margherita.id, recommended_item_id=drink.id, sort_order=2),
        # And pasta recommends a drink too — nice for demoing the sheet on multiple items
        ItemCrossSell(item_id=pasta_arrabiata.id, recommended_item_id=drink.id, sort_order=1),
    ])


def _seed_loyalty_defaults() -> None:
    """E5 — ensure the singleton settings row exists with sensible defaults."""
    if db.session.query(LoyaltySettings).count() == 0:
        db.session.add(LoyaltySettings(id=1))  # defaults set on the model
        db.session.flush()


def _seed_discount_codes() -> None:
    """E6 — two sample codes so the admin panel + mobile widget aren't empty right after --wipe."""
    from datetime import datetime, timezone, timedelta
    from decimal import Decimal
    db.session.add_all([
        DiscountCode(
            code="WELCOME10",
            kind=DiscountKind.percent,
            value=Decimal("10"),
            is_active=True,
            notes="Welcome discount — 10% off, no expiry, unlimited uses.",
        ),
        DiscountCode(
            code="RAMADAN50",
            kind=DiscountKind.fixed,
            value=Decimal("50"),
            min_subtotal=Decimal("100"),
            max_uses=100,
            expires_at=datetime.now(timezone.utc) + timedelta(days=365),
            is_active=True,
            notes="Ramadan campaign — 50 SAR off orders of 100+, first 100 uses.",
        ),
    ])


def _seed_sample_customer_and_orders() -> None:
    """E4/E5 — one customer with 250 points + a few orders linked to them."""
    from decimal import Decimal
    pizza = db.session.query(Item).filter_by(name_ar="بيتزا مارجريتا").first()
    drink = db.session.query(Item).filter_by(name_ar="كوكاكولا").first()
    if pizza is None or drink is None:
        return

    # Customer for the loyalty demo — marked verified for the E9 auth demo.
    customer = Customer(
        phone="0555555555",
        name="عميل جديد",
        points_balance=250,
        verified_at=datetime.now(timezone.utc),
    )
    db.session.add(customer)
    db.session.flush()
    db.session.add_all([
        SavedAddress(
            customer_id=customer.id, label="المنزل",
            address_text="الرياض، حي النرجس، شارع 12، منزل 5", is_default=True, sort_order=1,
        ),
        SavedAddress(
            customer_id=customer.id, label="العمل",
            address_text="الرياض، حي العليا، برج المملكة، دور 20", sort_order=2,
        ),
    ])

    def _line(item: Item, qty: int, opt_names: list[str] = None) -> OrderLine:
        opt_names = opt_names or []
        selections: list[OrderLineSelection] = []
        deltas = Decimal("0")
        for group in item.option_groups:
            for opt in group.options:
                if opt.name_ar in opt_names:
                    selections.append(OrderLineSelection(
                        group_id_snapshot=group.id,
                        group_name_ar_snapshot=group.name_ar,
                        group_kind_snapshot=group.kind.value,
                        option_id_snapshot=opt.id,
                        option_name_ar_snapshot=opt.name_ar,
                        price_delta_snapshot=opt.price_delta,
                    ))
                    deltas += opt.price_delta
        unit = item.base_price + deltas
        return OrderLine(
            item_id=item.id,
            name_ar_snapshot=item.name_ar,
            image_path_snapshot=item.image_path,
            base_price_snapshot=item.base_price,
            quantity=qty,
            unit_price=unit,
            line_price=unit * qty,
            sort_order=0,
            selections=selections,
        )

    # 1) A brand-new confirmed order — admin should see the "جديد" badge.
    o1_lines = [_line(pizza, 1, ["مارجريتا", "وسط"])]
    subtotal1 = sum((l.line_price for l in o1_lines), Decimal("0"))
    o1 = Order(
        status=OrderStatus.confirmed,
        fulfillment_type=FulfillmentType.delivery,
        delivery_address="الرياض، حي النرجس، شارع 12",
        customer_name="عميل جديد",
        customer_phone="0555555555",
        customer_id=customer.id,
        subtotal=subtotal1,
        delivery_fee=Decimal("15.00"),
        total=subtotal1 + Decimal("15.00"),
        payment_method=PaymentMethod.cash,
        payment_reference="cash-seed-1",
        lines=o1_lines,
    )

    # 2) Preparing (delivery)
    o2_lines = [_line(pizza, 2, ["بيبروني", "كبير"])]
    subtotal2 = sum((l.line_price for l in o2_lines), Decimal("0"))
    other_customer = Customer(phone="0501234567", name="سلمى العتيبي", points_balance=0)
    db.session.add(other_customer); db.session.flush()
    o2 = Order(
        status=OrderStatus.preparing,
        fulfillment_type=FulfillmentType.delivery,
        delivery_address="الرياض، حي الملك فيصل",
        customer_name="سلمى العتيبي",
        customer_phone="0501234567",
        customer_id=other_customer.id,
        subtotal=subtotal2,
        delivery_fee=Decimal("15.00"),
        total=subtotal2 + Decimal("15.00"),
        payment_method=PaymentMethod.apple_pay,
        payment_reference="stub-seed-2",
        admin_seen_at=None,  # will stay None until an admin opens it
        lines=o2_lines,
    )

    # 3) Already delivered — a "historical" order to show terminal state
    o3_lines = [_line(drink, 3, [])]
    subtotal3 = sum((l.line_price for l in o3_lines), Decimal("0"))
    o3 = Order(
        status=OrderStatus.delivered,
        fulfillment_type=FulfillmentType.pickup,
        customer_name="أحمد الغامدي",
        customer_phone="0509876543",
        subtotal=subtotal3,
        delivery_fee=Decimal("0"),
        total=subtotal3,
        payment_method=PaymentMethod.cash,
        payment_reference="cash-seed-3",
        lines=o3_lines,
    )

    # 4) Another delivered — gives E7's most-ordered something to rank.
    o4_lines = [_line(pizza, 2, ["بيبروني", "كبير"])]
    subtotal4 = sum((l.line_price for l in o4_lines), Decimal("0"))
    o4 = Order(
        status=OrderStatus.delivered,
        fulfillment_type=FulfillmentType.delivery,
        delivery_address="جدة، حي الشاطئ",
        customer_name="عميل تجريبي",
        customer_phone="0533334444",
        subtotal=subtotal4,
        delivery_fee=Decimal("15.00"),
        total=subtotal4 + Decimal("15.00"),
        payment_method=PaymentMethod.cash,
        payment_reference="cash-seed-4",
        lines=o4_lines,
    )

    db.session.add_all([o1, o2, o3, o4])


def _seed_welcome_notification() -> None:
    """E8 — one broadcast so the mobile inbox has something on first launch."""
    customer_ids = [c.id for c in db.session.query(Customer).all()]
    if not customer_ids:
        return
    notif = Notification(
        title_ar="أهلاً بك في أحلى طلة",
        body_ar="اطلب أول طلبك واستمتع بأشهى المأكولات — الأكواد والعروض في انتظارك!",
        target=NotificationTarget.all,
        target_snapshot=customer_ids,
        delivered_count=len(customer_ids),
    )
    db.session.add(notif)
    db.session.flush()
    db.session.add_all([
        NotificationDelivery(notification_id=notif.id, customer_id=cid)
        for cid in customer_ids
    ])


def _seed_offers() -> None:
    """E7 — one live offer + one expired to prove auto-hide."""
    from datetime import datetime, timezone, timedelta
    now = datetime.now(timezone.utc)
    pizza = db.session.query(Item).filter_by(name_ar="بيتزا مارجريتا").first()
    db.session.add_all([
        Offer(
            title_ar="عرض الأسبوع — خصم على البيتزا",
            description_ar="اطلب بيتزا مارجريتا هذا الأسبوع بأفضل سعر.",
            starts_at=now - timedelta(days=1),
            ends_at=now + timedelta(days=14),
            is_active=True,
            linked_item_id=pizza.id if pizza else None,
            sort_order=1,
        ),
        Offer(
            title_ar="عرض رمضان (منتهي)",
            description_ar="عرض تجريبي منتهي — يجب ألا يظهر في التطبيق.",
            starts_at=now - timedelta(days=60),
            ends_at=now - timedelta(days=30),
            is_active=True,
            sort_order=2,
        ),
    ])
