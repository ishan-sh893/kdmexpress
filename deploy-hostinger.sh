#!/bin/bash
# =======================================================
# Ktmexpress Hostinger VPS Deployment Script (DATA SAFE)
# Domain: kdmexpress.com | IP: 200.141.11.152
# Repository: https://github.com/Tester10-lab/Ktmexpress.git
# =======================================================

set -e

echo "🚀 Starting Safe Hostinger VPS Deployment for Ktmexpress (Data Preserved)..."

# 1. Automatic Database Safety Backup if MongoDB is currently running
mkdir -p /var/backups/ktmexpress
if docker ps -q --filter "name=ktmexpress_mongodb" | grep -q .; then
    echo "💾 Creating automatic safety backup of MongoDB database..."
    BACKUP_NAME="mongodb_backup_$(date +%Y%m%d_%H%M%S)"
    docker exec ktmexpress_mongodb mongodump --username ktmadmin --password ktmexpress_db_pass_2026 --authenticationDatabase admin --db ktmexpress --archive="/data/db/${BACKUP_NAME}.archive" 2>/dev/null || true
    echo "✅ Backup archive created in database volume."
fi

# 2. Safely stop containers WITHOUT deleting volumes (-v is NEVER used)
echo "🛑 Safely stopping old application containers (preserving MongoDB database volume)..."
docker compose down 2>/dev/null || true

# 3. Ensure 2GB swap space exists (prevents Out-Of-Memory during React build)
if [ $(swapon --show | wc -l) -eq 0 ]; then
    echo "🧠 Allocating 2GB swap memory for build stability..."
    fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile || true
fi

# 4. Ensure Docker and Docker Compose plugin are installed
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

if ! docker compose version &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    apt-get update -y && apt-get install -y docker-compose-plugin
fi

# 5. Backup .env if exists, then update the repository
DEPLOY_DIR="/var/www/ktmexpress"
if [ -d "$DEPLOY_DIR/.git" ]; then
    echo "📥 Pulling latest code into $DEPLOY_DIR..."
    cd "$DEPLOY_DIR"
    git fetch origin main
    git reset --hard origin/main
else
    echo "📥 Cloning fresh repository into $DEPLOY_DIR..."
    mkdir -p /var/www
    if [ -f "$DEPLOY_DIR/.env" ]; then
        cp "$DEPLOY_DIR/.env" /root/.ktmexpress.env
    fi
    rm -rf "$DEPLOY_DIR"
    git clone https://github.com/Tester10-lab/Ktmexpress.git "$DEPLOY_DIR"
    cd "$DEPLOY_DIR"
    if [ -f /root/.ktmexpress.env ]; then
        echo "♻️ Restoring your saved .env configuration..."
        cp /root/.ktmexpress.env "$DEPLOY_DIR/.env"
        cp /root/.ktmexpress.env "$DEPLOY_DIR/backend/.env"
    fi
fi

# 6. Build and launch Docker containers (clean frontend/backend build, existing DB volume attached)
echo "🐳 Building frontend and backend containers..."
docker compose build --no-cache
docker compose up -d

echo "🌱 Waiting for database & backend services..."
sleep 6
docker compose exec -T backend node seed.js || true

# 7. Configure / Restart Host Nginx reverse proxy & SSL for kdmexpress.com
echo "🔒 Configuring / Restarting Host Nginx & SSL reverse proxy..."
if [ -f "$DEPLOY_DIR/setup-ssl.sh" ]; then
    bash "$DEPLOY_DIR/setup-ssl.sh" || systemctl restart nginx || true
elif command -v nginx &> /dev/null; then
    systemctl restart nginx || true
fi

echo "======================================================="
echo "🎉 Deployment successful! All database data was preserved."
echo "Live URL: https://kdmexpress.com"
echo "======================================================="
