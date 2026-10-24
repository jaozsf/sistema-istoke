"""
Testes de integração — fluxo de pedido (vendedor -> produção -> expedição
-> distribuidora) + padrão de caixa.
Rode com: pytest tests/ -v
"""
import uuid
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.core.database import get_db
from app.core.security import create_access_token
from app.models.company import Company
from app.models.branch import Branch
from app.models.user import User, UserRole
from app.models.product import Product
from app.models.stock import Stock
from tests.test_products import override_get_db, setup_db, db  # noqa: F401 -- fixtures compartilhadas


def _user(company_id, branch_id, role, email):
    return User(
        id=str(uuid.uuid4()), firebase_uid=f"uid-{email}", email=email, full_name=email.split("@")[0].title(),
        role=role, company_id=company_id, branch_id=branch_id,
    )


@pytest_asyncio.fixture
async def world(db):
    company_id, branch_id = str(uuid.uuid4()), str(uuid.uuid4())
    db.add_all([
        Company(id=company_id, name="Copos SA", plan="pro"),
        Branch(id=branch_id, name="Matriz", company_id=company_id),
    ])
    users = {
        "admin": _user(company_id, branch_id, UserRole.admin, "dono@copos.com"),
        "seller": _user(company_id, branch_id, UserRole.seller, "vendedor@copos.com"),
        "production": _user(company_id, branch_id, UserRole.production, "producao@copos.com"),
        "shipping": _user(company_id, branch_id, UserRole.shipping, "expedicao@copos.com"),
    }
    copo = Product(id=str(uuid.uuid4()), sku="COP-TWI-500", name="Copo Twister 500ml",
                   sale_price=2.80, cost_price=1.10, company_id=company_id)
    eco = Product(id=str(uuid.uuid4()), sku="EC-300", name="Copo Ecológico 300ml",
                  sale_price=1.50, cost_price=0.60, company_id=company_id)
    db.add_all([*users.values(), copo, eco])
    db.add_all([
        Stock(product_id=copo.id, branch_id=branch_id, quantity=1000, min_quantity=0),
        Stock(product_id=eco.id, branch_id=branch_id, quantity=1000, min_quantity=0),
    ])
    await db.commit()
    tokens = {
        k: {"Authorization": "Bearer " + create_access_token({"sub": u.id, "role": u.role.value, "company_id": company_id})}
        for k, u in users.items()
    }
    return {"h": tokens, "copo": copo.id, "eco": eco.id, "branch": branch_id}


@pytest_asyncio.fixture
async def ac(world):
    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        yield client, world
    app.dependency_overrides.clear()


async def _setup_catalog(client, w):
    h = w["h"]
    r = await client.put(f"/api/v1/box-standards/{w['copo']}", headers=h["admin"],
                         json={"units_per_box": 25, "weight_kg": "2.5", "length_cm": 40, "width_cm": 30, "height_cm": 35})
    assert r.status_code == 200, r.text
    r = await client.post("/api/v1/distributors", headers=h["admin"], json={"name": "Transportes Rápido"})
    assert r.status_code == 201
    dist = r.json()["id"]
    r = await client.post("/api/v1/customers", headers=h["seller"], json={"name": "Bar do Zé", "city": "Maringá", "state": "PR"})
    assert r.status_code == 201
    return dist, r.json()["id"]


@pytest.mark.asyncio
async def test_only_admin_sets_box_standard(ac):
    client, w = ac
    r = await client.put(f"/api/v1/box-standards/{w['copo']}", headers=w["h"]["seller"], json={"units_per_box": 10})
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_order_without_box_standard_rejected(ac):
    client, w = ac
    dist, cust = await _setup_catalog(client, w)
    r = await client.post("/api/v1/orders", headers=w["h"]["seller"], json={
        "customer_id": cust, "distributor_id": dist, "items": [{"product_id": w["eco"], "quantity_boxes": 1}],
    })
    assert r.status_code == 422
    assert "padrão de caixa" in r.json()["detail"]


@pytest.mark.asyncio
async def test_full_flow_with_production(ac):
    client, w = ac
    h = w["h"]
    dist, cust = await _setup_catalog(client, w)

    r = await client.post("/api/v1/orders", headers=h["seller"], json={
        "customer_id": cust, "distributor_id": dist,
        "items": [{"product_id": w["copo"], "quantity_boxes": 4, "has_art": True}],
    })
    assert r.status_code == 201, r.text
    order = r.json()
    oid = order["id"]
    assert order["number"] == 1
    assert order["total_units"] == 100            # 4 cx x 25
    assert order["total_weight_kg"] == 10.0
    assert order["needs_production"] is True
    assert order["allowed_transitions"] == ["cancelado"]  # vendedor só cancela

    # Expedição não pode pular a produção
    r = await client.post(f"/api/v1/orders/{oid}/transition", headers=h["shipping"], json={"to_status": "em_separacao"})
    assert r.status_code == 409

    r = await client.post(f"/api/v1/orders/{oid}/transition", headers=h["production"], json={"to_status": "em_producao"})
    assert r.status_code == 200, r.text
    assert r.json()["stock_deducted"] is True
    stock = (await client.get(f"/api/v1/branches/{w['branch']}/stock/{w['copo']}", headers=h["admin"])).json()
    assert stock["quantity"] == 900

    r = await client.post(f"/api/v1/orders/{oid}/transition", headers=h["production"], json={"to_status": "em_separacao"})
    assert r.status_code == 200

    # Conferência incompleta trava
    item_id = r.json()["items"][0]["id"]
    r = await client.post(f"/api/v1/orders/{oid}/transition", headers=h["shipping"], json={"to_status": "conferido"})
    assert r.status_code == 409
    r = await client.put(f"/api/v1/orders/{oid}/items/{item_id}/check", headers=h["shipping"], json={"checked_boxes": 5})
    assert r.status_code == 422
    r = await client.put(f"/api/v1/orders/{oid}/items/{item_id}/check", headers=h["shipping"], json={"checked_boxes": 4})
    assert r.json()["checked_boxes"] == 4

    r = await client.post(f"/api/v1/orders/{oid}/transition", headers=h["shipping"], json={"to_status": "conferido"})
    assert r.status_code == 200
    r = await client.post(f"/api/v1/orders/{oid}/transition", headers=h["shipping"],
                          json={"to_status": "despachado", "invoice_number": "NF-123"})
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "despachado"
    assert body["invoice_number"] == "NF-123"
    assert body["distributor_name"] == "Transportes Rápido"
    assert [e["to_status"] for e in body["events"]] == ["enviado", "em_producao", "em_separacao", "conferido", "despachado"]

    summary = (await client.get("/api/v1/orders/summary", headers=h["admin"])).json()
    assert summary["counts"]["despachado"] == 1
    assert summary["dispatched_today"] == 1


@pytest.mark.asyncio
async def test_cancel_returns_stock(ac):
    client, w = ac
    h = w["h"]
    dist, cust = await _setup_catalog(client, w)
    oid = (await client.post("/api/v1/orders", headers=h["seller"], json={
        "customer_id": cust, "distributor_id": dist, "items": [{"product_id": w["copo"], "quantity_boxes": 2}],
    })).json()["id"]
    r = await client.post(f"/api/v1/orders/{oid}/transition", headers=h["shipping"], json={"to_status": "em_separacao"})
    assert r.status_code == 200

    # Vendedor não cancela depois que saiu de "enviado"
    r = await client.post(f"/api/v1/orders/{oid}/transition", headers=h["seller"], json={"to_status": "cancelado"})
    assert r.status_code == 409
    r = await client.post(f"/api/v1/orders/{oid}/transition", headers=h["admin"], json={"to_status": "cancelado"})
    assert r.status_code == 200
    stock = (await client.get(f"/api/v1/branches/{w['branch']}/stock/{w['copo']}", headers=h["admin"])).json()
    assert stock["quantity"] == 1000

    fin = (await client.get("/api/v1/finance/summary", headers=h["admin"])).json()
    assert float(fin["receita"]) == 0.0


@pytest.mark.asyncio
async def test_seller_sees_only_own_orders(ac):
    client, w = ac
    h = w["h"]
    dist, cust = await _setup_catalog(client, w)
    await client.post("/api/v1/orders", headers=h["admin"], json={
        "customer_id": cust, "distributor_id": dist, "items": [{"product_id": w["copo"], "quantity_boxes": 1}],
    })
    assert len((await client.get("/api/v1/orders", headers=h["seller"])).json()) == 0
    assert len((await client.get("/api/v1/orders", headers=h["admin"])).json()) == 1
