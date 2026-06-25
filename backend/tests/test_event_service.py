from datetime import time

from app.schemas.event import EventSlotCreateIn
from app.services.event_service import _slots_payload


def test_slots_payload_accepts_models() -> None:
    slots = [
        EventSlotCreateIn(
            start_time=time(10, 0),
            end_time=time(12, 0),
            capacity=5,
            audience="member",
        )
    ]
    payload = _slots_payload(slots)
    assert payload == [
        {
            "start_time": time(10, 0),
            "end_time": time(12, 0),
            "capacity": 5,
            "audience": "member",
        }
    ]


def test_slots_payload_accepts_dicts() -> None:
    slots = [
        {
            "start_time": time(9, 30),
            "end_time": time(11, 0),
            "capacity": 3,
            "audience": "volunteer",
        }
    ]
    payload = _slots_payload(slots)
    assert payload == slots
