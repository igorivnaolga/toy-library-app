import pytest
from pydantic import ValidationError

from app.schemas.principal import RegistrationCompleteIn


def _valid_payload(**overrides):
    base = {
        "full_name": "Jane Smith",
        "address_line1": "12 Example Street",
        "suburb": "Christchurch",
        "mobile_phone": "021 123 4567",
        "alt_contact_name": "Alex Jones",
        "alt_contact_address": "45 Other Road",
        "alt_contact_phone": "021 987 6543",
        "heard_about_us": "Friend",
        "membership_tier": "non_duty",
        "terms_accepted": True,
        "liability_accepted": True,
        "text_reminders_consent": True,
    }
    base.update(overrides)
    return base


def test_registration_accepts_valid_payload():
    payload = RegistrationCompleteIn(**_valid_payload())
    assert payload.full_name == "Jane Smith"
    assert payload.mobile_phone == "021 123 4567"


@pytest.mark.parametrize(
    "full_name",
    ["Jane", "J", "Jane 123", ""],
)
def test_registration_rejects_invalid_full_name(full_name):
    with pytest.raises(ValidationError):
        RegistrationCompleteIn(**_valid_payload(full_name=full_name))


def test_registration_rejects_invalid_email_fields_via_phone():
    with pytest.raises(ValidationError):
        RegistrationCompleteIn(**_valid_payload(mobile_phone="abc"))


def test_registration_requires_heard_about_us():
    with pytest.raises(ValidationError):
        RegistrationCompleteIn(**_valid_payload(heard_about_us=" "))


def test_registration_requires_alternative_contact():
    with pytest.raises(ValidationError):
        RegistrationCompleteIn(**_valid_payload(alt_contact_name=" "))


def test_registration_accepts_child_name():
    payload = RegistrationCompleteIn(
        **_valid_payload(
            kids=[{"name": "Sam", "birth_date": "2020-01-01"}],
        )
    )
    assert payload.kids[0].name == "Sam"


def test_registration_rejects_invalid_child_name():
    with pytest.raises(ValidationError):
        RegistrationCompleteIn(
            **_valid_payload(
                kids=[{"name": "Sam123", "birth_date": "2020-01-01"}],
            )
        )
