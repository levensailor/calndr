from fastapi import APIRouter, Request, HTTPException, status
from services.apple_notification_service import apple_notification_service
from core.logging import logger

router = APIRouter()

@router.post("/server-notify", status_code=204)
async def apple_server_notification(request: Request):
    """Endpoint that Apple calls for server-to-server notifications (e.g., subscription events).
    Apple sends a JSON body or signed JWS depending on version 2.0. We support both.
    """
    body = await request.body()
    try:
        data = body.decode()
    except UnicodeDecodeError:
        data = str(body)

    # Version 2 notifications are JWS strings
    if data.startswith("eyJ0"):
        payload = await apple_notification_service.verify_jws(data)
        if payload is None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid JWS")
        logger.info(f"✅ Apple S2S notification verified: {payload}")
        # TODO: handle payload['notificationType'] (e.g., DID_RENEW, CANCEL, etc.)
        return
    # Legacy JSON version
    try:
        json_data = await request.json()
        logger.info(f"✅ Apple S2S legacy notification: {json_data}")
        # TODO: handle json_data['notification_type']
    except Exception as e:
        logger.error(f"Failed to parse Apple notification: {e}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid payload") 