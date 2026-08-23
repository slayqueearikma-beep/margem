"""Rename marketplace slug 9ti3a -> 9ri3a (Souk Al Qurayaa / القريعة).

Revision ID: 022
Revises: 021
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "022"
down_revision: Union[str, None] = "021"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        sa.text(
            """
            UPDATE marketplaces
            SET slug = '9ri3a',
                name = '9ri3a',
                description = 'Souk Al Qurayaa (القريعة) — auto parts and mechanics district.',
                address = 'Souk Al Qurayaa',
                district = 'القريعة'
            WHERE slug = '9ti3a'
            """
        )
    )


def downgrade() -> None:
    op.execute(
        sa.text(
            """
            UPDATE marketplaces
            SET slug = '9ti3a',
                name = '9ti3a',
                description = 'Auto parts and mechanics district.',
                address = '9ti3a',
                district = '9ti3a'
            WHERE slug = '9ri3a'
            """
        )
    )
