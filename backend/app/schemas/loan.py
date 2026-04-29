from pydantic import BaseModel


class LoanOut(BaseModel):
    loan_id: str
