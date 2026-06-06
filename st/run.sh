#!/usr/bin/env bash
set -e

mkdir -p /data/st

export ST_DATA_DIR=/data/st
export PYTHONPATH=/app/backend

cd /app/backend
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
