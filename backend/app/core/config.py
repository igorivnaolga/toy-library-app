from pydantic import BaseModel


class Settings(BaseModel):
    app_name: str = "Toy Library API"


settings = Settings()
