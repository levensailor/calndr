from pydantic import BaseModel
from typing import Optional
from datetime import date, datetime

class JournalEntryBase(BaseModel):
    title: Optional[str] = None
    content: str
    entry_date: date

class JournalEntryCreate(JournalEntryBase):
    pass

class JournalEntryUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    entry_date: Optional[date] = None

class JournalEntry(JournalEntryBase):
    id: int
    family_id: str
    user_id: str
    author_name: str  # Will be populated from user data
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True 