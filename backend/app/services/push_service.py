import logging
from typing import Optional
from firebase_admin import messaging
from starlette.concurrency import run_in_threadpool

logger = logging.getLogger(__name__)


async def send_push(tokens: list[str], title: str, body: str, data: Optional[dict] = None) -> None:
    """
    Manda push via FCM pra uma lista de tokens de dispositivo. Tokens
    que o Firebase reporta como não-registrados (app desinstalado,
    permissão revogada) são removidos do banco -- senão a lista de
    tokens só cresce com lixo morto.
    """
    if not tokens:
        return

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in (data or {}).items()},
        tokens=tokens,
    )

    try:
        # messaging.send_each_for_multicast faz chamada HTTP síncrona --
        # roda em threadpool pra não travar o event loop do FastAPI.
        response = await run_in_threadpool(messaging.send_each_for_multicast, message)
    except Exception as exc:
        logger.warning("Falha ao enviar push FCM: %s", exc)
        return

    invalid_tokens = [
        tokens[i] for i, r in enumerate(response.responses)
        if not r.success and isinstance(r.exception, messaging.UnregisteredError)
    ]
    if invalid_tokens:
        from app.core.database import AsyncSessionLocal
        from app.repositories.device_token_repository import DeviceTokenRepository

        async with AsyncSessionLocal() as db:
            repo = DeviceTokenRepository(db)
            for token in invalid_tokens:
                await repo.delete_by_token(token)
            await db.commit()
