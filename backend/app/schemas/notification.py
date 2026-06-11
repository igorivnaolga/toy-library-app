from pydantic import BaseModel, Field


class DeviceTokenRegisterIn(BaseModel):
    token: str = Field(min_length=10, max_length=512)
    platform: str = Field(default="android", max_length=16)


class DeviceTokenUnregisterIn(BaseModel):
    token: str = Field(min_length=10, max_length=512)


class DeviceTokenOut(BaseModel):
    registered: bool = True


class MemberPushRemindersResult(BaseModel):
    slot: str
    reminders_found: int
    sent: int
    skipped_already_sent: int
    failed: int
    firebase_configured: bool
