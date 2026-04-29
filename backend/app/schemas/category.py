from pydantic import BaseModel


class CategoryOut(BaseModel):
    code: str
    name: str
