"""Align products.stock_quantity server default with ORM default.

Revision ID: 023
Revises: 022
"""

from typing import Sequence, Union

from alembic import op

revision: str = "023"
down_revision: Union[str, None] = "022"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TABLE products ALTER COLUMN stock_quantity SET DEFAULT 1")


def downgrade() -> None:
    op.execute("ALTER TABLE products ALTER COLUMN stock_quantity SET DEFAULT 100")
