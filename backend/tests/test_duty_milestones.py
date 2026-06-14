from app.services.duty_service import duty_booking_milestone_message


def test_duty_booking_milestone_message_third_shift() -> None:
    message = duty_booking_milestone_message(3)
    assert message is not None
    assert "third" in message.lower()
    assert "thank" in message.lower()


def test_duty_booking_milestone_message_other_counts() -> None:
    assert duty_booking_milestone_message(1) is None
    assert duty_booking_milestone_message(2) is None
    assert duty_booking_milestone_message(4) is None
