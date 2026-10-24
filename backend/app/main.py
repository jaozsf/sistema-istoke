import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from app.core.config import settings
from app.core.database import engine, Base
from app.core.firebase import init_firebase

# Importa todos os modelos para o Alembic/SQLAlchemy detectar
import app.models  # noqa: F401
from app.models.user import UserRole

from app.controllers.auth_controller    import router as auth_router
from app.controllers.user_controller    import router as user_router
from app.controllers.company_controller import router as company_router
from app.controllers.product_controller import router as product_router
from app.controllers.stock_controller   import router as stock_router
from app.controllers.ai_controller      import router as ai_router
from app.controllers.analytics_controller import router as analytics_router
from app.controllers.finance_controller import router as finance_router
from app.controllers.logistics_controller import router as logistics_router

logging.basicConfig(level=logging.DEBUG if settings.DEBUG else logging.INFO)
logger = logging.getLogger("stockiq")


async def _prepare_schema() -> None:
    """
    create_all só cria tabela que não existe -- não mexe em enum. Valores
    novos de user_role (setores do fluxo de pedido) entram aqui com
    ADD VALUE IF NOT EXISTS, idempotente. Cada ADD VALUE roda em
    autocommit porque o Postgres não deixa usar o valor novo na mesma
    transação em que ele foi criado.
    """
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    except IntegrityError:
        # Duas instâncias serverless subindo juntas: a outra criou a tabela
        # entre o "existe?" e o CREATE. Inofensivo -- segue pro enum.
        logger.info("create_all concorrente com outra instância; tabelas já existem.")
    if engine.dialect.name != "postgresql":
        return
    async with engine.connect() as conn:
        conn = await conn.execution_options(isolation_level="AUTOCOMMIT")
        for role in UserRole:
            await conn.execute(text(f"ALTER TYPE user_role ADD VALUE IF NOT EXISTS '{role.value}'"))


# ─── Lifespan (startup / shutdown) ────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Falha aqui não pode derrubar a instância inteira (na Vercel isso vira
    # 500 em TODA rota, inclusive /health) -- loga e segue; as rotas que
    # dependem do recurso falham sozinhas com mensagem clara.
    try:
        await _prepare_schema()
    except Exception:
        logger.exception("Falha ao preparar schema do banco no startup.")
    try:
        init_firebase()
    except Exception:
        logger.exception("Falha ao inicializar Firebase no startup.")
    logger.info("%s v%s iniciado.", settings.APP_NAME, settings.APP_VERSION)
    yield
    await engine.dispose()


# ─── App ──────────────────────────────────────────────────────────────────────

app = FastAPI(
    title=f"{settings.APP_NAME} API",
    version=settings.APP_VERSION,
    description="ERP SaaS com estoque, financeiro, pedidos e IA integrada.",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)


# ─── Erros não tratados ───────────────────────────────────────────────────────
# Middleware (e não exception_handler(Exception)): handler de Exception roda
# FORA do CORSMiddleware, então o 500 saía sem Access-Control-Allow-Origin e
# o app web via só "erro de conexão" em vez da mensagem. Registrado ANTES do
# CORS = fica por dentro dele.

class CatchUnhandledMiddleware:
    # ASGI puro (não @app.middleware/BaseHTTPMiddleware): esse último roda
    # a rota numa task separada e deixava a sessão do banco sem fechar.
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        started = False

        async def send_wrapper(message):
            nonlocal started
            if message["type"] == "http.response.start":
                started = True
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        except Exception:
            logger.exception("Erro não tratado em %s %s", scope.get("method"), scope.get("path"))
            if started:
                raise
            response = JSONResponse(status_code=500, content={"detail": "Erro interno do servidor. Tente novamente."})
            await response(scope, receive, send)


app.add_middleware(CatchUnhandledMiddleware)


# ─── CORS ─────────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Routers ──────────────────────────────────────────────────────────────────

API = "/api/v1"

app.include_router(auth_router,    prefix=API)
app.include_router(user_router,    prefix=API)
app.include_router(company_router, prefix=API)
app.include_router(product_router, prefix=API)
app.include_router(stock_router,   prefix=API)
app.include_router(ai_router,      prefix=API)
app.include_router(analytics_router, prefix=API)
app.include_router(finance_router, prefix=API)
app.include_router(logistics_router, prefix=API)

# ─── Health check ─────────────────────────────────────────────────────────────

@app.get("/health", tags=["Health"])
async def health():
    return {"status": "ok", "app": settings.APP_NAME, "version": settings.APP_VERSION}


@app.get("/health/db", tags=["Health"])
async def health_db():
    """Bate no banco -- o app chama no boot pra acordar a instância e a Neon."""
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return {"status": "ok", "db": "ok"}
    except Exception:
        logger.exception("Health check do banco falhou.")
        return JSONResponse(status_code=503, content={"status": "degraded", "db": "error"})
