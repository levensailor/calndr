import uuid
from typing import Optional
from datetime import date
from pydantic import BaseModel

class CustodyRecord(BaseModel):
    id: Optional[int] = None
    date: date
    custodian_id: uuid.UUID
    handoff_time: Optional[str] = None
    handoff_location: Optional[str] = None
    handoff_day: Optional[bool] = None

class CustodyResponse(BaseModel):
    id: int
    event_date: str
    content: str
    position: int = 4  # Always 4 for custody
    custodian_id: str
    handoff_day: Optional[bool] = None
    handoff_time: Optional[str] = None
    handoff_location: Optional[str] = None
