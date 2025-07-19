from pydantic import BaseModel
from typing import Optional, Union
from datetime import date, datetime
from uuid import UUID

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
    family_id: Union[str, UUID]
    user_id: Union[str, UUID]
    author_name: str  # Will be populated from user data
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True 