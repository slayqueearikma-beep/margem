"""Add marketplace_slug to saved searches for market-scoped alerts."""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "036"
down_revision: Union[str, None] = "035"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "saved_searches",
        sa.Column("marketplace_slug", sa.String(length=80), nullable=False, server_default=""),
    )
    op.alter_column("saved_searches", "marketplace_slug", server_default=None)


def downgrade() -> None:
    op.drop_column("saved_searches", "marketplace_slug")
