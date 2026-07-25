#!/usr/bin/env python3
"""
Minimal Flask backend that connects to PostgreSQL.
Used for Chaos Engineering demo — shows real DB dependency impact.
"""

import os
import time
import json
import socket
import psycopg2
from http.server import BaseHTTPRequestHandler, HTTPServer

DB_HOST = os.environ.get("DB_HOST", "db")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "demo")
DB_USER = os.environ.get("DB_USER", "demo")
DB_PASS = os.environ.get("DB_PASS", "demo123")

def get_db_conn():
    """Get a PostgreSQL connection with timeout."""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
        connect_timeout=5,
        options="-c statement_timeout=5000"
    )

def init_db():
    """Create a simple table if not exists."""
    try:
        conn = get_db_conn()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS counter (
                id SERIAL PRIMARY KEY,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        conn.commit()
        cur.close()
        conn.close()
        return True
    except Exception as e:
        print(f"DB init error: {e}")
        return False

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._respond(200, {"status": "ok"})
        elif self.path == "/api/status":
            self._handle_status()
        elif self.path == "/api/db-check":
            self._handle_db_check()
        else:
            self._respond(200, {"service": "backend", "version": "1.0"})

    def _handle_status(self):
        """Check DB connectivity and return status."""
        start = time.time()
        try:
            conn = get_db_conn()
            cur = conn.cursor()
            cur.execute("INSERT INTO counter (created_at) VALUES (NOW()) RETURNING id")
            row = cur.fetchone()
            conn.commit()
            cur.close()
            conn.close()
            elapsed = round((time.time() - start) * 1000)
            self._respond(200, {
                "db": "connected",
                "db_response_ms": elapsed,
                "last_insert_id": row[0] if row else None
            })
        except Exception as e:
            elapsed = round((time.time() - start) * 1000)
            self._respond(503, {
                "db": "error",
                "error": str(e),
                "db_response_ms": elapsed
            })

    def _handle_db_check(self):
        """Simple TCP + DB connection check."""
        # TCP check
        tcp_start = time.time()
        try:
            s = socket.create_connection((DB_HOST, int(DB_PORT)), timeout=5)
            s.close()
            tcp_ms = round((time.time() - tcp_start) * 1000)
        except Exception as e:
            self._respond(503, {"tcp": "failed", "error": str(e)})
            return

        # SQL check
        sql_start = time.time()
        try:
            conn = get_db_conn()
            cur = conn.cursor()
            cur.execute("SELECT count(*) FROM counter")
            count = cur.fetchone()[0]
            cur.close()
            conn.close()
            sql_ms = round((time.time() - sql_start) * 1000)
            self._respond(200, {
                "tcp_ms": tcp_ms,
                "sql_ms": sql_ms,
                "total_rows": count
            })
        except Exception as e:
            sql_ms = round((time.time() - sql_start) * 1000)
            self._respond(503, {
                "tcp_ms": tcp_ms,
                "sql": "failed",
                "error": str(e),
                "sql_ms": sql_ms
            })

    def _respond(self, code, data):
        body = json.dumps(data, indent=2).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}")

if __name__ == "__main__":
    print(f"Starting backend on :5000")
    print(f"DB: {DB_HOST}:{DB_PORT}/{DB_NAME} (user={DB_USER})")
    
    # Wait for DB to be ready
    for i in range(30):
        if init_db():
            print("DB initialized successfully")
            break
        print(f"Waiting for DB... ({i+1}/30)")
        time.sleep(2)
    
    server = HTTPServer(("0.0.0.0", 5000), Handler)
    server.serve_forever()
