"""saved_addresses: Stitch _3 delivery-detail fields

Adds the structured columns the Stitch address form (screen _3) writes
into: typed label, district/apt/floor, extra details, contact phone,
driver-instruction toggles (leave_at_door, dont_ring_bell), photo,
lat/lng, formatted address. All nullable so pre-Stitch rows still load.

Revision ID: a5f2d1e83b70
Revises: 7be0571769cd
Create Date: 2026-09-24 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a5f2d1e83b70'
down_revision = '7be0571769cd'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('saved_addresses') as batch:
        batch.add_column(sa.Column('label_type', sa.String(length=20), nullable=True))
        batch.add_column(sa.Column('district_name', sa.String(length=120), nullable=True))
        batch.add_column(sa.Column('apt_number', sa.String(length=40), nullable=True))
        batch.add_column(sa.Column('floor', sa.String(length=40), nullable=True))
        batch.add_column(sa.Column('extra_details', sa.String(length=500), nullable=True))
        batch.add_column(sa.Column('contact_phone', sa.String(length=40), nullable=True))
        batch.add_column(sa.Column('leave_at_door', sa.Boolean(), nullable=False, server_default='false'))
        batch.add_column(sa.Column('dont_ring_bell', sa.Boolean(), nullable=False, server_default='false'))
        batch.add_column(sa.Column('photo_url', sa.String(length=500), nullable=True))
        batch.add_column(sa.Column('lat', sa.Float(), nullable=True))
        batch.add_column(sa.Column('lng', sa.Float(), nullable=True))
        batch.add_column(sa.Column('formatted_address', sa.String(length=500), nullable=True))
        batch.create_check_constraint(
            'ck_saved_addresses_label_type',
            "label_type IS NULL OR label_type IN ('home','office','hotel','rest','other')",
        )


def downgrade():
    with op.batch_alter_table('saved_addresses') as batch:
        batch.drop_constraint('ck_saved_addresses_label_type', type_='check')
        for col in (
            'formatted_address', 'lng', 'lat', 'photo_url',
            'dont_ring_bell', 'leave_at_door',
            'contact_phone', 'extra_details', 'floor', 'apt_number',
            'district_name', 'label_type',
        ):
            batch.drop_column(col)
