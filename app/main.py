from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import settings
from app.core.database import engine, Base
from app.core.firebase import init_firebase

# Importa todos os modelos para o Alembic/SQLAlchemy detectar
import app.models  # noqa: F401

from app.controllers.auth_controller    import router as auth_router
from app.controllers.user_controller    import router as user_router
from app.controllers.company_controller import router as company_router
from app.controllers.product_controller import router as product_router
from app.controllers.stock_controller   import router as stock_router
from app.controllers.ai_controller      import router as ai_router
from app.controllers.analytics_controller import router as analytics_router

# ─── Lifespan (startup / shutdown) ────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)  # cria tabelas se não existirem
    init_firebase()
    print(f"✅ {settings.APP_NAME} v{settings.APP_VERSION} iniciado.")
    yield
    # Shutdown
    await engine.dispose()
    print("🔌 Conexões encerradas.")


# ─── App ──────────────────────────────────────────────────────────────────────

app = FastAPI(
    title=f"{settings.APP_NAME} API",
    version=settings.APP_VERSION,
    description="ERP SaaS com estoque, financeiro e IA integrada.",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ─── CORS ─────────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Exception handlers ───────────────────────────────────────────────────────

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    if settings.DEBUG:
        raise exc
    return JSONResponse(status_code=500, content={"detail": "Erro interno do servidor."})

# ─── Routers ──────────────────────────────────────────────────────────────────

API = "/api/v1"

app.include_router(auth_router,    prefix=API)
app.include_router(user_router,    prefix=API)
app.include_router(company_router, prefix=API)
app.include_router(product_router, prefix=API)
app.include_router(stock_router,   prefix=API)
app.include_router(ai_router,      prefix=API)
app.include_router(analytics_router, prefix=API)
# ─── Health check ─────────────────────────────────────────────────────────────

@app.get("/health", tags=["Health"])
async def health():
    return {"status": "ok", "app": settings.APP_NAME, "version": settings.APP_VERSION}
