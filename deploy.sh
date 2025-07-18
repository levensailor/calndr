#!/bin/bash
set -e

# --- Configuration ---
EC2_HOST="54.80.82.14"
EC2_USER="ec2-user"
# --- IMPORTANT: Update this if your key is in a different location ---
KEY_PAIR_FILE="~/.ssh/aws-2024.pem"

# --- Check for key file ---
KEY_PAIR_PATH=$(eval echo "$KEY_PAIR_FILE")
if [ ! -f "$KEY_PAIR_PATH" ]; then
    echo "ERROR: Key pair file not found at $KEY_PAIR_PATH"
    echo "Please update the KEY_PAIR_FILE variable in this script."
    exit 1
fi

# --- Check for .env file ---
if [ ! -f ".env" ]; then
    echo "WARNING: .env file not found in current directory"
    echo "The application will not work properly without environment variables"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "--- Starting deployment of refactored backend to EC2 instance $EC2_HOST ---"

# 1. Clean up remote directories before copying
echo "--- Cleaning up remote directories ---"
ssh -i "$KEY_PAIR_PATH" "$EC2_USER@$EC2_HOST" "rm -rf ~/backend"

# 2. Create logs directory in backend if it doesn't exist
echo "--- Preparing backend directory structure ---"
mkdir -p backend/logs

# 3. Copy backend directory to EC2 instance using rsync
echo "--- Copying backend files to server ---"
rsync -avz \
    --exclude '__pycache__' \
    --exclude '*.pyc' \
    --exclude 'venv' \
    --exclude '.git' \
    --exclude '.pytest_cache' \
    --exclude '*.log' \
    -e "ssh -i $KEY_PAIR_PATH" \
    backend/ "${EC2_USER}@${EC2_HOST}:~/backend/"

# 4. Copy setup script separately to ensure proper permissions
echo "--- Copying setup script ---"
rsync -avz -e "ssh -i $KEY_PAIR_PATH" backend/setup-backend.sh "${EC2_USER}@${EC2_HOST}:~/backend/"

# 5. Copy .env if it exists
if [ -f ".env" ]; then
    echo "--- Copying environment variables ---"
    rsync -avz -e "ssh -i $KEY_PAIR_PATH" .env "${EC2_USER}@${EC2_HOST}:~/"
fi

# 6. Copy AuthKey if it exists (for APNs notifications)
if [ -f "AuthKey_RZ6KL226Z5.p8" ]; then
    echo "--- Copying APNs authentication key ---"
    rsync -avz -e "ssh -i $KEY_PAIR_PATH" AuthKey_RZ6KL226Z5.p8 "${EC2_USER}@${EC2_HOST}:~/"
fi

# 7. Execute setup script on EC2 instance
echo "--- Running setup script on server ---"
ssh -i "$KEY_PAIR_PATH" "$EC2_USER@$EC2_HOST" "chmod +x ~/backend/setup-backend.sh && ~/backend/setup-backend.sh"

# 8. Check if the service is running
echo "--- Checking service status ---"
ssh -i "$KEY_PAIR_PATH" "$EC2_USER@$EC2_HOST" "sudo systemctl status cal-app --no-pager" || true

echo "--- Deployment finished ---"
echo "Check the output from the server above to ensure there were no errors."
echo "If successful, your application should be available at https://calndr.club"

# 9. Test the deployment
echo ""
echo "--- Testing deployment ---"
echo "Checking API health endpoint..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://calndr.club/health || echo "API might not be ready yet" 