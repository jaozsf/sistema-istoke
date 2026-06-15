"""initial schema

Revision ID: 0001
Revises: 
Create Date: 2024-01-01 00:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── companies ──────────────────────────────────────────────────────────────
    op.create_table(
        "companies",
        sa.Column("id",         sa.String(36),  primary_key=True),
        sa.Column("name",       sa.String(255), nullable=False),
        sa.Column("cnpj",       sa.String(18),  unique=True,  nullable=True),
        sa.Column("email",      sa.String(255), nullable=True),
        sa.Column("phone",      sa.String(20),  nullable=True),
        sa.Column("address",    sa.Text(),       nullable=True),
        sa.Column("plan",       sa.String(20),  nullable=False, server_default="free"),
        sa.Column("is_active",  sa.Boolean(),   nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # ── branches ───────────────────────────────────────────────────────────────
    op.create_table(
        "branches",
        sa.Column("id",         sa.String(36),  primary_key=True),
        sa.Column("name",       sa.String(255), nullable=False),
        sa.Column("city",       sa.String(100), nullable=True),
        sa.Column("state",      sa.String(2),   nullable=True),
        sa.Column("address",    sa.Text(),       nullable=True),
        sa.Column("phone",      sa.String(20),  nullable=True),
        sa.Column("is_active",  sa.Boolean(),   nullable=False, server_default="true"),
        sa.Column("company_id", sa.String(36),  nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["company_id"], ["companies.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_branches_company_id", "branches", ["company_id"])

    # ── users ──────────────────────────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id",           sa.String(36),  primary_key=True),
        sa.Column("firebase_uid", sa.String(128), nullable=False, unique=True),
        sa.Column("email",        sa.String(255), nullable=False, unique=True),
        sa.Column("full_name",    sa.String(255), nullable=False),
        sa.Column("role",         sa.Enum("admin","manager","operator", name="user_role"), nullable=False, server_default="operator"),
        sa.Column("is_active",    sa.Boolean(),   nullable=False, server_default="true"),
        sa.Column("company_id",   sa.String(36),  nullable=False),
        sa.Column("branch_id",    sa.String(36),  nullable=True),
        sa.Column("created_at",   sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at",   sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["company_id"], ["companies.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["branch_id"],  ["branches.id"],  ondelete="SET NULL"),
    )
    op.create_index("ix_users_firebase_uid", "users", ["firebase_uid"])
    op.create_index("ix_users_email",        "users", ["email"])
    op.create_index("ix_users_company_id",   "users", ["company_id"])

    # ── products ───────────────────────────────────────────────────────────────
    op.create_table(
        "products",
        sa.Column("id",          sa.String(36),   primary_key=True),
        sa.Column("sku",         sa.String(50),   nullable=False),
        sa.Column("name",        sa.String(255),  nullable=False),
        sa.Column("description", sa.Text(),        nullable=True),
        sa.Column("category",    sa.String(100),  nullable=True),
        sa.Column("unit",        sa.String(20),   nullable=False, server_default="unid"),
        sa.Column("sale_price",  sa.Numeric(12,2), nullable=False, server_default="0"),
        sa.Column("cost_price",  sa.Numeric(12,2), nullable=False, server_default="0"),
        sa.Column("qr_code",     sa.String(500),  nullable=True),
        sa.Column("min_stock",   sa.Integer(),    nullable=False, server_default="0"),
        sa.Column("is_active",   sa.Boolean(),    nullable=False, server_default="true"),
        sa.Column("company_id",  sa.String(36),   nullable=False),
        sa.Column("created_at",  sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at",  sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["company_id"], ["companies.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_products_sku",        "products", ["sku"])
    op.create_index("ix_products_company_id", "products", ["company_id"])

    # ── stocks ─────────────────────────────────────────────────────────────────
    op.create_table(
        "stocks",
        sa.Column("id",           sa.String(36), primary_key=True),
        sa.Column("quantity",     sa.Integer(),  nullable=False, server_default="0"),
        sa.Column("min_quantity", sa.Integer(),  nullable=False, server_default="0"),
        sa.Column("product_id",   sa.String(36), nullable=False),
        sa.Column("branch_id",    sa.String(36), nullable=False),
        sa.Column("updated_at",   sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["product_id"], ["products.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["branch_id"],  ["branches.id"],  ondelete="CASCADE"),
        sa.UniqueConstraint("product_id", "branch_id", name="uq_stock_product_branch"),
    )
    op.create_index("ix_stocks_product_id", "stocks", ["product_id"])
    op.create_index("ix_stocks_branch_id",  "stocks", ["branch_id"])

    # ── movements ──────────────────────────────────────────────────────────────
    op.create_table(
        "movements",
        sa.Column("id",             sa.String(36), primary_key=True),
        sa.Column("type",           sa.Enum("entrada","saida","ajuste","transfer", name="movement_type"), nullable=False),
        sa.Column("quantity",       sa.Integer(),  nullable=False),
        sa.Column("notes",          sa.Text(),      nullable=True),
        sa.Column("product_id",     sa.String(36), nullable=False),
        sa.Column("branch_id",      sa.String(36), nullable=False),
        sa.Column("user_id",        sa.String(36), nullable=True),
        sa.Column("dest_branch_id", sa.String(36), nullable=True),
        sa.Column("created_at",     sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["product_id"],     ["products.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["branch_id"],      ["branches.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"],        ["users.id"],    ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["dest_branch_id"], ["branches.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_movements_product_id", "movements", ["product_id"])
    op.create_index("ix_movements_branch_id",  "movements", ["branch_id"])
    op.create_index("ix_movements_created_at", "movements", ["created_at"])

    # ── finances ───────────────────────────────────────────────────────────────
    op.create_table(
        "finances",
        sa.Column("id",           sa.String(36),   primary_key=True),
        sa.Column("type",         sa.Enum("receita","custo", name="finance_type"), nullable=False),
        sa.Column("amount",       sa.Numeric(14,2), nullable=False),
        sa.Column("description",  sa.Text(),         nullable=True),
        sa.Column("reference_id", sa.String(36),    nullable=True),
        sa.Column("company_id",   sa.String(36),    nullable=False),
        sa.Column("branch_id",    sa.String(36),    nullable=True),
        sa.Column("user_id",      sa.String(36),    nullable=True),
        sa.Column("created_at",   sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["company_id"], ["companies.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["branch_id"],  ["branches.id"],  ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"],    ["users.id"],     ondelete="SET NULL"),
    )
    op.create_index("ix_finances_company_id", "finances", ["company_id"])
    op.create_index("ix_finances_created_at", "finances", ["created_at"])

    # ── logs ───────────────────────────────────────────────────────────────────
    op.create_table(
        "logs",
        sa.Column("id",         sa.String(36),  primary_key=True),
        sa.Column("action",     sa.String(100), nullable=False),
        sa.Column("entity",     sa.String(50),  nullable=True),
        sa.Column("entity_id",  sa.String(36),  nullable=True),
        sa.Column("detail",     sa.JSON(),       nullable=True),
        sa.Column("ip_address", sa.String(45),  nullable=True),
        sa.Column("user_id",    sa.String(36),  nullable=True),
        sa.Column("company_id", sa.String(36),  nullable=True),
        sa.Column("branch_id",  sa.String(36),  nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["user_id"],    ["users.id"],     ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["company_id"], ["companies.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["branch_id"],  ["branches.id"],  ondelete="SET NULL"),
    )
    op.create_index("ix_logs_action",     "logs", ["action"])
    op.create_index("ix_logs_user_id",    "logs", ["user_id"])
    op.create_index("ix_logs_company_id", "logs", ["company_id"])
    op.create_index("ix_logs_created_at", "logs", ["created_at"])


def downgrade() -> None:
    op.drop_table("logs")
    op.drop_table("finances")
    op.drop_table("movements")
    op.drop_table("stocks")
    op.drop_table("products")
    op.drop_table("users")
    op.drop_table("branches")
    op.drop_table("companies")
    op.execute("DROP TYPE IF EXISTS user_role")
    op.execute("DROP TYPE IF EXISTS movement_type")
    op.execute("DROP TYPE IF EXISTS finance_type")
