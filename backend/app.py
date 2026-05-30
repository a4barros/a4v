import sqlite3
import os
from datetime import datetime
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_PATH = "/app/data/videos.db"

def get_db():
    """Get database connection"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Initialize database schema"""
    conn = get_db()
    cursor = conn.cursor()
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS videos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            video_name TEXT UNIQUE NOT NULL,
            views INTEGER DEFAULT 0,
            likes INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    conn.commit()
    conn.close()

init_db()

class VideoStats(BaseModel):
    video_name: str
    views: int
    likes: int

@app.get("/api/stats/{video_name}")
def get_stats(video_name: str):
    """Get views and likes for a video"""
    conn = get_db()
    cursor = conn.cursor()
    
    cursor.execute("SELECT * FROM videos WHERE video_name = ?", (video_name,))
    row = cursor.fetchone()
    conn.close()
    
    if not row:
        # Create entry if it doesn't exist
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute("INSERT INTO videos (video_name, views, likes) VALUES (?, 0, 0)", (video_name,))
        conn.commit()
        conn.close()
        return {"video_name": video_name, "views": 0, "likes": 0}
    
    return {
        "video_name": row["video_name"],
        "views": row["views"],
        "likes": row["likes"]
    }

@app.post("/api/stats/{video_name}/view")
def increment_view(video_name: str):
    """Increment view count for a video"""
    conn = get_db()
    cursor = conn.cursor()
    
    # Ensure video exists
    cursor.execute("SELECT id FROM videos WHERE video_name = ?", (video_name,))
    if not cursor.fetchone():
        cursor.execute("INSERT INTO videos (video_name, views, likes) VALUES (?, 1, 0)", (video_name,))
    else:
        cursor.execute("UPDATE videos SET views = views + 1 WHERE video_name = ?", (video_name,))
    
    conn.commit()
    
    # Get updated stats
    cursor.execute("SELECT views, likes FROM videos WHERE video_name = ?", (video_name,))
    row = cursor.fetchone()
    conn.close()
    
    return {
        "video_name": video_name,
        "views": row["views"],
        "likes": row["likes"]
    }

@app.post("/api/stats/{video_name}/like")
def increment_like(video_name: str):
    """Increment like count for a video"""
    conn = get_db()
    cursor = conn.cursor()
    
    # Ensure video exists
    cursor.execute("SELECT id FROM videos WHERE video_name = ?", (video_name,))
    if not cursor.fetchone():
        cursor.execute("INSERT INTO videos (video_name, views, likes) VALUES (?, 0, 1)", (video_name,))
    else:
        cursor.execute("UPDATE videos SET likes = likes + 1 WHERE video_name = ?", (video_name,))
    
    conn.commit()
    
    # Get updated stats
    cursor.execute("SELECT views, likes FROM videos WHERE video_name = ?", (video_name,))
    row = cursor.fetchone()
    conn.close()
    
    return {
        "video_name": video_name,
        "views": row["views"],
        "likes": row["likes"]
    }

@app.post("/api/stats/{video_name}/unlike")
def decrement_like(video_name: str):
    """Decrement like count for a video"""
    conn = get_db()
    cursor = conn.cursor()
    
    # Ensure video exists
    cursor.execute("SELECT id FROM videos WHERE video_name = ?", (video_name,))
    if not cursor.fetchone():
        cursor.execute("INSERT INTO videos (video_name, views, likes) VALUES (?, 0, 0)", (video_name,))
    else:
        cursor.execute("UPDATE videos SET likes = MAX(0, likes - 1) WHERE video_name = ?", (video_name,))
    
    conn.commit()
    
    # Get updated stats
    cursor.execute("SELECT views, likes FROM videos WHERE video_name = ?", (video_name,))
    row = cursor.fetchone()
    conn.close()
    
    return {
        "video_name": video_name,
        "views": row["views"],
        "likes": row["likes"]
    }

@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {"status": "ok"}
