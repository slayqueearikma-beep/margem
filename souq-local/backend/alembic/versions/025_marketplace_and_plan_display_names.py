"""Display names: 9ri3a marketplace -> Al Qurayaa, buyer plan -> Dribex Plus.

Revision ID: 025
Revises: 024
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "025"
down_revision: Union[str, None] = "024"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        sa.text(
            """
            UPDATE marketplaces
            SET name = 'Al Qurayaa'
            WHERE slug = '9ri3a'
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE subscription_plans
            SET name = 'Dribex Plus'
            WHERE code = 'buyer_premium'
              AND name <> 'Dribex Plus'
            """
        )
    )


def downgrade() -> None:
    op.execute(
        sa.text(
            """
            UPDATE marketplaces
            SET name = '9ri3a'
            WHERE slug = '9ri3a'
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE subscription_plans
            SET name = 'MarGem Plus'
            WHERE code = 'buyer_premium'
              AND name = 'Dribex Plus'
            """
        )
    )
