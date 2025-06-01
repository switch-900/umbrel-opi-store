#!/bin/bash

echo "=== Checking Umbrel Environment ==="

# Check disk space
echo -e "\n>>> Checking disk space:"
df -h /home/umbrel

# Check RAM
echo -e "\n>>> Checking available memory:"
free -h

# Check if Bitcoin is running and synced
echo -e "\n>>> Checking Bitcoin status:"
bitcoin-cli getblockchaininfo 2>/dev/null || echo "Bitcoin not accessible"

# Check Docker status
echo -e "\n>>> Checking Docker status:"
docker ps
docker system df

# Check logs for OPI containers
echo -e "\n>>> Checking OPI container logs:"
docker logs opi_web_1 2>&1 | tail -n 50

# Check PostgreSQL logs
echo -e "\n>>> Checking PostgreSQL logs:"
docker logs opi_db_1 2>&1 | tail -n 50
