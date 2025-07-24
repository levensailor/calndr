import json
import traceback
from typing import List, Optional
from datetime import date, datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.dialects import postgresql
from sqlalchemy import text

from core.database import database
from core.security import get_current_user
from core.logging import logger
from db.models import events
from schemas.event import LegacyEvent

router = APIRouter()

@router.get("/{year}/{month}")
async def get_events_by_month(year: int, month: int, current_user = Depends(get_current_user)):
    """
    Returns all events for the specified month, including family events, school events, and daycare events.
    """
    logger.info(f"Getting events for {year}/{month}")
    # Calculate start and end dates for the month
    start_date = date(year, month, 1)
    if month == 12:
        end_date = date(year + 1, 1, 1) - timedelta(days=1)
    else:
        end_date = date(year, month + 1, 1) - timedelta(days=1)
    
    try:
        # Try to use the family_all_events view first
        query = text("""
            SELECT 
                id,
                event_date,
                title as content,
                description,
                event_type,
                start_time,
                end_time,
                all_day,
                source_type,
                provider_id,
                provider_name
            FROM family_all_events
            WHERE family_id = :family_id
            AND event_date BETWEEN :start_date AND :end_date
            ORDER BY event_date, start_time
        """)
        
        db_events = await database.fetch_all(
            query, 
            {
                'family_id': current_user['family_id'],
                'start_date': start_date,
                'end_date': end_date
            }
        )
    except Exception as e:
        # Fallback to legacy events table if view doesn't exist
        logger.warning(f"family_all_events view not available, using fallback query: {e}")
        
        # Use the traditional events table query
        query = events.select().where(
            (events.c.family_id == current_user['family_id']) &
            (events.c.date.between(start_date, end_date)) &
            (events.c.event_type != 'custody')  # Exclude custody events
        )
        db_events = await database.fetch_all(query)
        
        # Convert to expected format for legacy events
        legacy_events = []
        for event in db_events:
            legacy_events.append({
                'id': event['id'],
                'event_date': event['date'],
                'content': event['content'],
                'description': None,
                'event_type': event['event_type'],
                'start_time': None,
                'end_time': None,
                'all_day': False,
                'source_type': 'family',
                'provider_id': None,
                'provider_name': None
            })
        db_events = legacy_events
    
    # Convert events to the format expected by frontend
    frontend_events = []
    try:
        for event in db_events:
            # Format content based on source type
            content = event['content']
            if event.get('source_type') == 'school' and event.get('provider_name'):
                content = f"[{event['provider_name']}] {content}"
            elif event.get('source_type') == 'daycare' and event.get('provider_name'):
                content = f"[{event['provider_name']}] {content}"
            
            event_data = {
                'id': event['id'],
                'family_id': str(current_user['family_id']),
                'event_date': str(event['event_date']),
                'content': content,
                'source_type': event.get('source_type', 'family'),
                'event_type': event.get('event_type', 'regular')
            }
            
            # Add optional fields if they exist
            if event.get('description'):
                event_data['description'] = event['description']
            if event.get('start_time'):
                event_data['start_time'] = str(event['start_time'])
            if event.get('end_time'):
                event_data['end_time'] = str(event['end_time'])
            if event.get('all_day') is not None:
                event_data['all_day'] = event['all_day']
                
            frontend_events.append(event_data)
    except Exception as e:
        logger.error(f"Error processing event records for /api/events/{{year}}/{{month}}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Error processing event data")
        
    logger.info(f"Payload for /api/events/{{year}}/{{month}}: {json.dumps(frontend_events, indent=2)}")
    return frontend_events

@router.get("/")
async def get_events_by_date_range(
    start_date: str = Query(..., description="Start date in YYYY-MM-DD format"), 
    end_date: str = Query(..., description="End date in YYYY-MM-DD format"), 
    current_user = Depends(get_current_user)
):
    """
    Returns all events for the specified date range (iOS app compatibility).
    Includes family events, school events, and daycare events.
    """
    logger.info(f"iOS app requesting events from {start_date} to {end_date}")
    
    if not start_date or not end_date:
        raise HTTPException(status_code=400, detail="start_date and end_date query parameters are required")
    
    try:
        start_date_obj = datetime.strptime(start_date, '%Y-%m-%d').date()
        end_date_obj = datetime.strptime(end_date, '%Y-%m-%d').date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    
    try:
        # Try to use the family_all_events view first
        query = text("""
            SELECT 
                id,
                event_date,
                title as content,
                description,
                event_type,
                start_time,
                end_time,
                all_day,
                source_type,
                provider_id,
                provider_name
            FROM family_all_events
            WHERE family_id = :family_id
            AND event_date BETWEEN :start_date AND :end_date
            ORDER BY event_date, start_time
        """)
        
        db_events = await database.fetch_all(
            query, 
            {
                'family_id': current_user['family_id'],
                'start_date': start_date_obj,
                'end_date': end_date_obj
            }
        )
    except Exception as e:
        # Fallback to legacy events table if view doesn't exist
        logger.warning(f"family_all_events view not available, using fallback query: {e}")
        
        # Use the traditional events table query
        query = events.select().where(
            (events.c.family_id == current_user['family_id']) &
            (events.c.date.between(start_date_obj, end_date_obj)) &
            (events.c.event_type != 'custody')  # Exclude custody events
        )
        db_events = await database.fetch_all(query)
        
        # Convert to expected format for legacy events
        legacy_events = []
        for event in db_events:
            legacy_events.append({
                'id': event['id'],
                'event_date': event['date'],
                'content': event['content'],
                'description': None,
                'event_type': event['event_type'],
                'start_time': None,
                'end_time': None,
                'all_day': False,
                'source_type': 'family',
                'provider_id': None,
                'provider_name': None
            })
        db_events = legacy_events
    
    # Convert events to the format expected by iOS app
    frontend_events = []
    try:
        for event in db_events:
            # Format content based on source type
            content = event['content']
            if event.get('source_type') == 'school' and event.get('provider_name'):
                content = f"[{event['provider_name']}] {content}"
            elif event.get('source_type') == 'daycare' and event.get('provider_name'):
                content = f"[{event['provider_name']}] {content}"
            
            event_data = {
                'id': event['id'],
                'family_id': str(current_user['family_id']),
                'event_date': str(event['event_date']),
                'content': content,
                'source_type': event.get('source_type', 'family'),
                'event_type': event.get('event_type', 'regular')
            }
            
            # Add optional fields if they exist
            if event.get('description'):
                event_data['description'] = event['description']
            if event.get('start_time'):
                event_data['start_time'] = str(event['start_time'])
            if event.get('end_time'):
                event_data['end_time'] = str(event['end_time'])
            if event.get('all_day') is not None:
                event_data['all_day'] = event['all_day']
                
            frontend_events.append(event_data)
    except Exception as e:
        logger.error(f"Error processing event records for /api/events: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Error processing event data")
        
    return frontend_events

@router.post("/")
async def save_event(request: dict, current_user = Depends(get_current_user)):
    """
    Handles non-custody events only. Custody events should use the /api/custody endpoint.
    """
    logger.info(f"Saving event: {request}")
    try:
        logger.info(f"Received event request: {request}")
        
        # Check if this is a custody event (position 4) and reject it
        if 'position' in request and request['position'] == 4:
            logger.error(f"Rejecting custody event - position 4 should use /api/custody endpoint")
            raise HTTPException(status_code=400, detail="Custody events should use /api/custody endpoint")
        
        # Handle event format - position is now optional
        if 'event_date' in request and 'content' in request:
            legacy_event = LegacyEvent(**request)
            logger.info(f"Created LegacyEvent object: {legacy_event}")
            
            event_date = datetime.strptime(legacy_event.event_date, '%Y-%m-%d').date()
            logger.info(f"Parsed event_date: {event_date}")
            
            logger.info(f"Creating insert query with values:")
            logger.info(f"  - family_id: {current_user['family_id']}")
            logger.info(f"  - date: {event_date}")
            logger.info(f"  - content: {legacy_event.content}")
            logger.info(f"  - position: {legacy_event.position}")
            logger.info(f"  - event_type: 'regular'")
            
            insert_query = events.insert().values(
                family_id=current_user['family_id'],
                date=event_date,
                content=legacy_event.content,
                position=legacy_event.position,  # Can be None now
                event_type='regular'
            )
            logger.info(f"Insert query created successfully")
            logger.info(f"About to execute database insert...")
            
            event_id = await database.execute(insert_query)
            logger.info(f"Successfully executed insert, got event_id: {event_id}")
            
            logger.info(f"Successfully created event with ID {event_id}: content={legacy_event.content}")
            
            return {
                'id': event_id,  # Return the actual database-generated ID
                'event_date': legacy_event.event_date,
                'content': legacy_event.content,
                'position': legacy_event.position
            }
        else:
            logger.error(f"Invalid event format - missing required fields")
            logger.error(f"Request keys: {list(request.keys())}")
            raise HTTPException(status_code=400, detail="Invalid event format - event_date and content are required")
    
    except HTTPException:
        logger.error(f"HTTPException occurred")
        raise
    except Exception as e:
        logger.error(f"Exception in save_event: {e}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.put("/{event_id}")
async def update_event(event_id: int, request: dict, current_user = Depends(get_current_user)):
    """
    Updates an existing non-custody event.
    """
    logger.info(f"Updating event {event_id}: {request}")
    try:
        # Check if this is a custody event (position 4) and reject it
        if 'position' in request and request['position'] == 4:
            logger.error(f"Rejecting custody event - position 4 should use /api/custody endpoint")
            raise HTTPException(status_code=400, detail="Custody events should use /api/custody endpoint")
        
        # Verify the event exists and belongs to the user's family
        verify_query = events.select().where(
            (events.c.id == event_id) & 
            (events.c.family_id == current_user['family_id']) &
            (events.c.event_type != 'custody')
        )
        existing_event = await database.fetch_one(verify_query)
        
        if not existing_event:
            raise HTTPException(status_code=404, detail="Event not found or access denied")
        
        # Handle event format - position is now optional
        if 'event_date' in request and 'content' in request:
            legacy_event = LegacyEvent(**request)
            event_date = datetime.strptime(legacy_event.event_date, '%Y-%m-%d').date()
            
            # Update the event
            update_query = events.update().where(events.c.id == event_id).values(
                date=event_date,
                content=legacy_event.content,
                position=legacy_event.position  # Can be None now
            )
            await database.execute(update_query)
            
            logger.info(f"Successfully updated event {event_id}: content={legacy_event.content}")
            
            return {
                'id': event_id,
                'event_date': legacy_event.event_date,
                'content': legacy_event.content,
                'position': legacy_event.position
            }
        else:
            raise HTTPException(status_code=400, detail="Invalid event format - event_date and content are required")
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Exception in update_event: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.delete("/{event_id}")
async def delete_event(event_id: int, current_user = Depends(get_current_user)):
    """
    Deletes an existing non-custody event.
    """
    logger.info(f"Deleting event {event_id}")
    try:
        # Verify the event exists and belongs to the user's family
        verify_query = events.select().where(
            (events.c.id == event_id) & 
            (events.c.family_id == current_user['family_id']) &
            (events.c.event_type != 'custody')
        )
        existing_event = await database.fetch_one(verify_query)
        
        if not existing_event:
            raise HTTPException(status_code=404, detail="Event not found or access denied")
        
        # Delete the event
        delete_query = events.delete().where(events.c.id == event_id)
        await database.execute(delete_query)
        
        logger.info(f"Successfully deleted event {event_id}")
        return {"status": "success", "message": "Event deleted successfully"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Exception in delete_event: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
