from pydantic import BaseModel
from typing import Optional, Dict, Any
from enum import Enum

class SchedulePatternType(str, Enum):
    weekly = "weekly"
    alternatingWeeks = "alternatingWeeks"
    alternatingDays = "alternatingDays"
    custom = "custom"

class WeeklySchedulePattern(BaseModel):
    sunday: Optional[str] = None
    monday: Optional[str] = None
    tuesday: Optional[str] = None
    wednesday: Optional[str] = None
    thursday: Optional[str] = None
    friday: Optional[str] = None
    saturday: Optional[str] = None

class AlternatingWeeksPattern(BaseModel):
    week1: WeeklySchedulePattern
    week2: WeeklySchedulePattern

class ScheduleTemplateCreate(BaseModel):
    name: str
    description: Optional[str] = None
    patternType: SchedulePatternType
    weeklyPattern: Optional[WeeklySchedulePattern] = None
    alternatingWeeksPattern: Optional[AlternatingWeeksPattern] = None
    isActive: bool = True

    class Config:
        use_enum_values = True

class ScheduleTemplate(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    patternType: SchedulePatternType
    weeklyPattern: Optional[WeeklySchedulePattern] = None
    alternatingWeeksPattern: Optional[AlternatingWeeksPattern] = None
    isActive: bool
    familyId: int
    createdAt: str
    updatedAt: str

    class Config:
        use_enum_values = True

class ScheduleApplication(BaseModel):
    templateId: int
    startDate: str  # ISO date string
    endDate: str    # ISO date string
    overwriteExisting: bool = False

class ScheduleApplicationResponse(BaseModel):
    daysApplied: int
    message: Optional[str] = None 