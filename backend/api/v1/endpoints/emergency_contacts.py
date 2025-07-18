from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from datetime import datetime
import uuid

from core.database import database
from core.security import get_current_user, uuid_to_string
from core.logging import logger
from db.models import emergency_contacts
from schemas.emergency_contact import EmergencyContact, EmergencyContactCreate

router = APIRouter()

@router.get("/", response_model=List[EmergencyContact])
async def get_emergency_contacts(current_user = Depends(get_current_user)):
    """
    Get all emergency contacts for the current user's family.
    """
    query = emergency_contacts.select().where(
        emergency_contacts.c.family_id == current_user['family_id']
    ).order_by(emergency_contacts.c.created_at.desc())
    
    contact_records = await database.fetch_all(query)
    
    return [
        EmergencyContact(
            id=record['id'],
            first_name=record['first_name'],
            last_name=record['last_name'],
            phone_number=record['phone_number'],
            relationship=record['relationship'],
            notes=record['notes'],
            created_by_user_id=uuid_to_string(record['created_by_user_id']),
            created_at=record['created_at'].isoformat()
        )
        for record in contact_records
    ]

@router.post("/", response_model=EmergencyContact, status_code=status.HTTP_201_CREATED)
async def create_emergency_contact(contact: EmergencyContactCreate, current_user = Depends(get_current_user)):
    """
    Create a new emergency contact for the current user's family.
    """
    values = {
        "first_name": contact.first_name,
        "last_name": contact.last_name,
        "phone_number": contact.phone_number,
        "relationship": contact.relationship,
        "notes": contact.notes,
        "family_id": current_user['family_id'],
        "created_by_user_id": current_user['id'],
        "created_at": datetime.utcnow()
    }
    
    query = emergency_contacts.insert().values(**values)
    contact_id = await database.execute(query)
    
    # Fetch the created contact
    created_contact = await database.fetch_one(
        emergency_contacts.select().where(emergency_contacts.c.id == contact_id)
    )
    
    return EmergencyContact(
        id=created_contact['id'],
        first_name=created_contact['first_name'],
        last_name=created_contact['last_name'],
        phone_number=created_contact['phone_number'],
        relationship=created_contact['relationship'],
        notes=created_contact['notes'],
        created_by_user_id=uuid_to_string(created_contact['created_by_user_id']),
        created_at=created_contact['created_at'].isoformat()
    )

@router.put("/{contact_id}", response_model=EmergencyContact)
async def update_emergency_contact(
    contact_id: int, 
    contact: EmergencyContactCreate, 
    current_user = Depends(get_current_user)
):
    """
    Update an existing emergency contact.
    """
    # Check if contact exists and belongs to user's family
    existing_contact = await database.fetch_one(
        emergency_contacts.select().where(
            (emergency_contacts.c.id == contact_id) & 
            (emergency_contacts.c.family_id == current_user['family_id'])
        )
    )
    
    if not existing_contact:
        raise HTTPException(status_code=404, detail="Emergency contact not found")
    
    values = {
        "first_name": contact.first_name,
        "last_name": contact.last_name,
        "phone_number": contact.phone_number,
        "relationship": contact.relationship,
        "notes": contact.notes
    }
    
    query = emergency_contacts.update().where(
        emergency_contacts.c.id == contact_id
    ).values(**values)
    
    await database.execute(query)
    
    # Fetch the updated contact
    updated_contact = await database.fetch_one(
        emergency_contacts.select().where(emergency_contacts.c.id == contact_id)
    )
    
    return EmergencyContact(
        id=updated_contact['id'],
        first_name=updated_contact['first_name'],
        last_name=updated_contact['last_name'],
        phone_number=updated_contact['phone_number'],
        relationship=updated_contact['relationship'],
        notes=updated_contact['notes'],
        created_by_user_id=uuid_to_string(updated_contact['created_by_user_id']),
        created_at=updated_contact['created_at'].isoformat()
    )

@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_emergency_contact(contact_id: int, current_user = Depends(get_current_user)):
    """
    Delete an emergency contact.
    """
    # Check if contact exists and belongs to user's family
    existing_contact = await database.fetch_one(
        emergency_contacts.select().where(
            (emergency_contacts.c.id == contact_id) & 
            (emergency_contacts.c.family_id == current_user['family_id'])
        )
    )
    
    if not existing_contact:
        raise HTTPException(status_code=404, detail="Emergency contact not found")
    
    query = emergency_contacts.delete().where(emergency_contacts.c.id == contact_id)
    await database.execute(query)
    
    return None
