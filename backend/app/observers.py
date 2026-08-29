"""SQLAlchemy event observers.

Keeps `items.display_price_from` and `items.price_is_variable` in sync whenever an
Option or OptionGroup is inserted / updated / deleted. This lets the categories/items
list endpoint stay a single query while still supporting US1.1's
"يبدأ من X ريال" copy for items whose variant/size groups carry different prices.
"""
from __future__ import annotations

from decimal import Decimal

from sqlalchemy import event
from sqlalchemy.orm import Session

from app.extensions import db
from app.models import Item, Option, OptionGroup, OptionGroupKind, Order, OrderStatus

_KINDS_AFFECTING_LIST_PRICE = {OptionGroupKind.variant, OptionGroupKind.size}


def recompute_item_display_price(item: Item) -> None:
    """Look at the item's variant/size groups and refresh its list-price fields.

    The "starting from" price is the cheapest complete combination the customer
    can walk out with, so we must sum the MINIMUM contribution of each variable
    variant/size group — not take the min across the whole pool of deltas
    (which would be wrong whenever more than one such group exists and both
    have non-zero minimums).

    Rules:
        - A group is 'variable' if it has 2+ active options with differing price_deltas.
        - For each variable group:
            - if required, the customer must pick something → contribution = min(delta)
            - if optional, they can skip → contribution = 0
        - display_price_from = base_price + sum(contributions).
        - price_is_variable = True whenever at least one such variable group exists.
    """
    contributions: list[Decimal] = []
    any_variable = False
    for group in item.option_groups:
        if group.kind not in _KINDS_AFFECTING_LIST_PRICE:
            continue
        deltas = [opt.price_delta for opt in group.options if opt.is_active]
        if len(deltas) >= 2 and len(set(deltas)) > 1:
            any_variable = True
            if group.is_required:
                contributions.append(min(deltas))
            # optional variable groups contribute 0 (customer can leave them at default/none)

    if any_variable:
        item.price_is_variable = True
        item.display_price_from = (item.base_price or Decimal("0")) + sum(
            contributions, Decimal("0")
        )
    else:
        item.price_is_variable = False
        item.display_price_from = None


def _touch(session: Session, target) -> None:
    """Find the parent Item of an Option / OptionGroup change and recompute it."""
    item: Item | None = None
    if isinstance(target, Option):
        group: OptionGroup | None = target.group
        if group is None and target.option_group_id is not None:
            group = session.get(OptionGroup, target.option_group_id)
        if group is not None:
            item = group.item
            if item is None and group.item_id is not None:
                item = session.get(Item, group.item_id)
    elif isinstance(target, OptionGroup):
        item = target.item
        if item is None and target.item_id is not None:
            item = session.get(Item, target.item_id)

    if item is not None:
        recompute_item_display_price(item)


def register_observers() -> None:
    """Wire the events. Called from `create_app` once, after models are imported."""

    @event.listens_for(db.session, "before_flush")
    def _before_flush(session, flush_context, instances):  # noqa: ANN001
        touched_items: set[int] = set()

        for obj in list(session.new) + list(session.dirty) + list(session.deleted):
            if isinstance(obj, (Option, OptionGroup)):
                _touch(session, obj)
                # If we can identify the item id, remember it so we don't recompute twice
                if isinstance(obj, Option) and obj.group is not None and obj.group.item is not None:
                    touched_items.add(obj.group.item.id or 0)
                elif isinstance(obj, OptionGroup) and obj.item is not None:
                    touched_items.add(obj.item.id or 0)

    # E3: assign human-facing order_number after the row gets its PK.
    @event.listens_for(Order, "after_insert")
    def _after_insert_order(mapper, connection, target: Order):  # noqa: ANN001
        if target.order_number:
            return
        year = (target.created_at.year if target.created_at else 0) or __import__("datetime").datetime.utcnow().year
        number = f"AT-{year}-{target.id:06d}"
        connection.execute(
            Order.__table__.update().where(Order.__table__.c.id == target.id).values(order_number=number)
        )
        target.order_number = number

    # E5: award loyalty points when an admin flips an order to 'delivered'.
    # Idempotent via the ledger check inside loyalty.award().
    @event.listens_for(db.session, "before_flush")
    def _award_on_delivered(session, flush_context, instances):  # noqa: ANN001
        from sqlalchemy import inspect
        from app.loyalty import award  # local import: avoid load-time cycle

        for obj in session.dirty:
            if not isinstance(obj, Order):
                continue
            state = inspect(obj)
            hist = state.attrs.status.history
            if not hist.has_changes():
                continue
            if obj.status != OrderStatus.delivered:
                continue
            if obj.customer_id is None or obj.customer is None:
                continue
            award(obj.customer, obj)
