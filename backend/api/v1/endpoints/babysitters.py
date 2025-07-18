from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from datetime import datetime
import uuid

from core.database import database
from core.security import get_current_user, uuid_to_string
from core.logging import logger
from db.models import babysitters
from schemas.babysitter import Babysitter, BabysitterCreate

router = APIRouter()

@router.get("/", response_model=List[Babysitter])
async def get_babysitters(current_user = Depends(get_current_user)):
    """
    Get all babysitters for the current user's family.
    """
    query = babysitters.select().where(
        babysitters.c.family_id == current_user['family_id']
    ).order_by(babysitters.c.created_at.desc())
    
    babysitter_records = await database.fetch_all(query)
    
    return [
        Babysitter(
            id=record['id'],
            first_name=record['first_name'],
            last_name=record['last_name'],
            phone_number=record['phone_number'],
            rate=record['rate'],
            notes=record['notes'],
            created_by_user_id=uuid_to_string(record['created_by_user_id']),
            created_at=record['created_at'].isoformat()
        )
        for record in babysitter_records
    ]

@router.post("/", response_model=Babysitter, status_code=status.HTTP_201_CREATED)
async def create_babysitter(babysitter: BabysitterCreate, current_user = Depends(get_current_user)):
    """
    Create a new babysitter for the current user's family.
    """
    values = {
        "first_name": babysitter.first_name,
        "last_name": babysitter.last_name,
        "phone_number": babysitter.phone_number,
        "rate": babysitter.rate,
        "notes": babysitter.notes,
        "family_id": current_user['family_id'],
        "created_by_user_id": current_user['id'],
        "created_at": datetime.utcnow()
    }
    
    query = babysitters.insert().values(**values)
    babysitter_id = await database.execute(query)
    
    # Fetch the created babysitter
    created_babysitter = await database.fetch_one(
        babysitters.select().where(babysitters.c.id == babysitter_id)
    )
    
    return Babysitter(
        id=created_babysitter['id'],
        first_name=created_babysitter['first_name'],
        last_name=created_babysitter['last_name'],
        phone_number=created_babysitter['phone_number'],
        rate=created_babysitter['rate'],
        notes=created_babysitter['notes'],
        created_by_user_id=uuid_to_string(created_babysitter['created_by_user_id']),
        created_at=created_babysitter['created_at'].isoformat()
    )

@router.put("/{babysitter_id}", response_model=Babysitter)
async def update_babysitter(
    babysitter_id: int, 
    babysitter: BabysitterCreate, 
    current_user = Depends(get_current_user)
):
    """
    Update an existing babysitter.
    """
    # Check if babysitter exists and belongs to user's family
    existing_babysitter = await database.fetch_one(
        babysitters.select().where(
            (babysitters.c.id == babysitter_id) & 
            (babysitters.c.family_id == current_user['family_id'])
        )
    )
    
    if not existing_babysitter:
        raise HTTPException(status_code=404, detail="Babysitter not found")
    
    values = {
        "first_name": babysitter.first_name,
        "last_name": babysitter.last_name,
        "phone_number": babysitter.phone_number,
        "rate": babysitter.rate,
        "notes": babysitter.notes
    }
    
    query = babysitters.update().where(
        babysitters.c.id == babysitter_id
    ).values(**values)
    
    await database.execute(query)
    
    # Fetch the updated babysitter
    updated_babysitter = await database.fetch_one(
        babysitters.select().where(babysitters.c.id == babysitter_id)
    )
    
    return Babysitter(
        id=updated_babysitter['id'],
        first_name=updated_babysitter['first_name'],
        last_name=updated_babysitter['last_name'],
        phone_number=updated_babysitter['phone_number'],
        rate=updated_babysitter['rate'],
        notes=updated_babysitter['notes'],
        created_by_user_id=uuid_to_string(updated_babysitter['created_by_user_id']),
        created_at=updated_babysitter['created_at'].isoformat()
    )

@router.delete("/{babysitter_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_babysitter(babysitter_id: int, current_user = Depends(get_current_user)):
    """
    Delete a babysitter.
    """
    # Check if babysitter exists and belongs to user's family
    existing_babysitter = await database.fetch_one(
        babysitters.select().where(
            (babysitters.c.id == babysitter_id) & 
            (babysitters.c.family_id == current_user['family_id'])
        )
    )
    
    if not existing_babysitter:
        raise HTTPException(status_code=404, detail="Babysitter not found")
    
    query = babysitters.delete().where(babysitters.c.id == babysitter_id)
    await database.execute(query)
    
    return None
