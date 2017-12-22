"""change_cell_column_types

Revision ID: 6295b5d42e24
Revises: f13582bd37a0
Create Date: 2017-12-22 05:14:22.149784

"""
from alembic import op
import sqlalchemy as sa
import sys
from pathlib import Path
monocle_dir = str(Path(__file__).resolve().parents[2])
if monocle_dir not in sys.path:
    sys.path.append(monocle_dir)
from monocle import db as db


# revision identifiers, used by Alembic.
revision = '6295b5d42e24'
down_revision = 'f13582bd37a0'
branch_labels = None
depends_on = None


def upgrade():
    op.drop_constraint('sightings_fk_cellid', 'sightings', type_='foreignkey')
    op.drop_constraint('mystery_sightings_fk_cellid', 'mystery_sightings', type_='foreignkey')
    op.alter_column('weather', 's2_cell_id',
            existing_type=sa.BigInteger,
            type_=db.UNSIGNED_HUGE_TYPE)
    op.alter_column('mystery_sightings', 'weather_cell_id',
            existing_type=sa.BigInteger,
            type_=db.UNSIGNED_HUGE_TYPE)
    op.alter_column('sightings', 'weather_cell_id',
            existing_type=sa.BigInteger,
            type_=db.UNSIGNED_HUGE_TYPE)
    op.create_foreign_key('sightings_fk_cellid', 'sightings', 'weather', ['weather_cell_id'], ['s2_cell_id'])
    op.create_foreign_key('mystery_sightings_fk_cellid', 'mystery_sightings', 'weather', ['weather_cell_id'], ['s2_cell_id'])


def downgrade():
    op.drop_constraint('sightings_fk_cellid', 'sightings', type_='foreignkey')
    op.drop_constraint('mystery_sightings_fk_cellid', 'mystery_sightings', type_='foreignkey')
    op.alter_column('mystery_sightings', 'weather_cell_id',
            existing_type=db.UNSIGNED_HUGE_TYPE,
            type_=sa.BigInteger)
    op.alter_column('sightings', 'weather_cell_id',
            existing_type=db.UNSIGNED_HUGE_TYPE,
            type_=sa.BigInteger)
    op.alter_column('weather', 's2_cell_id',
            existing_type=db.UNSIGNED_HUGE_TYPE,
            type_=sa.BigInteger)
    op.create_foreign_key('sightings_fk_cellid', 'sightings', 'weather', ['weather_cell_id'], ['s2_cell_id'])
    op.create_foreign_key('mystery_sightings_fk_cellid', 'mystery_sightings', 'weather', ['weather_cell_id'], ['s2_cell_id'])
