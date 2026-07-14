#!/bin/bash
set -e

echo "🚀 Starting Hanadiz Backend Build Process"

# Install system dependencies
echo "📦 Installing system dependencies..."
apt-get update && apt-get install -y \
    gcc \
    g++ \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements/production.txt

# Run database migrations
echo "🗄️ Running database migrations..."
alembic upgrade head

# Create required directories
echo "📁 Creating required directories..."
mkdir -p logs backups

# Run health check
echo "✅ Build completed successfully!"