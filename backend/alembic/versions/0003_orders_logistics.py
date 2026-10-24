"""pedidos, padrão de caixa, distribuidoras, clientes + setores em user_role

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-24 00:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _ts():
    return [
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    ]


def upgrade() -> None:
    with op.get_context().autocommit_block():
        for role in ("seller", "production", "shipping"):
            op.execute(f"ALTER TYPE user_role ADD VALUE IF NOT EXISTS '{role}'")

    op.create_table(
        "box_standards",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("product_id", sa.String(36), sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("company_id", sa.String(36), sa.ForeignKey("companies.id", ondelete="CASCADE"), nullable=False),
        sa.Column("units_per_box", sa.Integer, nullable=False),
        sa.Column("box_type", sa.String(100)),
        sa.Column("length_cm", sa.Numeric(8, 2)),
        sa.Column("width_cm", sa.Numeric(8, 2)),
        sa.Column("height_cm", sa.Numeric(8, 2)),
        sa.Column("weight_kg", sa.Numeric(8, 3)),
        sa.Column("notes", sa.Text),
        *_ts(),
    )
    op.create_index("ix_box_standards_company_id", "box_standards", ["company_id"])

    op.create_table(
        "distributors",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("cnpj", sa.String(18)),
        sa.Column("contact_name", sa.String(255)),
        sa.Column("phone", sa.String(20)),
        sa.Column("email", sa.String(255)),
        sa.Column("regions", sa.Text),
        sa.Column("notes", sa.Text),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.true()),
        sa.Column("company_id", sa.String(36), sa.ForeignKey("companies.id", ondelete="CASCADE"), nullable=False),
        *_ts(),
    )
    op.create_index("ix_distributors_company_id", "distributors", ["company_id"])

    op.create_table(
        "customers",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("document", sa.String(18)),
        sa.Column("phone", sa.String(20)),
        sa.Column("email", sa.String(255)),
        sa.Column("city", sa.String(100)),
        sa.Column("state", sa.String(2)),
        sa.Column("address", sa.Text),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.true()),
        sa.Column("company_id", sa.String(36), sa.ForeignKey("companies.id", ondelete="CASCADE"), nullable=False),
        sa.Column("seller_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        *_ts(),
    )
    op.create_index("ix_customers_company_id", "customers", ["company_id"])
    op.create_index("ix_customers_seller_id", "customers", ["seller_id"])

    op.create_table(
        "orders",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("number", sa.Integer, nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("company_id", sa.String(36), sa.ForeignKey("companies.id", ondelete="CASCADE"), nullable=False),
        sa.Column("branch_id", sa.String(36), sa.ForeignKey("branches.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("customer_id", sa.String(36), sa.ForeignKey("customers.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("seller_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("distributor_id", sa.String(36), sa.ForeignKey("distributors.id", ondelete="SET NULL")),
        sa.Column("notes", sa.Text),
        sa.Column("invoice_number", sa.String(50)),
        sa.Column("tracking_code", sa.String(100)),
        sa.Column("check_notes", sa.Text),
        sa.Column("stock_deducted", sa.Boolean, nullable=False, server_default=sa.false()),
        *_ts(),
        sa.Column("dispatched_at", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("company_id", "number", name="uq_order_company_number"),
    )
    for col in ("company_id", "status", "customer_id", "seller_id", "created_at"):
        op.create_index(f"ix_orders_{col}", "orders", [col])

    op.create_table(
        "order_items",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("order_id", sa.String(36), sa.ForeignKey("orders.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", sa.String(36), sa.ForeignKey("products.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("position", sa.Integer, nullable=False, server_default="0"),
        sa.Column("quantity_boxes", sa.Integer, nullable=False),
        sa.Column("units_per_box", sa.Integer, nullable=False),
        sa.Column("box_weight_kg", sa.Numeric(8, 3)),
        sa.Column("unit_price", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("product_name", sa.String(255), nullable=False),
        sa.Column("product_sku", sa.String(50), nullable=False),
        sa.Column("has_art", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("has_border", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("art_notes", sa.Text),
        sa.Column("checked_boxes", sa.Integer, nullable=False, server_default="0"),
    )
    op.create_index("ix_order_items_order_id", "order_items", ["order_id"])

    op.create_table(
        "order_events",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("order_id", sa.String(36), sa.ForeignKey("orders.id", ondelete="CASCADE"), nullable=False),
        sa.Column("from_status", sa.String(20)),
        sa.Column("to_status", sa.String(20), nullable=False),
        sa.Column("note", sa.Text),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("user_name", sa.String(255)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_order_events_order_id", "order_events", ["order_id"])


def downgrade() -> None:
    for t in ("order_events", "order_items", "orders", "customers", "distributors", "box_standards"):
        op.drop_table(t)
    # Valores de enum do Postgres não têm DROP VALUE -- ficam.
