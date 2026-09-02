from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

BR_TZ = ZoneInfo("America/Sao_Paulo")


def now_br() -> datetime:
    return datetime.now(BR_TZ)


def br_day_range(days: int = 1) -> tuple[datetime, datetime]:
    """Janela de `days` dias corridos no calendário de Brasília, terminando
    agora. days=1 = "hoje" (desde a meia-noite BR). Retorna em UTC, porque
    é assim que created_at é gravado no banco."""
    end_br = now_br()
    start_br = (end_br - timedelta(days=days - 1)).replace(hour=0, minute=0, second=0, microsecond=0)
    return start_br.astimezone(timezone.utc), end_br.astimezone(timezone.utc)
