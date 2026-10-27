from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from app.services.vision import process_frame
from app.services.graph_service import upsert_plate_detection
from app.services.audit_service import log
from pydantic import BaseModel
from datetime import datetime

router = APIRouter()

class PlateDetection(BaseModel):
    plate: str
    confidence: float
    vehicle_type: str
    source_id: str

@router.post("/detect", response_model=list[PlateDetection])
async def detect(
    file: UploadFile = File(...),
    source_id: str = Form(...),
    legal_basis: str = Form(...),
    operator_id: str = Form(...),
):
    if not legal_basis.strip():
        raise HTTPException(status_code=400, detail="Base legal obligatoria")
    content = await file.read()
    detections = process_frame(content)
    results = []
    for d in detections:
        if d["confidence"] < 0.5:
            continue
        upsert_plate_detection(d["plate"], source_id, legal_basis)
        log(operator_id, "plate_detected", d["plate"], {
            "source_id": source_id, "confidence": d["confidence"], "legal_basis": legal_basis,
        })
        results.append(PlateDetection(**d, source_id=source_id))
    return results
