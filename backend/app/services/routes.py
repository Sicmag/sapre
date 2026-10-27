from fastapi import APIRouter
from app.services.routing import compute_routes
from app.models.schemas import RouteRequest, RoutesResponse

router = APIRouter()

@router.post("/compute", response_model=RoutesResponse)
def compute(req: RouteRequest):
    routes = compute_routes(req.origin_lat, req.origin_lon, req.n_routes)
    return {"origin": [req.origin_lat, req.origin_lon], "routes": routes}