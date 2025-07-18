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

@router.post("/request-location/{target_user_id}")
async def request_location(target_user_id: str, current_user = Depends(get_current_user)):
    """
    Send a silent push notification to request a user's location.
    """
    import json
    import uuid as uuid_module
    import boto3
    from core.config import settings
    
    if not settings.SNS_PLATFORM_APPLICATION_ARN:
        logger.warning("SNS client not configured. Cannot send location request.")
        raise HTTPException(status_code=500, detail="Notification service is not configured.")

    try:
        target_user_uuid = uuid_module.UUID(target_user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid target user ID format.")

    # Fetch the target user's SNS endpoint ARN
    user_query = users.select().where(users.c.id == target_user_uuid)
    target_user = await database.fetch_one(user_query)

    if not target_user or not target_user['sns_endpoint_arn']:
        logger.warning(f"Target user {target_user_id} not found or has no SNS endpoint.")
        raise HTTPException(status_code=404, detail="Target user not found or not registered for notifications.")

    # Construct the special APNS payload for a silent location request
    aps_payload = {
        "aps": {
            "content-available": 1
        },
        "type": "location_request",
        "requester_name": current_user['first_name']
    }

    platform_key = "APNS_SANDBOX" if "APNS_SANDBOX" in settings.SNS_PLATFORM_APPLICATION_ARN else "APNS"
    message = {
        platform_key: json.dumps(aps_payload)
    }

    try:
        sns_client = boto3.client('sns', region_name='us-east-1')
        logger.info(f"Sending location request to user {target_user_id} from user {current_user['id']}")
        sns_client.publish(
            TargetArn=target_user['sns_endpoint_arn'],
            Message=json.dumps(message),
            MessageStructure='json'
        )
        return {"status": "success", "message": "Location request sent."}
    except Exception as e:
        logger.error(f"Failed to send location request via SNS: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to send location request.")
