from fastapi import APIRouter
from api.v1.endpoints import (
    auth, users, events, custody, notifications, weather, profile, 
    babysitters, emergency_contacts, daycare_providers, family, 
    children, reminders, group_chat, school_events
)

api_router = APIRouter()

# Authentication
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])

# Users
api_router.include_router(users.router, prefix="/users", tags=["users"])

# Family
api_router.include_router(family.router, prefix="/family", tags=["family"])

# Events
api_router.include_router(events.router, prefix="/events", tags=["events"])

# Custody
api_router.include_router(custody.router, prefix="/custody", tags=["custody"])

# Notifications
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])

# Weather
api_router.include_router(weather.router, prefix="/weather", tags=["weather"])

# Profile
api_router.include_router(profile.router, prefix="/profile", tags=["profile"])

# Babysitters
api_router.include_router(babysitters.router, prefix="/babysitters", tags=["babysitters"])

# Emergency Contacts
api_router.include_router(emergency_contacts.router, prefix="/emergency-contacts", tags=["emergency_contacts"])

# Daycare Providers
api_router.include_router(daycare_providers.router, prefix="/daycare-providers", tags=["daycare_providers"])

# Children
api_router.include_router(children.router, prefix="/children", tags=["children"])

# Reminders
api_router.include_router(reminders.router, prefix="/reminders", tags=["reminders"])

# Group Chat
api_router.include_router(group_chat.router, prefix="/group-chat", tags=["group_chat"])

# School Events
api_router.include_router(school_events.router, prefix="/school-events", tags=["school_events"])
