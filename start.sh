#!/bin/bash
# start.sh - Simplified startup for Codespaces

echo "🚀 Starting BarangayLink..."

# Check if we're in Codespaces
if [ -n "$CODESPACES" ]; then
    echo "📦 Running in GitHub Codespaces"
    
    # Use docker compose if available, otherwise try docker-compose
    if command -v docker-compose &> /dev/null; then
        echo "Using docker-compose..."
        docker-compose up -d
    elif docker compose version &> /dev/null; then
        echo "Using docker compose..."
        docker compose up -d
    else
        echo "❌ Docker Compose not found. Installing..."
        # Install Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        docker-compose up -d
    fi
    
    # Wait for services to start
    sleep 5
    
    # Check services
    echo ""
    echo "🔍 Checking services..."
    curl -s http://localhost:3001/api/health || echo "Backend not ready"
    curl -s http://localhost:5000/api/health || echo "AI Prioritization not ready"
    
    echo ""
    echo "✅ Services starting..."
    echo "🌐 Open http://localhost:3000 in your browser"
    
else
    echo "Running locally..."
    # Local development setup
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    elif docker compose version &> /dev/null; then
        docker compose up -d
    fi
fi
