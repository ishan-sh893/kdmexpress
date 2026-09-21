#!/bin/bash
# =======================================================
# Quick Update Script (Zero Data Loss - Only Updates App Code)
# =======================================================

set -e

cd /var/www/ktmexpress

echo "📥 Fetching latest code..."
git pull origin main

echo "🐳 Rebuilding frontend & backend containers..."
docker compose build --no-cache frontend backend
docker compose up -d --no-deps frontend backend

echo "✅ Update complete! Database and data untouched."
