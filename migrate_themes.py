import sqlite3
import os

def migrate_themes(db_path):
    print("Connecting to database...")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    print("Connection successful.")

    try:
        print("Creating themes table...")
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS themes (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            mainBackgroundColor TEXT NOT NULL,
            secondaryBackgroundColor TEXT NOT NULL,
            textColor TEXT NOT NULL,
            headerTextColor TEXT NOT NULL,
            iconColor TEXT NOT NULL,
            iconActiveColor TEXT NOT NULL,
            accentColor TEXT NOT NULL,
            parentOneColor TEXT NOT NULL,
            parentTwoColor TEXT NOT NULL,
            is_public BOOLEAN NOT NULL DEFAULT 0,
            created_by_user_id INTEGER,
            FOREIGN KEY (created_by_user_id) REFERENCES users(id)
        );
        """)
        print("Themes table created or already exists.")

        print("Creating user_preferences table...")
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_preferences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            selected_theme_id TEXT,
            FOREIGN KEY (user_id) REFERENCES users(id),
            FOREIGN KEY (selected_theme_id) REFERENCES themes(id)
        );
        """)
        print("User preferences table created or already exists.")

        print("Adding 'selected_theme_id' to user_preferences table...")
        cursor.execute("""
        ALTER TABLE user_preferences ADD COLUMN selected_theme_id TEXT;
        """)
        print("Column 'selected_theme_id' added to user_preferences table.")

    except sqlite3.OperationalError as e:
        if "duplicate column name" in str(e):
            print("Column 'selected_theme_id' already exists in 'user_preferences'.")
        else:
            print(f"An error occurred: {e}")
            raise

    conn.commit()
    print("Changes committed.")
    conn.close()
    print("Connection closed.")

if __name__ == "__main__":
    db_path = os.getenv("DB_PATH", "calndr.db")
    migrate_themes(db_path) 