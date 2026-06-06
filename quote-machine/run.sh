#!/usr/bin/env bash
set -e

mkdir -p /data/quote-machine

if [ ! -L /app/data ]; then
  rm -rf /app/data
  ln -s /data/quote-machine /app/data
fi

export NODE_ENV=production
export PORT=3000

cd /app
exec npm start
