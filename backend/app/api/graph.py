from fastapi import APIRouter, HTTPException
from app.services.graph_service import get_nexos_by_plate
from pydantic import BaseModel
from typing import List

router = APIRouter()

class GraphNode(BaseModel):
    id: str
    type: str
    label: str
    legal_basis: str

class NexosResponse(BaseModel):
    plate: str
    nodes: List[GraphNode]
    relations: List[dict]

@router.get("/nexos/{plate}", response_model=NexosResponse)
def nexos_by_plate(plate: str):
    data = get_nexos_by_plate(plate)
    if not data["nodes"]:
        raise HTTPException(status_code=404, detail="Placa sin nexos registrados")
    return data
