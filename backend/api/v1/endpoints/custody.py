import uuid
from typing import List
from datetime import date, datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status

from core.database import database
from core.security import get_current_user, uuid_to_string
from core.logging import logger
from db.models import custody, users
from schemas.custody import CustodyRecord, CustodyResponse
from services.notification_service import send_custody_change_notification

router = APIRouter()

@router.get("/{year}/{month}", response_model=List[CustodyResponse])
async def get_custody_records(year: int, month: int, current_user = Depends(get_current_user)):
    """
    Returns custody records for the specified month.
    """
    try:
        family_id = current_user['family_id']
        # Calculate start and end dates for the month
        start_date = date(year, month, 1)
        if month == 12:
            end_date = date(year, 1, 1) + timedelta(days=31)
            end_date = end_date.replace(day=1) - timedelta(days=1)
        else:
            end_date = date(year, month + 1, 1) - timedelta(days=1)
        
        # Query custody records for the given month and family
        query = custody.select().where(
            (custody.c.family_id == family_id) &
            (custody.c.date.between(start_date, end_date))
        )
        
        db_records = await database.fetch_all(query)
        
        # Get all user data for the family in a single query
        user_query = users.select().where(users.c.family_id == family_id)
        family_users = await database.fetch_all(user_query)
        user_map = {uuid_to_string(user['id']): user['first_name'] for user in family_users}
        
        # Convert records to CustodyResponse format
        custody_responses = [
            CustodyResponse(
                id=record['id'],
                event_date=str(record['date']),
                content=user_map.get(uuid_to_string(record['custodian_id']), "Unknown"),
                custodian_id=uuid_to_string(record['custodian_id']),
                handoff_day=record['handoff_day'],
                handoff_time=record['handoff_time'].strftime('%H:%M') if record['handoff_time'] else None,
                handoff_location=record['handoff_location']
            ) for record in db_records
        ]
        
        return custody_responses
    except Exception as e:
        logger.error(f"Error fetching custody records: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@router.post("/", response_model=CustodyResponse)
async def set_custody(custody_data: CustodyRecord, current_user = Depends(get_current_user)):
    """
    Creates or updates a custody record for a specific date.
    """
    logger.info(f"Received custody update request: {custody_data.model_dump_json(indent=2)}")
    
    family_id = current_user['family_id']
    actor_id = current_user['id']
    
    try:
        # Check if a record already exists for this date
        existing_record_query = custody.select().where(
            (custody.c.family_id == family_id) &
            (custody.c.date == custody_data.date)
        )
        existing_record = await database.fetch_one(existing_record_query)
        
        # If handoff_day is not provided, determine it based on default logic
        handoff_day_value = custody_data.handoff_day
        if handoff_day_value is None and custody_data.handoff_time is not None:
            # If handoff time is provided but handoff_day is not, assume it's a handoff day
            handoff_day_value = True
        elif handoff_day_value is None:
            # Default logic: check if previous day has different custodian
            previous_date = custody_data.date - timedelta(days=1)
            previous_record = await database.fetch_one(
                custody.select().where(
                    (custody.c.family_id == family_id) &
                    (custody.c.date == previous_date)
                )
            )
            if previous_record and previous_record['custodian_id'] != custody_data.custodian_id:
                handoff_day_value = True
                
                # Set default handoff time and location if not provided
                if not custody_data.handoff_time:
                    weekday = custody_data.date.weekday()  # Monday = 0, Sunday = 6
                    is_weekend = weekday >= 5  # Saturday = 5, Sunday = 6
                    if is_weekend:
                        custody_data.handoff_time = "12:00"  # Noon for weekends
                        if not custody_data.handoff_location:
                            # Get target custodian name for location
                            target_user = await database.fetch_one(users.select().where(users.c.id == custody_data.custodian_id))
                            target_name = target_user['first_name'].lower() if target_user else "unknown"
                            custody_data.handoff_location = f"{target_name}'s home"
                    else:
                        custody_data.handoff_time = "17:00"  # 5pm for weekdays
                        if not custody_data.handoff_location:
                            custody_data.handoff_location = "daycare"
            else:
                handoff_day_value = False

        if existing_record:
            # Update existing record
            update_query = custody.update().where(custody.c.id == existing_record['id']).values(
                custodian_id=custody_data.custodian_id,
                actor_id=actor_id,
                handoff_day=handoff_day_value,
                handoff_time=datetime.strptime(custody_data.handoff_time, '%H:%M').time() if custody_data.handoff_time else None,
                handoff_location=custody_data.handoff_location
            )
            await database.execute(update_query)
            record_id = existing_record['id']
        else:
            # Insert new record
            insert_query = custody.insert().values(
                family_id=family_id,
                date=custody_data.date,
                custodian_id=custody_data.custodian_id,
                actor_id=actor_id,
                handoff_day=handoff_day_value,
                handoff_time=datetime.strptime(custody_data.handoff_time, '%H:%M').time() if custody_data.handoff_time else None,
                handoff_location=custody_data.handoff_location,
                created_at=datetime.now()
            )
            record_id = await database.execute(insert_query)
            
        # Send push notification to the other parent
        await send_custody_change_notification(sender_id=actor_id, family_id=family_id, event_date=custody_data.date)
            
        # Get custodian name for response
        custodian_user = await database.fetch_one(users.select().where(users.c.id == custody_data.custodian_id))
        custodian_name = custodian_user['first_name'] if custodian_user else "Unknown"

        return CustodyResponse(
            id=record_id,
            event_date=str(custody_data.date),
            content=custodian_name,
            custodian_id=str(custody_data.custodian_id),
            handoff_day=handoff_day_value,
            handoff_time=custody_data.handoff_time,
            handoff_location=custody_data.handoff_location
        )
    except Exception as e:
        logger.error(f"Error setting custody: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error while setting custody: {e}")
