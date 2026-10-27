from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_env: str = "development"
    app_name: str = "SAPRE"

    neo4j_uri: str = "bolt://neo4j:7687"
    neo4j_user: str = "neo4j"
    neo4j_password: str = "neo4j"

    postgres_user: str = "sapre"
    postgres_password: str = "sapre"
    postgres_db: str = "sapre"
    postgres_host: str = "postgis"
    postgres_port: int = 5432

    audit_log_path: str = "/app/logs/audit.log"

    routing_city: str = "Bogota, Colombia"
    routing_penalty_cai: float = 0.7
    routing_penalty_congestion: float = 0.5

    max_queries_per_hour: int = 200
    require_human_validation: bool = True

    class Config:
        env_file = ".env"

settings = Settings()
