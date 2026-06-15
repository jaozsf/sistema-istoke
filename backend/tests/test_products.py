"""
Testes de integração — Products
Rode com: pytest tests/ -v
"""
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.main import app
from app.core.database import Base, get_db
from app.models.company import Company
from app.models.branch import Branch
from app.models.user import User, UserRole
from app.core.security import create_access_token
import uuid

TEST_DB = "sqlite+aiosqlite:///:memory:"

engine_test = create_async_engine(TEST_DB, echo=False)
TestSession = async_sessionmaker(engine_test, class_=AsyncSession, expire_on_commit=False)


async def override_get_db():
    async with TestSession() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


@pytest_asyncio.fixture(autouse=True)
async def setup_db():
    async with engine_test.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine_test.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def db():
    async with TestSession() as session:
        yield session


@pytest_asyncio.fixture
async def seeded_data(db):
    company_id = str(uuid.uuid4())
    branch_id  = str(uuid.uuid4())
    user_id    = str(uuid.uuid4())

    company = Company(id=company_id, name="Empresa Teste", plan="pro")
    branch  = Branch(id=branch_id, name="Filial Teste", company_id=company_id)
    user    = User(
        id=user_id, firebase_uid="uid-test", email="admin@test.com",
        full_name="Admin Teste", role=UserRole.admin,
        company_id=company_id, branch_id=branch_id,
    )
    db.add_all([company, branch, user])
    await db.commit()

    token = create_access_token({"sub": user_id, "role": "admin", "company_id": company_id})
    return {"token": token, "company_id": company_id, "branch_id": branch_id, "user_id": user_id}


@pytest_asyncio.fixture
async def client(seeded_data):
    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac, seeded_data
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_create_product(client):
    ac, data = client
    headers = {"Authorization": f"Bearer {data['token']}"}
    payload = {
        "sku": "T-001", "name": "Produto Teste", "category": "Testes",
        "sale_price": "100.00", "cost_price": "50.00", "min_stock": 5,
    }
    resp = await ac.post("/api/v1/products", json=payload, headers=headers)
    assert resp.status_code == 201
    body = resp.json()
    assert body["sku"] == "T-001"
    assert body["margin_percent"] == 50.0
    assert body["qr_code"] is not None


@pytest.mark.asyncio
async def test_list_products(client):
    ac, data = client
    headers = {"Authorization": f"Bearer {data['token']}"}
    # Cria um produto primeiro
    await ac.post("/api/v1/products", json={
        "sku": "T-002", "name": "Produto Lista", "sale_price": "200.00", "cost_price": "80.00",
    }, headers=headers)
    resp = await ac.get("/api/v1/products", headers=headers)
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


@pytest.mark.asyncio
async def test_duplicate_sku_rejected(client):
    ac, data = client
    headers = {"Authorization": f"Bearer {data['token']}"}
    payload = {"sku": "DUP-001", "name": "Produto X", "sale_price": "10.00", "cost_price": "5.00"}
    await ac.post("/api/v1/products", json=payload, headers=headers)
    resp = await ac.post("/api/v1/products", json=payload, headers=headers)
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_search_product(client):
    ac, data = client
    headers = {"Authorization": f"Bearer {data['token']}"}
    await ac.post("/api/v1/products", json={
        "sku": "S-001", "name": "Notebook Gamer", "sale_price": "5000.00", "cost_price": "3000.00",
    }, headers=headers)
    resp = await ac.get("/api/v1/products?q=notebook", headers=headers)
    assert resp.status_code == 200
    assert any("Notebook" in p["name"] for p in resp.json())


@pytest.mark.asyncio
async def test_health():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
