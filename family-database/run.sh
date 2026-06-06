#!/usr/bin/env bash
set -e

mkdir -p /data/family-database/data
mkdir -p /data/family-database/media

rm -rf /app/data
ln -s /data/family-database/data /app/data

rm -rf /app/media
ln -s /data/family-database/media /app/media

cd /app/backend
exec python app.py
