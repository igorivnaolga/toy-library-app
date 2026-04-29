from pydantic import BaseModel


class BookingOut(BaseModel):
    booking_id: str
