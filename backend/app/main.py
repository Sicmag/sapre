from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.api import plates, graph, routes, alerts, audit

app = FastAPI(
    title=settings.app_name,
    description="Sistema de AnalÃ­tica Predictiva para Rutas de Escape - Fase 1",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(plates.router, prefix="/api/v1/plates", tags=["Placas"])
app.include_router(graph.router, prefix="/api/v1/graph", tags=["Grafo"])
app.include_router(routes.router, prefix="/api/v1/routes", tags=["Rutas"])
app.include_router(alerts.router, prefix="/api/v1/alerts", tags=["Alertas"])
app.include_router(audit.router, prefix="/api/v1/audit", tags=["AuditorÃ­a"])

@app.get("/health")
def health():
    return {"status": "ok", "app": settings.app_name, "env": settings.app_env}
