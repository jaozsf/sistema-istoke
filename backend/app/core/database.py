import uuid
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import NullPool
from app.core.config import settings, normalize_async_db_url, IS_SERVERLESS


_db_url, _connect_args = normalize_async_db_url(settings.DATABASE_URL)
if _connect_args.get("statement_cache_size") == 0:
    _connect_args["prepared_statement_name_func"] = lambda: f"__asyncpg_{uuid.uuid4()}__"

_engine_kwargs: dict = {"echo": settings.SQL_ECHO, "pool_pre_ping": True, "connect_args": _connect_args}
if IS_SERVERLESS:
    # Serverless: cada instância congela entre requisições e conexão de
    # pool parada morre do lado da Neon -- abre/fecha por requisição (o
    # pooler da Neon já faz o pooling de verdade).
    _engine_kwargs["poolclass"] = NullPool
elif _db_url.startswith("postgresql"):
    _engine_kwargs.update(pool_size=10, max_overflow=20, pool_recycle=300)

engine = create_async_engine(_db_url, **_engine_kwargs)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
