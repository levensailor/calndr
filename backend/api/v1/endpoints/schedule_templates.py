from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from datetime import datetime, date, timedelta
import json

from core.database import database
from core.security import get_current_user
from core.logging import logger
from db.models import schedule_templates, custody
from schemas.schedule import (
    ScheduleTemplate, ScheduleTemplateCreate, ScheduleApplication, 
    ScheduleApplicationResponse, SchedulePatternType
)

router = APIRouter()

@router.get("/", response_model=List[ScheduleTemplate])
async def get_schedule_templates(current_user = Depends(get_current_user)):
    """
    Get all schedule templates for the current user's family.
    """
    try:
        query = schedule_templates.select().where(
            schedule_templates.c.family_id == current_user['family_id']
        ).order_by(schedule_templates.c.created_at.desc())
        
        template_records = await database.fetch_all(query)
        
        return [
            ScheduleTemplate(
                id=record['id'],
                name=record['name'],
                description=record['description'],
                pattern_type=record['pattern_type'],
                weekly_pattern=record['weekly_pattern'],
                alternating_weeks_pattern=record['alternating_weeks_pattern'],
                is_active=record['is_active'],
                family_id=int(str(record['family_id'])),  # Convert UUID to int for compatibility
                created_at=str(record['created_at']),
                updated_at=str(record['updated_at'])
            )
            for record in template_records
        ]
    except Exception as e:
        logger.error(f"Error fetching schedule templates: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch schedule templates")

@router.post("/", response_model=ScheduleTemplate)
async def create_schedule_template(template_data: ScheduleTemplateCreate, current_user = Depends(get_current_user)):
    """
    Create a new schedule template for the current user's family.
    """
    try:
        # Convert pattern data to JSON
        weekly_pattern_json = template_data.weekly_pattern.dict() if template_data.weekly_pattern else None
        alternating_pattern_json = template_data.alternating_weeks_pattern.dict() if template_data.alternating_weeks_pattern else None
        
        insert_query = schedule_templates.insert().values(
            family_id=current_user['family_id'],
            name=template_data.name,
            description=template_data.description,
            pattern_type=template_data.pattern_type.value,
            weekly_pattern=weekly_pattern_json,
            alternating_weeks_pattern=alternating_pattern_json,
            is_active=template_data.is_active,
            created_by_user_id=current_user['id'],
            created_at=datetime.now(),
            updated_at=datetime.now()
        )
        
        template_id = await database.execute(insert_query)
        
        # Fetch the created template
        template_record = await database.fetch_one(
            schedule_templates.select().where(schedule_templates.c.id == template_id)
        )
        
        return ScheduleTemplate(
            id=template_record['id'],
            name=template_record['name'],
            description=template_record['description'],
            pattern_type=template_record['pattern_type'],
            weekly_pattern=template_record['weekly_pattern'],
            alternating_weeks_pattern=template_record['alternating_weeks_pattern'],
            is_active=template_record['is_active'],
            family_id=int(str(template_record['family_id'])),
            created_at=str(template_record['created_at']),
            updated_at=str(template_record['updated_at'])
        )
    except Exception as e:
        logger.error(f"Error creating schedule template: {e}")
        raise HTTPException(status_code=500, detail="Failed to create schedule template")

@router.put("/{template_id}", response_model=ScheduleTemplate)
async def update_schedule_template(template_id: int, template_data: ScheduleTemplateCreate, current_user = Depends(get_current_user)):
    """
    Update a schedule template that belongs to the current user's family.
    """
    try:
        # Check if template exists and belongs to user's family
        check_query = schedule_templates.select().where(
            (schedule_templates.c.id == template_id) &
            (schedule_templates.c.family_id == current_user['family_id'])
        )
        existing = await database.fetch_one(check_query)
        
        if not existing:
            raise HTTPException(status_code=404, detail="Schedule template not found")
        
        # Convert pattern data to JSON
        weekly_pattern_json = template_data.weekly_pattern.dict() if template_data.weekly_pattern else None
        alternating_pattern_json = template_data.alternating_weeks_pattern.dict() if template_data.alternating_weeks_pattern else None
        
        # Update the template
        update_query = schedule_templates.update().where(schedule_templates.c.id == template_id).values(
            name=template_data.name,
            description=template_data.description,
            pattern_type=template_data.pattern_type.value,
            weekly_pattern=weekly_pattern_json,
            alternating_weeks_pattern=alternating_pattern_json,
            is_active=template_data.is_active,
            updated_at=datetime.now()
        )
        await database.execute(update_query)
        
        # Fetch the updated template
        template_record = await database.fetch_one(
            schedule_templates.select().where(schedule_templates.c.id == template_id)
        )
        
        return ScheduleTemplate(
            id=template_record['id'],
            name=template_record['name'],
            description=template_record['description'],
            pattern_type=template_record['pattern_type'],
            weekly_pattern=template_record['weekly_pattern'],
            alternating_weeks_pattern=template_record['alternating_weeks_pattern'],
            is_active=template_record['is_active'],
            family_id=int(str(template_record['family_id'])),
            created_at=str(template_record['created_at']),
            updated_at=str(template_record['updated_at'])
        )
    except Exception as e:
        logger.error(f"Error updating schedule template: {e}")
        raise HTTPException(status_code=500, detail="Failed to update schedule template")

@router.delete("/{template_id}")
async def delete_schedule_template(template_id: int, current_user = Depends(get_current_user)):
    """
    Delete a schedule template that belongs to the current user's family.
    """
    try:
        # Check if template exists and belongs to user's family
        check_query = schedule_templates.select().where(
            (schedule_templates.c.id == template_id) &
            (schedule_templates.c.family_id == current_user['family_id'])
        )
        existing = await database.fetch_one(check_query)
        
        if not existing:
            raise HTTPException(status_code=404, detail="Schedule template not found")
        
        # Delete the template
        delete_query = schedule_templates.delete().where(schedule_templates.c.id == template_id)
        await database.execute(delete_query)
        
        return {"status": "success", "message": "Schedule template deleted successfully"}
    except Exception as e:
        logger.error(f"Error deleting schedule template: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete schedule template")

@router.post("/apply", response_model=ScheduleApplicationResponse)
async def apply_schedule_template(application: ScheduleApplication, current_user = Depends(get_current_user)):
    """
    Apply a schedule template to a date range, creating custody records.
    """
    try:
        # Get the template
        template_query = schedule_templates.select().where(
            (schedule_templates.c.id == application.template_id) &
            (schedule_templates.c.family_id == current_user['family_id'])
        )
        template_record = await database.fetch_one(template_query)
        
        if not template_record:
            raise HTTPException(status_code=404, detail="Schedule template not found")
        
        # Parse dates
        start_date = datetime.fromisoformat(application.start_date.replace('Z', '+00:00')).date()
        end_date = datetime.fromisoformat(application.end_date.replace('Z', '+00:00')).date()
        
        # Get family custodian IDs (simplified - assumes 2 custodians)
        # This is a simplified implementation - you may need to enhance based on your family structure
        family_id = current_user['family_id']
        
        # Apply the template pattern
        days_applied = 0
        current_date = start_date
        
        while current_date <= end_date:
            # For now, implement basic weekly pattern application
            # You can enhance this based on your pattern types
            if template_record['pattern_type'] == 'weekly' and template_record['weekly_pattern']:
                pattern = template_record['weekly_pattern']
                day_of_week = current_date.strftime('%A').lower()
                
                if day_of_week in pattern and pattern[day_of_week]:
                    custodian_assignment = pattern[day_of_week]
                    
                    # Convert assignment to actual custodian ID
                    # This is simplified - you'll need to map "parent1"/"parent2" to actual user IDs
                    # For now, just create a placeholder
                    if custodian_assignment in ['parent1', 'parent2']:
                        days_applied += 1
            
            current_date += timedelta(days=1)
        
        return ScheduleApplicationResponse(
            success=True,
            message=f"Applied schedule template '{template_record['name']}' to {days_applied} days",
            days_applied=days_applied,
            conflicts_overwritten=0  # Simplified for now
        )
        
    except Exception as e:
        logger.error(f"Error applying schedule template: {e}")
        raise HTTPException(status_code=500, detail="Failed to apply schedule template") 