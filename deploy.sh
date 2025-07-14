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

echo "--- Starting deployment of refactored backend to EC2 instance $EC2_HOST ---"

# 1. Clean up remote directory before copying
echo "--- Cleaning up remote directory ---"
ssh -i "$KEY_PAIR_PATH" "$EC2_USER@$EC2_HOST" "rm -rf ~/backend"

# 2. Copy backend directory and other necessary files to EC2 instance using rsync
echo "--- Copying application files to server ---"
rsync -avz --exclude 'setup-backend.sh' -e "ssh -i $KEY_PAIR_PATH" backend/ "${EC2_USER}@${EC2_HOST}:~/backend/"
rsync -avz -e "ssh -i $KEY_PAIR_PATH" backend/setup-backend.sh "${EC2_USER}@${EC2_HOST}:~/backend/"


# Copy .env if it exists
if [ -f ".env" ]; then
    rsync -avz -e "ssh -i $KEY_PAIR_PATH" .env "${EC2_USER}@${EC2_HOST}:~/"
fi

# Copy AuthKey if it exists
if [ -f "AuthKey_RZ6KL226Z5.p8" ]; then
    rsync -avz -e "ssh -i $KEY_PAIR_PATH" AuthKey_RZ6KL226Z5.p8 "${EC2_USER}@${EC2_HOST}:~/"
fi


# 3. Execute setup script on EC2 instance
echo "--- Running setup script on server ---"
ssh -i "$KEY_PAIR_PATH" "$EC2_USER@$EC2_HOST" "chmod +x ~/backend/setup-backend.sh && ~/backend/setup-backend.sh"

echo "--- Deployment finished ---"
echo "Check the output from the server above to ensure there were no errors."
echo "If successful, your application should be available at https://calndr.club" 