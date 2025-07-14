import uuid
from typing import Optional
from datetime import date
from pydantic import BaseModel

class Event(BaseModel):
    id: Optional[int] = None
    date: date
    custodian_id: Optional[uuid.UUID] = None

# Legacy Event model for compatibility
class LegacyEvent(BaseModel):
    id: Optional[int] = None
    event_date: str
    content: str
    position: int
