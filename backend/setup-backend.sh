#!/bin/bash
# Script to set up the refactored application on the EC2 instance.
# This script is intended to be run on the server.
set -e

APP_DIR="/var/www/cal-app"
APP_USER="ec2-user"
SOURCE_DIR="/home/$APP_USER/backend"
LOG_DIR="$APP_DIR/logs"

echo "--- Starting setup for refactored backend on the server ---"

# 1. Install dependencies
echo "--- Installing system packages ---"
sudo yum update -y
sudo yum install -y python3-pip python3-devel nginx certbot python3-certbot-nginx cronie

# 2. Create app directory and set permissions
echo "--- Creating application directory and setting permissions ---"
sudo mkdir -p $APP_DIR
sudo rm -rf $APP_DIR/* # Clean out the directory before copying new files

# 3. Copy application files
echo "--- Copying application files to $APP_DIR ---"
# Copy the entire backend directory content
if [ -d "$SOURCE_DIR" ]; then
    sudo cp -r $SOURCE_DIR/* $APP_DIR/
fi
# Copy other files that were rsynced to home
[ -f /home/$APP_USER/.env ] && sudo cp /home/$APP_USER/.env $APP_DIR/
[ -f /home/$APP_USER/AuthKey_RZ6KL226Z5.p8 ] && sudo cp /home/$APP_USER/AuthKey_RZ6KL226Z5.p8 $APP_DIR/

# 4. Create logs directory
sudo mkdir -p $LOG_DIR

# 5. Set ownership and permissions
sudo chown -R $APP_USER:$APP_USER $APP_DIR
sudo chmod -R 755 $APP_DIR
sudo chmod 775 $LOG_DIR

cd $APP_DIR

# 6. Create python virtual environment and install packages
echo "--- Creating Python virtual environment and installing dependencies ---"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "ERROR: requirements.txt not found!"
    exit 1
fi
deactivate

# 7. Create a simple health check endpoint if it doesn't exist
echo "--- Ensuring health check endpoint exists ---"
if ! grep -q "health" main.py; then
    echo "Adding health endpoint to main.py..."
    sudo bash -c "cat >> main.py" << 'HEALTH_EOF'

@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring."""
    return {"status": "healthy", "service": "calndr-backend"}
HEALTH_EOF
fi

# 8. Set up systemd service to run gunicorn with PYTHONPATH
echo "--- Creating systemd service file for refactored app ---"
sudo bash -c "cat > /etc/systemd/system/cal-app.service" << EOL
[Unit]
Description=Gunicorn instance to serve the calendar app
After=network.target

[Service]
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
Environment="PYTHONPATH=$APP_DIR"
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000 --timeout 120 --access-logfile $LOG_DIR/access.log --error-logfile $LOG_DIR/error.log main:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# 9. Set up nginx as a reverse proxy
echo "--- Configuring nginx ---"
sudo bash -c "cat > /etc/nginx/conf.d/cal-app.conf" << EOL
server {
    listen 80;
    server_name calndr.club www.calndr.club;

    # Increase timeouts for large requests
    proxy_connect_timeout 120s;
    proxy_send_timeout 120s;
    proxy_read_timeout 120s;
    send_timeout 120s;

    # Increase buffer sizes
    client_max_body_size 10M;
    client_body_buffer_size 128k;
    proxy_buffer_size 4k;
    proxy_buffers 8 16k;
    proxy_busy_buffers_size 32k;

    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /health {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /docs {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /redoc {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /openapi.json {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Remove default nginx config if it exists
sudo rm -f /etc/nginx/conf.d/default.conf
sudo nginx -t

# 10. Start and enable services
echo "--- Starting and enabling services ---"
sudo systemctl daemon-reload
sudo systemctl restart cal-app
sudo systemctl enable cal-app
sudo systemctl restart nginx
sudo systemctl enable nginx

# 11. Obtain SSL certificate with Certbot if not already obtained
if ! sudo certbot certificates | grep -q "calndr.club"; then
    echo "--- Obtaining SSL certificate with Certbot ---"
    sudo certbot --nginx -d calndr.club -d www.calndr.club --non-interactive --agree-tos --email jeff@levensailor.com --redirect
else
    echo "--- SSL certificate already exists, skipping creation ---"
fi

# 12. Enable automatic certificate renewal
echo "--- Enabling automatic certificate renewal ---"
sudo systemctl start certbot-renew.timer
sudo systemctl enable certbot-renew.timer

# 13. Check service status
echo "--- Checking service status ---"
sudo systemctl status cal-app --no-pager || true

# 14. Show logs location
echo ""
echo "--- Deployment to EC2 finished successfully! ---"
echo "Your app should be available at https://calndr.club"
echo ""
echo "Log files location:"
echo "  - Application logs: $LOG_DIR/backend.log"
echo "  - Access logs: $LOG_DIR/access.log"
echo "  - Error logs: $LOG_DIR/error.log"
echo ""
echo "To view logs:"
echo "  sudo tail -f $LOG_DIR/backend.log"
echo "  sudo journalctl -u cal-app -f" 