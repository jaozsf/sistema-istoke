"""
seed.py — Cria empresa, filial, usuário admin e produtos de exemplo no banco.

USO:
  1. Coloque este arquivo dentro de: stockiq-backend/
  2. Ative o venv: venv\\Scripts\\activate
  3. Execute: python seed.py

ANTES DE RODAR:
  - Edite FIREBASE_UID abaixo com o UID real do seu usuário Firebase
  - Para achar o UID: acesse https://console.firebase.google.com
    → Authentication → Users → copie o User UID
"""

import asyncio
import uuid
from datetime import datetime, timezone

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

# ── Configuração ────────────────────────────────────────────────────────────────
DATABASE_URL = "postgresql+asyncpg://postgres:1234@localhost:5432/stockiq"

# ⚠️  TROQUE AQUI pelo UID real do Firebase Authentication
FIREBASE_UID = "hD7EOXIHoZZCVcSwFKlfIdmJmWO2"
USER_EMAIL   = "vitalinomoraesmatheus@gmail.com"
USER_NAME    = "Administrador StockIQ"

# ── Setup engine ────────────────────────────────────────────────────────────────
engine = create_async_engine(DATABASE_URL, echo=False)
SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

now = datetime.now(timezone.utc)


async def seed():
    async with SessionLocal() as db:
        # ── 1. Empresa ─────────────────────────────────────────────────────────
        company_id = str(uuid.uuid4())
        await db.execute(text("""
            INSERT INTO companies (id, name, cnpj, email, phone, address, plan, is_active, created_at, updated_at)
            VALUES (:id, :name, :cnpj, :email, :phone, :address, :plan, true, :now, :now)
            ON CONFLICT DO NOTHING
        """), {
            "id": company_id,
            "name": "StockIQ Demo",
            "cnpj": "00.000.000/0001-00",
            "email": "contato@stockiq.com",
            "phone": "(44) 99999-0000",
            "address": "Maringá, PR",
            "plan": "pro",
            "now": now,
        })
        print(f"✅ Empresa criada: {company_id}")

        # ── 2. Filial ──────────────────────────────────────────────────────────
        branch_id = str(uuid.uuid4())
        await db.execute(text("""
            INSERT INTO branches (id, name, city, state, address, phone, is_active, company_id, created_at, updated_at)
            VALUES (:id, :name, :city, :state, :address, :phone, true, :company_id, :now, :now)
            ON CONFLICT DO NOTHING
        """), {
            "id": branch_id,
            "name": "Matriz",
            "city": "Maringá",
            "state": "PR",
            "address": "Av. Principal, 100",
            "phone": "(44) 3333-0000",
            "company_id": company_id,
            "now": now,
        })
        print(f"✅ Filial criada: {branch_id}")

        # ── 3. Usuário admin ───────────────────────────────────────────────────
        user_id = str(uuid.uuid4())
        await db.execute(text("""
            INSERT INTO users (id, firebase_uid, email, full_name, role, is_active, company_id, branch_id, created_at, updated_at)
            VALUES (:id, :firebase_uid, :email, :full_name, 'admin', true, :company_id, :branch_id, :now, :now)
            ON CONFLICT (firebase_uid) DO UPDATE SET
                email      = EXCLUDED.email,
                full_name  = EXCLUDED.full_name,
                role       = EXCLUDED.role,
                is_active  = true,
                company_id = EXCLUDED.company_id,
                branch_id  = EXCLUDED.branch_id,
                updated_at = EXCLUDED.updated_at
        """), {
            "id": user_id,
            "firebase_uid": FIREBASE_UID,
            "email": USER_EMAIL,
            "full_name": USER_NAME,
            "company_id": company_id,
            "branch_id": branch_id,
            "now": now,
        })
        print(f"✅ Usuário admin criado: {USER_EMAIL}")

        # ── 4. Produtos de exemplo ─────────────────────────────────────────────
        produtos = [
            ("Notebook Dell", "NTB-001", "Eletrônicos", 3500.00, 2800.00, "un", 5),
            ("Mouse Logitech", "MOU-002", "Periféricos",   89.90,   45.00, "un", 10),
            ("Teclado Mecânico", "TEC-003", "Periféricos", 299.00,  150.00, "un", 8),
            ("Monitor 24\"", "MON-004", "Eletrônicos",    899.00,  600.00, "un", 3),
            ("Headset Gamer", "HDS-005", "Periféricos",   199.00,   90.00, "un", 15),
        ]

        product_ids = []
        for nome, sku, cat, sale, cost, unit, min_stock in produtos:
            pid = str(uuid.uuid4())
            product_ids.append(pid)
            await db.execute(text("""
                INSERT INTO products (id, sku, name, category, sale_price, cost_price, unit, min_stock, is_active, company_id, created_at, updated_at)
                VALUES (:id, :sku, :name, :cat, :sale, :cost, :unit, :min_stock, true, :company_id, :now, :now)
                ON CONFLICT DO NOTHING
            """), {
                "id": pid, "sku": sku, "name": nome, "cat": cat,
                "sale": sale, "cost": cost, "unit": unit,
                "min_stock": min_stock, "company_id": company_id, "now": now,
            })

        print(f"✅ {len(produtos)} produtos criados")

        # ── 5. Estoque inicial para os produtos ────────────────────────────────
        quantidades = [12, 45, 30, 8, 60]
        for pid, qty in zip(product_ids, quantidades):
            sid = str(uuid.uuid4())
            await db.execute(text("""
                INSERT INTO stocks (id, quantity, min_quantity, product_id, branch_id, updated_at)
                VALUES (:id, :qty, :min_qty, :product_id, :branch_id, :now)
                ON CONFLICT (product_id, branch_id) DO UPDATE SET
                    quantity   = EXCLUDED.quantity,
                    updated_at = EXCLUDED.updated_at
            """), {
                "id": sid, "qty": qty, "min_qty": 5,
                "product_id": pid, "branch_id": branch_id, "now": now,
            })

        print(f"✅ Estoque inicial criado para {len(product_ids)} produtos")

        await db.commit()

    await engine.dispose()
    print("\n🎉 Seed concluído com sucesso!")
    print(f"   Empresa  : StockIQ Demo")
    print(f"   Filial   : Matriz - Maringá/PR")
    print(f"   Login    : {USER_EMAIL}")
    print(f"   Firebase : {FIREBASE_UID}")


if __name__ == "__main__":
    if FIREBASE_UID == "SEU_FIREBASE_UID_AQUI":
        print("❌ ERRO: Edite o arquivo seed.py e coloque seu Firebase UID real!")
        print("   Acesse: https://console.firebase.google.com → Authentication → Users")
        exit(1)
    asyncio.run(seed())
