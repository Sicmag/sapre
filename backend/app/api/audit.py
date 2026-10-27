from fastapi import APIRouter
from fastapi.responses import PlainTextResponse
from app.config import settings

router = APIRouter()

@router.get("/tail", response_class=PlainTextResponse)
def tail(lines: int = 50):
    try:
        with open(settings.audit_log_path, "r", encoding="utf-8") as f:
            content = f.readlines()[-lines:]
        return "".join(content)
    except FileNotFoundError:
        return "Sin registros de auditorÃ­a aÃºn."
