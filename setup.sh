#!/bin/bash

# BarangayLink Setup Script
set -e

echo "🚀 Starting BarangayLink Setup..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p {backend,frontend,ai-services/{prioritization,chatbot},nginx/{ssl,logs},uploads,logs}

# Copy configuration files
echo "📋 Copying configuration files..."

# Create environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit the .env file with your configuration before continuing."
    exit 1
fi

# Load environment variables
source .env

# Generate SSL certificates for development
echo "🔐 Generating SSL certificates for development..."
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout nginx/ssl/barangaylink.key \
    -out nginx/ssl/barangaylink.crt \
    -subj "/C=PH/ST=Manila/L=Manila/O=BarangayLink/CN=barangaylink.local"

# Build and start services
echo "🔨 Building Docker images..."
docker-compose build

echo "🚀 Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check service status
echo "🔍 Checking service status..."
docker-compose ps

# Run database migrations
echo "🗄️  Running database migrations..."
docker-compose exec backend npx prisma migrate deploy

# Seed initial data
echo "🌱 Seeding initial data..."
docker-compose exec backend node prisma/seed.js

echo "✅ Setup complete!"
echo ""
echo "📋 Access Information:"
echo "   Frontend: https://barangaylink.local (or http://localhost:3000)"
echo "   Backend API: http://localhost:3001/api"
echo "   API Documentation: http://localhost:3001/api/docs"
echo "   PGAdmin: http://localhost:5050"
echo "   Redis Commander: http://localhost:8081"
echo ""
echo "🔐 Default Admin Credentials:"
echo "   Email: admin@barangaylink.ph"
echo "   Password: admin123"
echo ""
echo "🚨 Important: Add '127.0.0.1 barangaylink.local' to your hosts file:"
echo "   Linux/Mac: /etc/hosts"
echo "   Windows: C:\Windows\System32\drivers\etc\hosts"
echo ""
echo "To stop the services: docker-compose down"
echo "To view logs: docker-compose logs -f"
