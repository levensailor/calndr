# Calndr Backend API

Family Calendar Management API built with FastAPI.

## Project Structure

```
backend/
├── api/
│   └── v1/
│       ├── api.py              # Main API router
│       └── endpoints/          # API endpoint modules
│           ├── auth.py         # Authentication endpoints
│           ├── users.py        # User management
│           ├── events.py       # Calendar events
│           ├── custody.py      # Custody management
│           ├── family.py       # Family management
│           ├── children.py     # Children management
│           ├── babysitters.py  # Babysitter management
│           ├── emergency_contacts.py
│           ├── daycare_providers.py
│           ├── notifications.py
│           ├── weather.py      # Weather integration
│           ├── reminders.py    # Reminders and notifications
│           ├── group_chat.py   # Group chat functionality
│           └── school_events.py # School events scraping
├── core/
│   ├── config.py              # Application configuration
│   ├── database.py            # Database connection
│   ├── logging.py             # Logging configuration
│   ├── middleware.py          # Custom middleware
│   └── security.py            # Authentication and security
├── db/
│   └── models.py              # SQLAlchemy table definitions
├── schemas/
│   ├── auth.py                # Authentication schemas
│   ├── user.py                # User-related schemas
│   ├── event.py               # Event schemas
│   ├── custody.py             # Custody schemas
│   ├── babysitter.py          # Babysitter schemas
│   ├── emergency_contact.py   # Emergency contact schemas
│   ├── daycare.py             # Daycare provider schemas
│   ├── reminder.py            # Reminder schemas
│   ├── notification.py        # Notification schemas
│   ├── weather.py             # Weather schemas
│   ├── child.py               # Children schemas
│   └── group_chat.py          # Group chat schemas
├── services/
│   ├── notification_service.py # Push notification logic
│   ├── weather_service.py     # Weather caching
│   └── school_events_service.py # School events scraping
├── utils/                     # Utility functions
├── main.py                    # FastAPI application factory
├── run.py                     # Development server startup
├── requirements.txt           # Python dependencies
└── README.md                  # This file
```

## Features

- **Authentication**: JWT-based user authentication
- **Family Management**: Multi-user family calendar system
- **Custody Management**: Child custody scheduling with handoff tracking
- **Events**: Calendar events with position-based organization
- **Weather Integration**: Cached weather data from Open-Meteo API
- **Push Notifications**: AWS SNS integration for mobile notifications
- **Babysitter Management**: Track babysitter contacts and rates
- **Emergency Contacts**: Family emergency contact management
- **Daycare Providers**: Daycare provider directory with Google Places integration
- **School Events**: Automated scraping of school closure events
- **Reminders**: Custom reminders with notification scheduling
- **User Preferences**: Theme and preference management
- **Location Tracking**: Last known location for family members

## Setup

### Prerequisites

- Python 3.11+
- PostgreSQL database
- AWS account (for SNS notifications and S3 storage)
- Google Places API key (for daycare search)

### Installation

1. **Create virtual environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Environment Configuration**:
   Create a `.env` file in the backend directory:
   ```env
   # Database
   DB_USER=your_db_user
   DB_PASSWORD=your_db_password
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=calndr
   
   # Security
   SECRET_KEY=your_secret_key_here
   
   # AWS
   AWS_ACCESS_KEY_ID=your_aws_access_key
   AWS_SECRET_ACCESS_KEY=your_aws_secret_key
   AWS_REGION=us-east-1
   AWS_S3_BUCKET_NAME=your_s3_bucket
   SNS_PLATFORM_APPLICATION_ARN=your_sns_platform_arn
   
   # External APIs
   GOOGLE_PLACES_API_KEY=your_google_places_api_key
   ```

4. **Database Setup**:
   - Create PostgreSQL database
   - Run database migrations (if available)

## Running the Application

### Development Server

```bash
# Using the run script
python run.py

# Or directly with uvicorn
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Production

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

## API Documentation

Once the server is running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## API Versioning

The API is versioned with `/api/v1` as the base path. This follows the rule for versioned APIs that can easily redirect to `/api/v2` for red/blue testing.

## Logging

The application uses structured logging with:
- Console output for development
- Rotating file logs (1MB max, 3 backups) in `logs/` directory
- EST timezone formatting
- Line numbers and function names for debugging

## Testing

```bash
# Install test dependencies
pip install pytest pytest-asyncio httpx

# Run tests
pytest
```

## Deployment

The application is designed to be deployed using:
- Docker containers
- AWS ECS/Fargate
- Traditional VPS with supervisor/systemd

### Environment Variables for Production

Ensure all environment variables are properly set in production, particularly:
- Database connection details
- AWS credentials and ARNs
- Secret keys for JWT signing
- External API keys

## Security Features

- **Password Hashing**: bcrypt for secure password storage
- **JWT Tokens**: Secure token-based authentication
- **CORS**: Configurable CORS policies
- **Input Validation**: Pydantic schemas for request validation
- **SQL Injection Protection**: SQLAlchemy ORM prevents SQL injection

## Contributing

When adding new features:
1. Create new endpoint modules in `api/v1/endpoints/`
2. Add corresponding schemas in `schemas/`
3. Update the main API router in `api/v1/api.py`
4. Add any business logic to `services/`
5. Update this README with new features

## Architecture Decisions

- **FastAPI**: Modern async Python framework with automatic OpenAPI docs
- **SQLAlchemy Core**: For database operations (not ORM for performance)
- **Pydantic**: For data validation and serialization
- **JWT**: Stateless authentication for scalability
- **Async/Await**: Full async support for database and HTTP operations
- **Service Layer**: Business logic separated from API endpoints
