from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from datetime import datetime
import uuid
from app.services.audit_service import log
from app.config import settings

router = APIRouter()

class AlertCreate(BaseModel):
    plate: str
    operator_id: str
    operator_note: str

class AlertResponse(BaseModel):
    alert_id: str
    status: str
    created_at: datetime
    requires_human_validation: bool

@router.post("/validate", response_model=AlertResponse)
def validate_alert(alert: AlertCreate):
    if settings.require_human_validation and not alert.operator_note.strip():
        raise HTTPException(status_code=400, detail="Nota del operador requerida")
    alert_id = str(uuid.uuid4())
    log(alert.operator_id, "alert_validated", alert_id, {
        "plate": alert.plate, "note": alert.operator_note
    })
    return {
        "alert_id": alert_id, "status": "validated", 
        "created_at": datetime.utcnow(), "requires_human_validation": True
    }
