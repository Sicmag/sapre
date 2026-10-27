from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class PlateDetection(BaseModel):
    plate: str
    confidence: float = Field(ge=0, le=1)
    vehicle_type: Optional[str] = None
    image_ref: Optional[str] = None
    detected_at: datetime = Field(default_factory=datetime.utcnow)
    source_id: str = Field(description="ID de cámara o fuente autorizada")

class GraphNode(BaseModel):
    id: str
    type: str
    label: str
    legal_basis: str = Field(description="Base legal del dato (Ley 1581, convenio, etc.)")

class GraphRelation(BaseModel):
    source: str
    target: str
    type: str
    legal_basis: str
    valid_from: Optional[datetime] = None
    valid_to: Optional[datetime] = None

class NexosResponse(BaseModel):
    plate: str
    nodes: List[GraphNode]
    relations: List[GraphRelation]

class RouteRequest(BaseModel):
    origin_lat: float
    origin_lon: float
    destination_lat: Optional[float] = None
    destination_lon: Optional[float] = None
    n_routes: int = Field(default=3, ge=1, le=5)

class RouteResult(BaseModel):
    route_id: int
    score: float
    distance_m: float
    geometry: List[List[float]]
    penalized_cai: bool
    penalized_congestion: bool

class RoutesResponse(BaseModel):
    origin: List[float]
    routes: List[RouteResult]

class AlertCreate(BaseModel):
    plate_detection: PlateDetection
    nexos: Optional[NexosResponse] = None
    routes: Optional[RoutesResponse] = None
    operator_id: str
    operator_note: str

class AlertResponse(BaseModel):
    alert_id: str
    status: str
    created_at: datetime
    requires_human_validation: bool = True

class AuditEntry(BaseModel):
    timestamp: datetime
    actor: str
    action: str
    resource: str
    detail: dict
    hash: str