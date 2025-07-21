#!/bin/bash

"""
Setup Daycare Calendar Sync Cron Job

This script sets up a weekly cron job to automatically sync daycare calendar events.
The job runs every Sunday at 3:00 AM to sync all configured daycare calendars.

Usage:
    bash setup_daycare_sync_cron.sh [--remove]

Arguments:
    --remove: Remove the cron job instead of adding it
"""

# Get the absolute path to the project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$PROJECT_DIR/sync_daycare_calendars.py"
PYTHON_PATH="$PROJECT_DIR/venv/bin/python"

# Cron job specification (every Sunday at 3:00 AM)
CRON_SCHEDULE="0 3 * * 0"
CRON_JOB="$CRON_SCHEDULE cd $PROJECT_DIR && $PYTHON_PATH $SCRIPT_PATH >> $PROJECT_DIR/logs/daycare_sync.log 2>&1"
CRON_COMMENT="# Daycare Calendar Sync - Weekly sync of daycare calendar events"

function add_cron_job() {
    echo "🔧 Setting up weekly daycare calendar sync cron job..."
    
    # Check if the script exists
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "❌ Error: Sync script not found at $SCRIPT_PATH"
        exit 1
    fi
    
    # Check if Python virtual environment exists
    if [ ! -f "$PYTHON_PATH" ]; then
        echo "❌ Error: Python virtual environment not found at $PYTHON_PATH"
        echo "💡 Please run 'python -m venv venv' to create the virtual environment first"
        exit 1
    fi
    
    # Create logs directory if it doesn't exist
    mkdir -p "$PROJECT_DIR/logs"
    
    # Get current crontab
    current_crontab=$(crontab -l 2>/dev/null || echo "")
    
    # Check if the job already exists
    if echo "$current_crontab" | grep -F "$SCRIPT_PATH" > /dev/null; then
        echo "⚠️  Daycare sync cron job already exists. Removing old job first..."
        current_crontab=$(echo "$current_crontab" | grep -v "$SCRIPT_PATH")
    fi
    
    # Add the new cron job
    new_crontab="$current_crontab
$CRON_COMMENT
$CRON_JOB"
    
    # Install the new crontab
    echo "$new_crontab" | crontab -
    
    echo "✅ Successfully added daycare calendar sync cron job"
    echo "📅 Schedule: Every Sunday at 3:00 AM"
    echo "📁 Log file: $PROJECT_DIR/logs/daycare_sync.log"
    echo "🔍 To test the sync manually, run:"
    echo "   $PYTHON_PATH $SCRIPT_PATH --dry-run"
}

function remove_cron_job() {
    echo "🗑️  Removing daycare calendar sync cron job..."
    
    # Get current crontab
    current_crontab=$(crontab -l 2>/dev/null || echo "")
    
    # Check if the job exists
    if ! echo "$current_crontab" | grep -F "$SCRIPT_PATH" > /dev/null; then
        echo "⚠️  Daycare sync cron job not found"
        return
    fi
    
    # Remove the job and its comment
    new_crontab=$(echo "$current_crontab" | grep -v "$SCRIPT_PATH" | grep -v "Daycare Calendar Sync")
    
    # Install the new crontab
    echo "$new_crontab" | crontab -
    
    echo "✅ Successfully removed daycare calendar sync cron job"
}

function show_usage() {
    echo "Usage: $0 [--remove]"
    echo ""
    echo "Options:"
    echo "  --remove    Remove the cron job instead of adding it"
    echo "  --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Add the weekly sync cron job"
    echo "  $0 --remove       # Remove the cron job"
}

# Parse command line arguments
case "${1:-}" in
    --remove)
        remove_cron_job
        ;;
    --help)
        show_usage
        ;;
    "")
        add_cron_job
        ;;
    *)
        echo "❌ Unknown option: $1"
        show_usage
        exit 1
        ;;
esac

echo ""
echo "📋 Current cron jobs:"
crontab -l 2>/dev/null || echo "No cron jobs found" 