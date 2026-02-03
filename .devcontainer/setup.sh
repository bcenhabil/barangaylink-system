#!/bin/bash
echo "🔧 Setting up BarangayLink development environment..."

# Install backend dependencies
echo "Installing backend dependencies..."
cd /workspaces/barangaylink-system/backend
npm ci

# Generate Prisma Client
npx prisma generate

# Install frontend dependencies
echo "Installing frontend dependencies..."
cd /workspaces/barangaylink-system/frontend
npm ci

# Install Python dependencies for AI services
echo "Installing AI service dependencies..."
cd /workspaces/barangaylink-system/ai-services/prioritization
pip install -r requirements.txt
cd /workspaces/barangaylink-system/ai-services/chatbot
pip install -r requirements.txt

echo "✅ Setup complete!"
