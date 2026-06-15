"""
Seed de desenvolvimento — executa uma vez para criar dados iniciais.
Uso: python -m app.utils.seed
"""
import asyncio
import uuid
from app.core.database import AsyncSessionLocal, engine, Base
from app.models.company  import Company
from app.models.branch   import Branch
from app.models.user     import User, UserRole
from app.models.product  import Product
from app.models.stock    import Stock


COMPANY_ID = str(uuid.uuid4())
BRANCH_IDS = [str(uuid.uuid4()) for _ in range(4)]
PRODUCT_IDS = [str(uuid.uuid4()) for _ in range(6)]


async def seed():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as db:
        # Empresa
        company = Company(
            id=COMPANY_ID, name="Demo Ltda", cnpj="12.345.678/0001-90",
            email="contato@demo.com.br", plan="pro", is_active=True,
        )
        db.add(company)

        # Filiais
        branches_data = [
            ("Matriz São Paulo", "São Paulo", "SP"),
            ("Filial Campinas",  "Campinas",  "SP"),
            ("Filial Ribeirão",  "Ribeirão Preto", "SP"),
            ("Filial Santos",    "Santos",    "SP"),
        ]
        for i, (name, city, state) in enumerate(branches_data):
            db.add(Branch(id=BRANCH_IDS[i], name=name, city=city, state=state, company_id=COMPANY_ID))

        # Usuário admin
        db.add(User(
            id=str(uuid.uuid4()),
            firebase_uid="FIREBASE_UID_DO_ADMIN",  # substitua pelo UID real
            email="admin@demo.com",
            full_name="Admin Sistema",
            role=UserRole.admin,
            company_id=COMPANY_ID,
            branch_id=BRANCH_IDS[0],
        ))

        # Produtos
        products_data = [
            ("A-001", "Notebook Dell XPS 15",   "Computadores",   8900, 5200, 10),
            ("A-204", "Produto A-204 Especial", "Acessórios",      340,   180, 15),
            ("B-012", "Mouse Logitech MX Master","Periféricos",    620,   310, 20),
            ("C-089", "Monitor 27\" 4K LG",     "Monitores",      3200,  2100,  5),
            ("D-401", "SSD 1TB NVMe Samsung",   "Armazenamento",   480,   240, 25),
            ("E-200", "Teclado Mecânico K5",    "Periféricos",     580,   290, 10),
        ]
        for i, (sku, name, cat, sale, cost, min_s) in enumerate(products_data):
            pid = PRODUCT_IDS[i]
            qr  = f"STOCKIQ:{COMPANY_ID}:{pid}:{sku}"
            db.add(Product(
                id=pid, sku=sku, name=name, category=cat,
                sale_price=sale, cost_price=cost, min_stock=min_s,
                qr_code=qr, company_id=COMPANY_ID,
            ))

        # Estoques iniciais (produto × filial matriz)
        stock_qtys = [42, 3, 87, 1, 61, 33]
        for i, qty in enumerate(stock_qtys):
            db.add(Stock(
                id=str(uuid.uuid4()),
                product_id=PRODUCT_IDS[i],
                branch_id=BRANCH_IDS[0],
                quantity=qty,
                min_quantity=products_data[i][5],
            ))

        await db.commit()
        print(f"✅ Seed concluído!")
        print(f"   company_id : {COMPANY_ID}")
        print(f"   branch_ids : {BRANCH_IDS}")
        print(f"   ⚠️  Atualize o firebase_uid do admin em users para um UID real do Firebase Auth.")


if __name__ == "__main__":
    asyncio.run(seed())
