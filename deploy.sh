#!/bin/bash
set -e

# --- Configuration ---
EC2_HOST="54.80.82.14"
EC2_USER="ec2-user"
# --- IMPORTANT: Update this if your key is in a different location ---
KEY_PAIR_FILE="~/.ssh/aws-2024.pem"

# --- Check for key file ---
if [ ! -f "$(eval echo $KEY_PAIR_FILE)" ]; then
    echo "ERROR: Key pair file not found at $KEY_PAIR_FILE"
    echo "Please update the KEY_PAIR_FILE variable in this script."
    exit 1
fi

# --- Files and directories to deploy ---
# This list contains all the project components that will be copied to the server.
FILES_TO_DEPLOY=(
    "app.py"
    "requirements.txt"
    "AuthKey_4LZC88RV85.p8"
    "setup.sh"
    ".env"
    "initial_setup.py"
    "send_weekly_email.py"
    "migrate_user_profile.py"
    "migrate_notification_emails.py"
    "migrate_custody_table.py"
    "migrate_events_table.py"
    "fix_events_date_column.py"
)

echo "--- Building frontend assets (SKIPPED) ---"
# (cd frontend && npm install && npm run build)
# echo "--- Frontend build complete ---"

echo "--- Starting deployment to EC2 instance $EC2_HOST ---"

# 1. Copy files to EC2 instance using rsync
echo "--- Copying application files to server ---"
rsync -avz -e "ssh -i $KEY_PAIR_FILE" "${FILES_TO_DEPLOY[@]}" "${EC2_USER}@${EC2_HOST}:~/"

# 2. Execute setup script on EC2 instance
echo "--- Running setup script on server ---"
ssh -i "$KEY_PAIR_FILE" "$EC2_USER@$EC2_HOST" 'bash ~/setup.sh'

echo "--- Deployment finished ---"
echo "Check the output from the server above to ensure there were no errors."
echo "If successful, your application should be available at https://calndr.club" 