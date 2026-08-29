"""e4 order workflow statuses + admin_seen_at

Revision ID: beb9a36d3739
Revises: 05abfb5056fd
Create Date: 2026-08-29 17:17:39.811199

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'beb9a36d3739'
down_revision = '05abfb5056fd'
branch_labels = None
depends_on = None


def upgrade():
    # Add admin_seen_at column
    with op.batch_alter_table('orders', schema=None) as batch_op:
        batch_op.add_column(sa.Column('admin_seen_at', sa.DateTime(timezone=True), nullable=True))

    # Extend the order_status enum with the 4 workflow values (US4.2).
    # Postgres requires ADD VALUE to run outside a transaction; the raw SQL
    # inside op.execute is committed via Alembic's own transaction. IF NOT EXISTS
    # makes this idempotent across re-runs / partial migrations.
    for value in ('preparing', 'on_the_way', 'ready_for_pickup', 'delivered'):
        op.execute(f"ALTER TYPE order_status ADD VALUE IF NOT EXISTS '{value}'")


def downgrade():
    # Removing enum values is not natively supported by Postgres. If you
    # truly need to downgrade, hand-roll it: recreate the type with the
    # smaller set, cast the column, drop the old type. Left unimplemented
    # here because it's never done in practice.
    with op.batch_alter_table('orders', schema=None) as batch_op:
        batch_op.drop_column('admin_seen_at')
