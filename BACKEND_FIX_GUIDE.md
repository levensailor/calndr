# Backend Refactoring Fix Guide

The app was partially refactored from a monolithic `app.py` to a modular backend structure, but the refactoring was incomplete. Here's how to run the app:

## Option 1: Run the Original App (Recommended for now)

The original `app.py` is still functional. To run it:

```bash
# From the root directory
./run.sh
```

This will:
- Create a virtual environment (if needed)
- Install dependencies
- Run the original app.py on port 3000

## Option 2: Run the Refactored Backend

The backend has been partially refactored but needs the correct Python path to work:

```bash
# From the root directory
./run.sh backend
```

This will:
- Navigate to the backend directory
- Set up the correct PYTHONPATH
- Run the refactored backend on port 3000

## What Was Fixed

1. **Updated run.sh**: The script now supports both versions - original and refactored
2. **Python Path**: Added `export PYTHONPATH` to ensure imports work correctly
3. **Import Structure**: The backend uses absolute imports that require the correct Python path

## Deployment

The deployment script (`deploy.sh`) currently deploys the refactored backend. The server setup script (`backend/setup-backend.sh`) handles the Python path correctly on the server.

## Next Steps

To complete the refactoring:
1. Finish implementing all endpoint modules in `backend/api/v1/endpoints/`
2. Move all business logic from `app.py` to appropriate modules
3. Add comprehensive tests
4. Update documentation

For now, it's recommended to use the original `app.py` until the refactoring is complete.