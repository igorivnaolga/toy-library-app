from pydantic import BaseModel


class ToyOut(BaseModel):
    toy_id: str
    name: str
