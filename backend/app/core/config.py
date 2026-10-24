import os
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode
from pydantic import field_validator
from pydantic_settings import BaseSettings
from typing import List


def normalize_async_db_url(url: str) -> tuple[str, dict]:
    """
    Aceita a URL do jeito que a Neon/Vercel entrega
    (`postgresql://...?sslmode=require&channel_binding=require`) e devolve
    uma URL que o asyncpg entende + os connect_args equivalentes. O asyncpg
    não conhece `sslmode`/`channel_binding` na query string -- passar eles
    crus derruba a conexão com "unexpected keyword argument".
    """
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://"):]
    if url.startswith("postgresql://") or url.startswith("postgresql+psycopg2://"):
        url = "postgresql+asyncpg://" + url.split("://", 1)[1]

    connect_args: dict = {}
    if not url.startswith("postgresql+asyncpg://"):
        return url, connect_args  # sqlite (testes) etc. -- passa direto

    parts = urlsplit(url)
    query = dict(parse_qsl(parts.query))
    sslmode = query.pop("sslmode", None)
    query.pop("channel_binding", None)
    if query.pop("ssl", None) in ("require", "true", "1") or sslmode in ("require", "verify-ca", "verify-full"):
        connect_args["ssl"] = "require"
    url = urlunsplit(parts._replace(query=urlencode(query)))

    # Neon "-pooler" = PgBouncer em modo transação: prepared statements
    # nomeados do asyncpg colidem entre conexões ("prepared statement
    # __asyncpg_stmt_x__ already exists") -- desliga o cache e gera nome
    # único por statement.
    if "-pooler" in (parts.hostname or "") or IS_SERVERLESS:
        connect_args["statement_cache_size"] = 0
        connect_args["prepared_statement_cache_size"] = 0
    return url, connect_args


# Vercel injeta VERCEL=1 em todo runtime -- usado pra trocar pool de
# conexões por NullPool (instância serverless congela entre requisições,
# conexão de pool parada vira conexão morta).
IS_SERVERLESS = bool(os.environ.get("VERCEL"))


class Settings(BaseSettings):
    # App
    APP_NAME: str = "StockIQ"
    APP_VERSION: str = "1.1.0"
    # Só controla nível de log / detalhe de erro. Nunca re-lança exceção
    # pro cliente nem liga eco de SQL (isso é SQL_ECHO).
    DEBUG: bool = False
    SQL_ECHO: bool = False

    # Banco
    DATABASE_URL: str
    # Só o Alembic usa (driver síncrono). Opcional no runtime da API.
    DATABASE_URL_SYNC: str = ""

    # JWT -- 7 dias. O app ainda renova sozinho (troca o token do Firebase
    # por um JWT novo ao receber 401), então isso só reduz idas ao
    # /auth/login; desativar a conta continua valendo na hora porque
    # get_current_user checa is_active a cada requisição.
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = "./firebase-credentials.json"
    # Alternativa ao arquivo, pro deploy serverless (Vercel): conteúdo
    # inteiro do JSON da conta de serviço numa env var. Se setada, tem
    # prioridade sobre FIREBASE_CREDENTIALS_PATH.
    FIREBASE_CREDENTIALS_JSON: str = ""
    FIREBASE_PROJECT_ID: str = ""

    # Anthropic
    ANTHROPIC_API_KEY: str = ""
    ANTHROPIC_MODEL: str = "claude-sonnet-5-5"

    # CORS
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000"]

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def _split_origins(cls, v):
        # Aceita tanto JSON (["a","b"]) quanto "a,b" na env var.
        if isinstance(v, str) and not v.strip().startswith("["):
            return [o.strip() for o in v.split(",") if o.strip()]
        return v

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
