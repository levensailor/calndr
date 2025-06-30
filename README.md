# Calendar App

## Quick Start

To run the application, make sure you have Python, pip, and Node.js with npm installed. Then, simply run the `run.sh` script:

```bash
./run.sh
```

The script will install all necessary dependencies, build the frontend, and start the server.

The application will be available at [http://localhost:3000](http://localhost:3000).

## Manual Setup

If you prefer to run the application manually, follow these steps:

### Backend

1.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
2.  Run the server:
    ```bash
    uvicorn app:app --reload --port 3000
    ```

### Frontend

1.  Navigate to the `frontend` directory:
    ```bash
    cd frontend
    ```
2.  Install dependencies:
    ```bash
    npm install
    ```
3.  Build for production:
    ```bash
    npm run build
    ```

The application will be available at [http://localhost:3000](http://localhost:3000). 



