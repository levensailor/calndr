import os
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import date, timedelta, datetime
import databases
import sqlalchemy
from dotenv import load_dotenv
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables from .env file
load_dotenv()

# --- Configuration ---
DATABASE_URL = "sqlite:///calendar.db"
SENDER_EMAIL = "jeff@levensailor.com"
GMAIL_APP_PASSWORD = os.getenv("GMAIL_APP_PASSWORD")

# --- Database Setup ---
database = databases.Database(DATABASE_URL)
metadata = sqlalchemy.MetaData()

events = sqlalchemy.Table(
    "events",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True),
    sqlalchemy.Column("event_date", sqlalchemy.String),
    sqlalchemy.Column("content", sqlalchemy.String),
    sqlalchemy.Column("position", sqlalchemy.Integer),
)

notification_emails = sqlalchemy.Table(
    "notification_emails",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True),
    sqlalchemy.Column("email", sqlalchemy.String, unique=True, nullable=False),
)

def get_custody_for_day(db_events, a_date):
    """
    Determines custody schedule for a given day. Checks for manual overrides first.
    """
    for event in db_events:
        if event['position'] == 4:
            return "Jeff" if event['content'] == 'jeff' else "Deanna"
    
    # Default: Jeff has Sat, Sun, Mon
    return "Jeff" if a_date.weekday() in [0, 5, 6] else "Deanna"

def create_html_content(schedule_data):
    """Creates the HTML content for the email."""
    
    # --- Inline CSS for Email Compatibility ---
    styles = {
        "body": "font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f4f4f4;",
        "container": "max-width: 600px; margin: auto; background: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1);",
        "header": "background-color: #4A90E2; color: white; padding: 20px; text-align: center;",
        "header_h1": "margin: 0; font-size: 24px;",
        "content": "padding: 20px;",
        "table": "width: 100%; border-collapse: collapse; margin-top: 20px;",
        "th_td": "padding: 12px; border-bottom: 1px solid #ddd; text-align: left;",
        "th": "background-color: #f8f8f8; font-weight: bold;",
        "custody_jeff": "background-color: #96CBFC; color: #000;",
        "custody_deanna": "background-color: #FFC2D9; color: #000;",
        "ul": "margin: 0; padding-left: 20px;",
        "footer": "text-align: center; padding: 15px; font-size: 12px; color: #888; background-color: #f8f8f8; border-top: 1px solid #ddd;"
    }

    # --- HTML Structure ---
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Weekly Schedule Summary</title>
    </head>
    <body style="{styles['body']}">
        <div style="{styles['container']}">
            <div style="{styles['header']}">
                <h1 style="{styles['header_h1']}">Your Weekly Schedule</h1>
            </div>
            <div style="{styles['content']}">
                <p>Here's a look at the schedule for the upcoming week:</p>
                <table style="{styles['table']}">
                    <thead>
                        <tr>
                            <th style="{styles['th_td']} {styles['th']}">Day</th>
                            <th style="{styles['th_td']} {styles['th']}">Date</th>
                            <th style="{styles['th_td']} {styles['th']}">Custody</th>
                            <th style="{styles['th_td']} {styles['th']}">Notes</th>
                        </tr>
                    </thead>
                    <tbody>
    """

    for day_data in schedule_data:
        custody_class = styles['custody_jeff'] if day_data['custody'] == 'Jeff' else styles['custody_deanna']
        notes_html = f"<ul style='{styles['ul']}'>"
        if day_data['notes']:
            for note in day_data['notes']:
                notes_html += f"<li>{note}</li>"
        else:
            notes_html += "<li>-</li>" # Placeholder if no notes
        notes_html += "</ul>"
        
        html += f"""
                        <tr>
                            <td style="{styles['th_td']}">{day_data['day_name']}</td>
                            <td style="{styles['th_td']}">{day_data['date_str']}</td>
                            <td style="{styles['th_td']} {custody_class}">{day_data['custody']}</td>
                            <td style="{styles['th_td']}">{notes_html}</td>
                        </tr>
        """

    html += """
                    </tbody>
                </table>
            </div>
            <div style="{styles['footer']}">
                <p>This is an automated reminder. Have a great week!</p>
            </div>
        </div>
    </body>
    </html>
    """
    return html

async def send_weekly_summary():
    """Fetches data and sends the weekly summary email."""
    if not GMAIL_APP_PASSWORD:
        logger.error("GMAIL_APP_PASSWORD environment variable not set. Cannot send email.")
        return

    await database.connect()
    
    # Fetch recipient emails from the database
    email_query = notification_emails.select()
    results = await database.fetch_all(email_query)
    receiver_emails = [row['email'] for row in results]

    if not receiver_emails:
        logger.warning("No recipient emails found in the database. Aborting email send.")
        await database.disconnect()
        return

    today = date.today()
    # The script runs on Sunday, so we get today + the next 6 days.
    start_of_week = today
    end_of_week = today + timedelta(days=6)
    
    logger.info(f"Generating weekly summary for {start_of_week} to {end_of_week}")
    
    schedule_data = []
    for i in range(7):
        current_date = start_of_week + timedelta(days=i)
        date_str_db = current_date.isoformat()
        
        query = events.select().where(events.c.event_date == date_str_db)
        all_day_events_from_db = await database.fetch_all(query)
        
        custody = get_custody_for_day(all_day_events_from_db, current_date)
        notes = [e['content'] for e in all_day_events_from_db if e['position'] != 4 and e['content'] and e['content'].strip()]
        
        schedule_data.append({
            "day_name": current_date.strftime("%A"),
            "date_str": current_date.strftime("%m/%d"),
            "custody": custody,
            "notes": notes
        })

    await database.disconnect()

    # --- Send Email ---
    subject = f"Weekly Calendar Summary: {start_of_week.strftime('%b %d')} - {end_of_week.strftime('%b %d')}"
    html_content = create_html_content(schedule_data)
    
    msg = MIMEMultipart()
    msg['From'] = SENDER_EMAIL
    msg['To'] = ", ".join(receiver_emails)
    msg['Subject'] = subject
    msg.attach(MIMEText(html_content, 'html'))

    try:
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL('smtp.gmail.com', 465, context=context) as server:
            server.login(SENDER_EMAIL, GMAIL_APP_PASSWORD)
            server.send_message(msg)
        logger.info(f"Weekly summary email sent successfully to {', '.join(receiver_emails)}.")
    except Exception as e:
        logger.error(f"Failed to send weekly email: {e}")

if __name__ == "__main__":
    import asyncio
    asyncio.run(send_weekly_summary()) 