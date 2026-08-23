"""Business partnership & teaming system tables."""

from alembic import op

revision = "014"
down_revision = "013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TYPE partnertype AS ENUM (
          'temporary', 'long_term', 'supplier_retailer',
          'service_provider', 'wholesale', 'multi_shop'
        )
        """
    )
    op.execute(
        """
        CREATE TYPE partnershipstatus AS ENUM ('pending', 'active', 'suspended', 'ended')
        """
    )
    op.execute(
        """
        CREATE TYPE partnershipinvitationstatus AS ENUM (
          'pending', 'accepted', 'declined', 'cancelled', 'expired'
        )
        """
    )
    op.execute(
        """
        CREATE TYPE partnershipmemberrole AS ENUM (
          'owner', 'partner', 'manager', 'inventory_manager',
          'sales_manager', 'customer_support'
        )
        """
    )
    op.execute(
        """
        CREATE TYPE inventorymovementtype AS ENUM (
          'share', 'reserve', 'release', 'transfer', 'adjust'
        )
        """
    )
    op.execute(
        """
        CREATE TYPE collaborationstatus AS ENUM (
          'inquiry', 'in_progress', 'fulfilled', 'cancelled'
        )
        """
    )
    op.execute(
        """
        CREATE TYPE revenuesplitscope AS ENUM ('partnership', 'product', 'collaboration')
        """
    )

    op.execute(
        """
        CREATE TABLE partnerships (
          id UUID PRIMARY KEY,
          name VARCHAR(160) NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          partnership_type partnertype NOT NULL,
          marketplace_slug VARCHAR(64) NOT NULL DEFAULT '',
          category_slugs JSONB NOT NULL DEFAULT '[]',
          status partnershipstatus NOT NULL DEFAULT 'pending',
          start_date TIMESTAMPTZ NOT NULL DEFAULT now(),
          end_date TIMESTAMPTZ,
          requires_admin_approval BOOLEAN NOT NULL DEFAULT false,
          admin_approved_at TIMESTAMPTZ,
          admin_approved_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
          is_verified BOOLEAN NOT NULL DEFAULT false,
          successful_collaborations INTEGER NOT NULL DEFAULT 0,
          created_by_seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )
    op.execute("CREATE INDEX ix_partnerships_marketplace_slug ON partnerships (marketplace_slug)")
    op.execute("CREATE INDEX ix_partnerships_status ON partnerships (status)")

    op.execute(
        """
        CREATE TABLE partnership_members (
          id UUID PRIMARY KEY,
          partnership_id UUID NOT NULL REFERENCES partnerships(id) ON DELETE CASCADE,
          seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
          user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          role partnershipmemberrole NOT NULL,
          permissions JSONB NOT NULL DEFAULT '{}',
          joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          is_active BOOLEAN NOT NULL DEFAULT true,
          UNIQUE (partnership_id, seller_id)
        )
        """
    )
    op.execute("CREATE INDEX ix_partnership_members_partnership_id ON partnership_members (partnership_id)")
    op.execute("CREATE INDEX ix_partnership_members_seller_id ON partnership_members (seller_id)")

    op.execute(
        """
        CREATE TABLE partnership_invitations (
          id UUID PRIMARY KEY,
          partnership_id UUID NOT NULL REFERENCES partnerships(id) ON DELETE CASCADE,
          inviter_seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
          invitee_seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
          invited_role partnershipmemberrole NOT NULL DEFAULT 'partner',
          message TEXT NOT NULL DEFAULT '',
          terms JSONB NOT NULL DEFAULT '{}',
          status partnershipinvitationstatus NOT NULL DEFAULT 'pending',
          expires_at TIMESTAMPTZ NOT NULL,
          responded_at TIMESTAMPTZ,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )
    op.execute(
        "CREATE INDEX ix_partnership_invite_invitee ON partnership_invitations (invitee_seller_id, status)"
    )

    op.execute(
        """
        CREATE TABLE partnership_listings (
          id UUID PRIMARY KEY,
          partnership_id UUID NOT NULL REFERENCES partnerships(id) ON DELETE CASCADE,
          product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
          supplier_seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
          fulfiller_seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
          shared_inventory BOOLEAN NOT NULL DEFAULT false,
          shared_pricing BOOLEAN NOT NULL DEFAULT false,
          custom_price_mad NUMERIC(12,2),
          shared_stock_quantity INTEGER NOT NULL DEFAULT 0,
          reserved_stock_quantity INTEGER NOT NULL DEFAULT 0,
          is_active BOOLEAN NOT NULL DEFAULT true,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          UNIQUE (partnership_id, product_id)
        )
        """
    )
    op.execute("CREATE INDEX ix_partnership_listings_partnership_id ON partnership_listings (partnership_id)")
    op.execute("CREATE INDEX ix_partnership_listings_product_id ON partnership_listings (product_id)")

    op.execute(
        """
        CREATE TABLE partnership_inventory_movements (
          id UUID PRIMARY KEY,
          partnership_id UUID NOT NULL REFERENCES partnerships(id) ON DELETE CASCADE,
          listing_id UUID REFERENCES partnership_listings(id) ON DELETE SET NULL,
          product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
          actor_seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
          from_seller_id UUID REFERENCES seller_profiles(id) ON DELETE SET NULL,
          to_seller_id UUID REFERENCES seller_profiles(id) ON DELETE SET NULL,
          movement_type inventorymovementtype NOT NULL,
          quantity INTEGER NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )

    op.execute(
        """
        CREATE TABLE partnership_collaborations (
          id UUID PRIMARY KEY,
          partnership_id UUID NOT NULL REFERENCES partnerships(id) ON DELETE CASCADE,
          reference_code VARCHAR(32) NOT NULL UNIQUE,
          customer_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
          status collaborationstatus NOT NULL DEFAULT 'inquiry',
          total_amount_mad NUMERIC(12,2),
          notes TEXT NOT NULL DEFAULT '',
          created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
          updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )

    op.execute(
        """
        CREATE TABLE partnership_collaboration_responsibilities (
          id UUID PRIMARY KEY,
          collaboration_id UUID NOT NULL REFERENCES partnership_collaborations(id) ON DELETE CASCADE,
          seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
          responsibility_type VARCHAR(40) NOT NULL,
          status VARCHAR(32) NOT NULL DEFAULT 'pending',
          notes TEXT NOT NULL DEFAULT '',
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )

    op.execute(
        """
        CREATE TABLE partnership_revenue_splits (
          id UUID PRIMARY KEY,
          partnership_id UUID NOT NULL REFERENCES partnerships(id) ON DELETE CASCADE,
          scope revenuesplitscope NOT NULL,
          scope_ref_id UUID,
          splits JSONB NOT NULL DEFAULT '[]',
          created_by_seller_id UUID NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )

    op.execute(
        """
        CREATE TABLE partnership_revenue_records (
          id UUID PRIMARY KEY,
          partnership_id UUID NOT NULL REFERENCES partnerships(id) ON DELETE CASCADE,
          collaboration_id UUID REFERENCES partnership_collaborations(id) ON DELETE SET NULL,
          total_amount_mad NUMERIC(12,2) NOT NULL,
          allocations JSONB NOT NULL DEFAULT '[]',
          note TEXT NOT NULL DEFAULT '',
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )

    op.execute(
        """
        CREATE TABLE partnership_chat_messages (
          id UUID PRIMARY KEY,
          partnership_id UUID NOT NULL REFERENCES partnerships(id) ON DELETE CASCADE,
          sender_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          body TEXT NOT NULL DEFAULT '',
          attachment_url VARCHAR(512) NOT NULL DEFAULT '',
          shared_product_id UUID REFERENCES products(id) ON DELETE SET NULL,
          shared_collaboration_id UUID REFERENCES partnership_collaborations(id) ON DELETE SET NULL,
          task_title VARCHAR(160) NOT NULL DEFAULT '',
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )

    op.execute(
        """
        CREATE TABLE partnership_audit_logs (
          id UUID PRIMARY KEY,
          partnership_id UUID NOT NULL REFERENCES partnerships(id) ON DELETE CASCADE,
          actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
          actor_seller_id UUID REFERENCES seller_profiles(id) ON DELETE SET NULL,
          action VARCHAR(80) NOT NULL,
          target_type VARCHAR(40) NOT NULL DEFAULT '',
          target_id VARCHAR(64) NOT NULL DEFAULT '',
          metadata JSONB NOT NULL DEFAULT '{}',
          created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )
    op.execute("CREATE INDEX ix_partnership_audit_action ON partnership_audit_logs (action)")


def downgrade() -> None:
    for table in (
        "partnership_audit_logs",
        "partnership_chat_messages",
        "partnership_revenue_records",
        "partnership_revenue_splits",
        "partnership_collaboration_responsibilities",
        "partnership_collaborations",
        "partnership_inventory_movements",
        "partnership_listings",
        "partnership_invitations",
        "partnership_members",
        "partnerships",
    ):
        op.execute(f"DROP TABLE IF EXISTS {table} CASCADE")
    for enum_name in (
        "revenuesplitscope",
        "collaborationstatus",
        "inventorymovementtype",
        "partnershipmemberrole",
        "partnershipinvitationstatus",
        "partnershipstatus",
        "partnertype",
    ):
        op.execute(f"DROP TYPE IF EXISTS {enum_name} CASCADE")
