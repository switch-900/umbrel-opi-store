#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
until PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c '\q'; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

echo "PostgreSQL is up - executing initialization"

# Initialize databases using reset_init.py scripts
cd /app/modules/main_index && python3 reset_init.py
cd /app/modules/brc20_index && python3 reset_init.py
cd /app/modules/bitmap_index && python3 reset_init.py
cd /app/modules/sns_index && python3 reset_init.py
cd /app/modules/pow20_index && python3 reset_init.py
cd /app/modules/runes_index && python3 reset_init.py

# Start all services in the background
cd /app/modules/main_index && node index.js &
cd /app/modules/brc20_api && node api.js &
cd /app/modules/bitmap_api && node api.js &
cd /app/modules/sns_api && node api.js &
cd /app/modules/pow20_api && node api.js &
cd /app/modules/runes_api && node api.js &

# Keep container running
tail -f /dev/null
