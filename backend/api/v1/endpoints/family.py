from typing import List
from fastapi import APIRouter, Depends, HTTPException

from core.database import database
from core.security import get_current_user, uuid_to_string
from core.logging import logger
from db.models import users
from schemas.user import FamilyMember, FamilyMemberEmail

router = APIRouter()

@router.get("/custodians")
async def get_family_custodians(current_user = Depends(get_current_user)):
    """
    Returns the two primary custodians (parents) for the current user's family.
    """
    family_id = current_user['family_id']
    family_members = await database.fetch_all(users.select().where(users.c.family_id == family_id).order_by(users.c.created_at))
    
    if len(family_members) < 2:
        raise HTTPException(status_code=404, detail="Family must have at least two members to determine custodians")
        
    custodian_one = family_members[0]
    custodian_two = family_members[1]
    
    return {
        "custodian_one": {
            "id": uuid_to_string(custodian_one['id']),
            "first_name": custodian_one['first_name']
        },
        "custodian_two": {
            "id": uuid_to_string(custodian_two['id']),
            "first_name": custodian_two['first_name']
        }
    }

@router.get("/emails", response_model=List[FamilyMemberEmail])
async def get_family_member_emails(current_user = Depends(get_current_user)):
    """
    Returns the email addresses of all family members (parents) for automatic population in alerts.
    """
    query = users.select().where(users.c.family_id == current_user['family_id']).order_by(users.c.first_name)
    family_members = await database.fetch_all(query)
    
    return [
        FamilyMemberEmail(
            id=str(member['id']),
            first_name=member['first_name'],
            email=member['email']
        )
        for member in family_members
    ]

@router.get("/members", response_model=List[FamilyMember])
async def get_family_members(current_user = Depends(get_current_user)):
    """
    Returns all family members with their contact information including phone numbers.
    """
    family_id = current_user['family_id']
    query = users.select().where(users.c.family_id == family_id)
    family_members_records = await database.fetch_all(query)
    
    return [
        FamilyMember(
            id=str(member['id']),
            first_name=member['first_name'],
            last_name=member['last_name'],
            email=member['email'],
            phone_number=member['phone_number'],
            status=member['status'],
            last_signed_in=member['last_signed_in'].isoformat() if member['last_signed_in'] else None,
            last_known_location=member['last_known_location'],
            last_known_location_timestamp=member['last_known_location_timestamp'].isoformat() if member['last_known_location_timestamp'] else None
        ) for member in family_members_records
    ]
