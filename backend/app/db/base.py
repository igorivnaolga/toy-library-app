from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass


# Import models for metadata registration (Alembic / create_all).
from app.models import booking as booking_model  # noqa: E402,F401
from app.models import category as category_model  # noqa: E402,F401
from app.models import loan as loan_model  # noqa: E402,F401
from app.models import toy as toy_model  # noqa: E402,F401
from app.models import toy_image as toy_image_model  # noqa: E402,F401
from app.models import profile as profile_model  # noqa: E402,F401
from app.models import duty_session as duty_session_model  # noqa: E402,F401
from app.models import device_token as device_token_model  # noqa: E402,F401
from app.models import push_notification_log as push_notification_log_model  # noqa: E402,F401
