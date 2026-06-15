"""
seed_copos.py — Reseta e popula o banco com produtos reais de copos/canecas/cristal.

USO:
  1. Coloque este arquivo em: stockiq-backend/
  2. venv\\Scripts\\activate
  3. python seed_copos.py

ATENÇÃO: Este script LIMPA os dados antigos e insere dados novos.
"""

import asyncio
import uuid
from datetime import datetime, timezone

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

DATABASE_URL  = "postgresql+asyncpg://postgres:1234@localhost:5432/stockiq"
FIREBASE_UID  = "hD7EOXIHoZZCVcSwFKlfIdmJmWO2"
USER_EMAIL    = "vitalinomoraesmatheus@gmail.com"
USER_NAME     = "Matheus Vitalino"

engine       = create_async_engine(DATABASE_URL, echo=False)
SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
now          = datetime.now(timezone.utc)


async def seed():
    async with SessionLocal() as db:

        # ── Limpa dados antigos (ordem inversa de FK) ──────────────────────────
        for t in ("finances","logs","movements","stocks","products","users","branches","companies"):
            await db.execute(text(f"DELETE FROM {t}"))
        print("🗑️  Dados antigos removidos")

        # ── 1. Empresa ─────────────────────────────────────────────────────────
        company_id = str(uuid.uuid4())
        await db.execute(text("""
            INSERT INTO companies (id,name,cnpj,email,phone,address,plan,is_active,created_at,updated_at)
            VALUES (:id,:name,:cnpj,:email,:phone,:address,:plan,true,:now,:now)
        """), dict(id=company_id, name="Distribuidora Copa & Cia",
                   cnpj="12.345.678/0001-99", email="contato@copaecia.com.br",
                   phone="(44) 99876-5432", address="Maringá, PR", plan="pro", now=now))
        print(f"✅ Empresa: Distribuidora Copa & Cia")

        # ── 2. Filiais ─────────────────────────────────────────────────────────
        branch_matriz = str(uuid.uuid4())
        branch_cd     = str(uuid.uuid4())

        for bid, nome, cidade in [
            (branch_matriz, "Matriz - Centro",      "Maringá"),
            (branch_cd,     "CD - Galpão Logístico","Sarandi"),
        ]:
            await db.execute(text("""
                INSERT INTO branches (id,name,city,state,address,phone,is_active,company_id,created_at,updated_at)
                VALUES (:id,:name,:city,'PR',:addr,:phone,true,:cid,:now,:now)
            """), dict(id=bid, name=nome, city=cidade,
                       addr="Rodovia PR-317, Km 5", phone="(44) 3333-1234",
                       cid=company_id, now=now))
        print(f"✅ Filiais criadas: Matriz e CD Logístico")

        # ── 3. Usuário admin ───────────────────────────────────────────────────
        user_id = str(uuid.uuid4())
        await db.execute(text("""
            INSERT INTO users (id,firebase_uid,email,full_name,role,is_active,company_id,branch_id,created_at,updated_at)
            VALUES (:id,:uid,:email,:name,'admin',true,:cid,:bid,:now,:now)
        """), dict(id=user_id, uid=FIREBASE_UID, email=USER_EMAIL,
                   name=USER_NAME, cid=company_id, bid=branch_matriz, now=now))
        print(f"✅ Usuário admin: {USER_EMAIL}")

        # ── 4. Produtos ────────────────────────────────────────────────────────
        # (nome, sku, categoria, sale, cost, unit, min_stock, descricao)
        produtos = [
            # ── Canecas ───────────────────────────────────────────────────────
            ("Caneca Cerâmica 300ml",       "CAN-CER-300", "Canecas",  8.90,  4.20, "un",  50,
             "Caneca de cerâmica branca 300ml. Acompanha caixa individual."),
            ("Caneca PP Plástico 400ml",    "CAN-PP-400",  "Canecas",  3.50,  1.40, "un", 100,
             "Caneca plástica em PP (Polipropileno) 400ml. Resistente a calor. Ideal para brindes."),
            ("Caneca PS Cristal 350ml",     "CAN-PS-350",  "Canecas",  4.20,  1.80, "un",  80,
             "Caneca em PS (Poliestireno) cristal transparente 350ml. Visual elegante."),
            ("Caneca Cerâmica Colorida 400ml","CAN-CER-COL","Canecas", 12.50,  6.00, "un",  30,
             "Caneca cerâmica colorida sortida 400ml. Cores: azul, vermelho, verde, amarelo."),

            # ── Copos ─────────────────────────────────────────────────────────
            ("Copo Twister PP 500ml",       "COP-TWI-500", "Copos",    2.80,  1.10, "un", 200,
             "Copo twister PP translúcido 500ml. Embalagem com 25 unidades por caixa fechada."),
            ("Copo Twister Cristal 300ml",  "COP-TWI-CRI", "Copos",    2.20,  0.90, "un", 200,
             "Copo twister de cristal (PS) 300ml. Embalagem com 50 unidades por caixa."),
            ("Copo Caldeireta PP 200ml",    "COP-CAL-200", "Copos",    1.90,  0.75, "un", 300,
             "Copo caldeireta PP 200ml. Ideal para bebidas quentes e frias. Cx c/ 100un."),
            ("Copo Caldeireta Cristal 250ml","COP-CAL-CRI","Copos",    2.10,  0.85, "un", 250,
             "Copo caldeireta cristal PS 250ml. Transparência total. Cx c/ 100un."),
            ("Copo Americano PS 350ml",     "COP-AME-350", "Copos",    1.60,  0.65, "un", 400,
             "Copo americano PS 350ml. Alta resistência. Caixa com 50 unidades."),
            ("Copo Long Drink Cristal 350ml","COP-LNG-350","Copos",    3.40,  1.50, "un", 150,
             "Copo long drink cristal PS 350ml. Para drinks e coquetéis. Cx c/ 25un."),

            # ── Caixas fechadas (unidade = caixa) ─────────────────────────────
            ("Cx Fechada Copo Twister PP 500ml x25",  "CX-TWI-PP-25",  "Caixas Fechadas", 65.00, 27.00, "cx",  20,
             "Caixa fechada com 25 copos twister PP 500ml. SKU unitário: COP-TWI-500."),
            ("Cx Fechada Copo Twister Cristal 300ml x50","CX-TWI-CRI-50","Caixas Fechadas",99.00, 42.00, "cx",  15,
             "Caixa fechada com 50 copos twister cristal 300ml. SKU unitário: COP-TWI-CRI."),
            ("Cx Fechada Caneca PP 400ml x25",        "CX-CAN-PP-25",  "Caixas Fechadas", 80.00, 33.00, "cx",  10,
             "Caixa fechada com 25 canecas PP 400ml. SKU unitário: CAN-PP-400."),
            ("Cx Fechada Caneca Cerâmica 300ml x12",  "CX-CER-300-12", "Caixas Fechadas",95.00, 47.00, "cx",   8,
             "Caixa fechada com 12 canecas cerâmica 300ml. SKU unitário: CAN-CER-300."),

            # ── Materiais / Insumos ───────────────────────────────────────────
            ("Resina PP Granulada 25kg",    "MAT-PP-25KG", "Matéria-Prima", 180.00, 140.00, "sc", 5,
             "Saco 25kg de resina PP para produção de copos e canecas plásticas."),
            ("Resina PS Cristal 25kg",      "MAT-PS-25KG", "Matéria-Prima", 210.00, 165.00, "sc", 5,
             "Saco 25kg de resina PS cristal para produção de copos transparentes."),
        ]

        product_ids = []
        for (nome, sku, cat, sale, cost, unit, min_s, desc) in produtos:
            pid = str(uuid.uuid4())
            product_ids.append((pid, nome, sku))
            await db.execute(text("""
                INSERT INTO products
                  (id,sku,name,description,category,sale_price,cost_price,unit,min_stock,is_active,company_id,created_at,updated_at)
                VALUES
                  (:id,:sku,:name,:desc,:cat,:sale,:cost,:unit,:min_s,true,:cid,:now,:now)
            """), dict(id=pid, sku=sku, name=nome, desc=desc, cat=cat,
                       sale=sale, cost=cost, unit=unit, min_s=min_s,
                       cid=company_id, now=now))
        print(f"✅ {len(produtos)} produtos criados")

        # ── 5. Estoque (matriz + CD) ───────────────────────────────────────────
        # qtd_matriz, qtd_cd, min_qty
        estoques = [
            (120, 300, 50),   # Caneca Cerâmica 300ml
            (250, 800, 100),  # Caneca PP 400ml
            (180, 600, 80),   # Caneca PS Cristal
            ( 60, 120, 30),   # Caneca Cerâmica Colorida
            (400, 2000, 200), # Copo Twister PP 500ml
            (350, 1800, 200), # Copo Twister Cristal
            (600, 3000, 300), # Copo Caldeireta PP
            (500, 2500, 250), # Copo Caldeireta Cristal
            (800, 4000, 400), # Copo Americano PS
            (200, 800, 150),  # Copo Long Drink
            ( 45, 120, 20),   # Cx Twister PP x25
            ( 30,  90, 15),   # Cx Twister Cristal x50
            ( 22,  60, 10),   # Cx Caneca PP x25
            ( 15,  40,  8),   # Cx Caneca Cerâmica x12
            ( 12,  30,  5),   # Resina PP
            (  8,  20,  5),   # Resina PS
        ]

        for (pid, nome, sku), (qm, qcd, mq) in zip(product_ids, estoques):
            for bid, qty in [(branch_matriz, qm), (branch_cd, qcd)]:
                await db.execute(text("""
                    INSERT INTO stocks (id,quantity,min_quantity,product_id,branch_id,updated_at)
                    VALUES (:id,:qty,:mq,:pid,:bid,:now)
                    ON CONFLICT (product_id,branch_id) DO UPDATE
                    SET quantity=EXCLUDED.quantity, updated_at=EXCLUDED.updated_at
                """), dict(id=str(uuid.uuid4()), qty=qty, mq=mq,
                           pid=pid, bid=bid, now=now))
        print(f"✅ Estoque criado nas 2 filiais para todos os produtos")

        # ── 6. Movimentações de hoje ───────────────────────────────────────────
        movs = [
            # (product_idx, branch, type, qty, notes)
            (0, branch_matriz, "entrada",  60, "Recebimento NF 4521 — Fornecedor CerâmicaMix"),
            (4, branch_cd,     "entrada", 500, "Entrada carga completa — Twister PP 500ml"),
            (4, branch_matriz, "saida",   100, "Venda cliente Restaurante Bom Sabor — Pedido #887"),
            (6, branch_matriz, "saida",   200, "Saída para evento Festa Corporativa Maringá"),
            (1, branch_matriz, "entrada",  25, "Ajuste de inventário — contagem física"),
            (10,branch_cd,     "saida",    10, "Transferência 10 caixas para filial Matriz"),
            (10,branch_matriz, "entrada",  10, "Recebimento transferência do CD — 10 cx Twister PP"),
        ]

        for (pidx, bid, mtype, qty, notes) in movs:
            pid = product_ids[pidx][0]
            await db.execute(text("""
                INSERT INTO movements (id,type,quantity,notes,product_id,branch_id,user_id,created_at)
                VALUES (:id,:type,:qty,:notes,:pid,:bid,:uid,:now)
            """), dict(id=str(uuid.uuid4()), type=mtype, qty=qty,
                       notes=notes, pid=pid, bid=bid, uid=user_id, now=now))
        print(f"✅ {len(movs)} movimentações de hoje registradas")

        await db.commit()

    await engine.dispose()
    print("""
🎉 Seed concluído!
   Empresa  : Distribuidora Copa & Cia
   Filiais  : Matriz (Maringá) + CD Logístico (Sarandi)
   Produtos : 16 produtos (canecas, copos, caixas, matéria-prima)
   Estoque  : 2 filiais populadas
   Movimentos: 7 movimentações de hoje
   Login    : vitalinomoraesmatheus@gmail.com
""")


if __name__ == "__main__":
    asyncio.run(seed())
