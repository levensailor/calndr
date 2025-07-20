import httpx, time, json
from jose import jwk, jwt
from jose.utils import base64url_decode
from core.logging import logger
from typing import Optional

APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"

class AppleNotificationService:
    def __init__(self):
        self.cached_keys = None
        self.cached_at = 0
        self.cache_ttl = 60 * 60  # 1 hour

    async def _get_apple_keys(self):
        if self.cached_keys and time.time() - self.cached_at < self.cache_ttl:
            return self.cached_keys
        async with httpx.AsyncClient() as client:
            r = await client.get(APPLE_KEYS_URL)
            r.raise_for_status()
            self.cached_keys = r.json()["keys"]
            self.cached_at = time.time()
            return self.cached_keys

    async def verify_jws(self, jws_token: str) -> Optional[dict]:
        try:
            headers = jwt.get_unverified_header(jws_token)
            kid = headers["kid"]
            alg = headers["alg"]
            keys = await self._get_apple_keys()
            key_dict = next((k for k in keys if k["kid"] == kid and k["alg"] == alg), None)
            if not key_dict:
                logger.error("Apple key not found for kid %s", kid)
                return None
            public_key = jwk.construct(key_dict)
            message, encoded_sig = jws_token.rsplit('.', 1)
            decoded_sig = base64url_decode(encoded_sig.encode())
            if not public_key.verify(message.encode(), decoded_sig):
                logger.error("Signature verification failed for Apple notification")
                return None
            payload = jwt.get_unverified_claims(jws_token)
            return payload
        except Exception as e:
            logger.error(f"Failed to verify Apple notification JWS: {e}")
            return None

apple_notification_service = AppleNotificationService() 