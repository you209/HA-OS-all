#!/usr/bin/env bash
set -e

mkdir -p /data/find-my-local-pollie

export NODE_ENV=production
export PORT=3000

cd /app
exec npm start
