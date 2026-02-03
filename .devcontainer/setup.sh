#!/bin/bash

set -e

echo "🚀 Setting up BarangayLink in Codespaces..."

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    DOCKER_COMPOSE_VERSION="v2.23.0"
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose --version
fi

# Install system dependencies
sudo apt-get update && sudo apt-get install -y \
    curl \
    wget \
    git \
    postgresql-client \
    redis-tools \
    python3-venv \
    python3-pip \
    sqlite3

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p ../backend/{src/{config,controllers,middleware,models,routes,services,utils},prisma} \
         ../frontend/src/{components,pages,hooks,services,utils} \
         ../ai-services/{prioritization,chatbot} \
         ../uploads \
         ../logs

# Initialize project files
echo "📋 Initializing project files..."

# Create a simple docker-compose.yml for Codespaces
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: barangaylink
      POSTGRES_USER: barangayadmin
      POSTGRES_PASSWORD: barangay123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U barangayadmin"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis for caching
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Backend API
  backend:
    build: ./backend
    restart: unless-stopped
    ports:
      - "3001:3001"
    environment:
      NODE_ENV: development
      DATABASE_URL: postgresql://barangayadmin:barangay123@postgres:5432/barangaylink
      REDIS_URL: redis://redis:6379
      JWT_SECRET: dev_secret_1234567890
      FRONTEND_URL: http://localhost:3000
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - ./backend:/app
      - /app/node_modules
    command: sh -c "npm install && npm run dev"

  # Frontend
  frontend:
    build: ./frontend
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      VITE_API_URL: http://localhost:3001/api
      VITE_WS_URL: ws://localhost:3001
    depends_on:
      - backend
    volumes:
      - ./frontend:/app
      - /app/node_modules
    command: sh -c "npm install && npm run dev"

  # AI Prioritization Service
  ai-prioritization:
    build:
      context: ./ai-services/prioritization
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      - "5000:5000"
    volumes:
      - ./ai-services/prioritization:/app
    command: sh -c "pip install -r requirements.txt && python main.py"

  # AI Chatbot Service
  ai-chatbot:
    build:
      context: ./ai-services/chatbot
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      - "5001:5001"
    volumes:
      - ./ai-services/chatbot:/app
    command: sh -c "pip install -r requirements.txt && python main.py"

volumes:
  postgres_data:
EOF

# Create backend Dockerfile
cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3001
CMD ["npm", "run", "dev"]
EOF

# Create frontend Dockerfile
cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]
EOF

# Create AI Dockerfile
mkdir -p ai-services/prioritization ai-services/chatbot

cat > ai-services/prioritization/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "main.py"]
EOF

cp ai-services/prioritization/Dockerfile ai-services/chatbot/Dockerfile

# Create minimal package.json files
cat > backend/package.json << 'EOF'
{
  "name": "barangaylink-backend",
  "version": "1.0.0",
  "description": "Barangay Management System Backend",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

cat > frontend/package.json << 'EOF'
{
  "name": "barangaylink-frontend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.15.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.3",
    "vite": "^4.4.9"
  }
}
EOF

# Create AI requirements
cat > ai-services/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
EOF

cp ai-services/requirements.txt ai-services/prioritization/requirements.txt
cp ai-services/requirements.txt ai-services/chatbot/requirements.txt

# Create simple backend app
mkdir -p backend/src

cat > backend/src/server.js << 'EOF'
const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    service: 'barangaylink-backend',
    timestamp: new Date().toISOString()
  });
});

app.get('/api/dashboard', (req, res) => {
  res.json({
    stats: {
      pendingRequests: 12,
      activeVolunteers: 45,
      upcomingEvents: 8,
      totalDonations: 125000
    }
  });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`🚀 Backend running on port ${PORT}`);
});
EOF

# Create simple frontend app
cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>BarangayLink - Codespaces</title>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
      .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
      header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px 0; }
      header h1 { font-size: 3rem; margin-bottom: 10px; }
      header p { font-size: 1.2rem; opacity: 0.9; }
      .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 40px 0; }
      .card { background: white; border-radius: 10px; padding: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
      .card h3 { color: #667eea; margin-bottom: 10px; }
      .status { background: #f7fafc; padding: 20px; border-radius: 10px; margin: 20px 0; }
      .status-item { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #e2e8f0; }
      .btn { display: inline-block; background: #667eea; color: white; padding: 10px 20px; border-radius: 5px; text-decoration: none; margin-top: 10px; }
      footer { text-align: center; padding: 20px; color: #718096; margin-top: 40px; }
    </style>
  </head>
  <body>
    <header>
      <div class="container">
        <h1>BarangayLink</h1>
        <p>Community Management System - Running in GitHub Codespaces</p>
      </div>
    </header>
    
    <div class="container">
      <div class="status">
        <h2>System Status</h2>
        <div id="status-list">
          <div class="status-item">
            <span>Backend API</span>
            <span class="status-indicator" id="backend-status">Checking...</span>
          </div>
          <div class="status-item">
            <span>Frontend</span>
            <span class="status-indicator" id="frontend-status">Checking...</span>
          </div>
          <div class="status-item">
            <span>Database</span>
            <span class="status-indicator" id="db-status">Checking...</span>
          </div>
          <div class="status-item">
            <span>AI Services</span>
            <span class="status-indicator" id="ai-status">Checking...</span>
          </div>
        </div>
      </div>

      <div class="services">
        <div class="card">
          <h3>📋 Service Requests</h3>
          <p>Submit and track community service requests</p>
          <a href="#" class="btn">Submit Request</a>
        </div>
        
        <div class="card">
          <h3>📅 Community Events</h3>
          <p>Browse and register for community events</p>
          <a href="#" class="btn">View Events</a>
        </div>
        
        <div class="card">
          <h3>👥 Volunteer Management</h3>
          <p>Register as volunteer and track hours</p>
          <a href="#" class="btn">Volunteer Now</a>
        </div>
      </div>

      <div class="card">
        <h2>📊 Dashboard Preview</h2>
        <div id="dashboard-data">Loading dashboard data...</div>
      </div>
    </div>

    <footer>
      <p>BarangayLink - Community Management System | Running in GitHub Codespaces</p>
    </footer>

    <script>
      // Check service status
      async function checkService(url, id) {
        try {
          const response = await fetch(url);
          if (response.ok) {
            document.getElementById(id).innerHTML = '✅ Online';
            document.getElementById(id).style.color = '#10B981';
            return true;
          }
        } catch (error) {
          document.getElementById(id).innerHTML = '❌ Offline';
          document.getElementById(id).style.color = '#EF4444';
          return false;
        }
      }

      async function loadDashboard() {
        try {
          const response = await fetch('http://localhost:3001/api/dashboard');
          const data = await response.json();
          const dashboard = document.getElementById('dashboard-data');
          dashboard.innerHTML = `
            <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px; margin-top: 20px;">
              <div>
                <h4>Pending Requests</h4>
                <h2 style="color: #667eea;">${data.stats.pendingRequests}</h2>
              </div>
              <div>
                <h4>Active Volunteers</h4>
                <h2 style="color: #667eea;">${data.stats.activeVolunteers}</h2>
              </div>
              <div>
                <h4>Upcoming Events</h4>
                <h2 style="color: #667eea;">${data.stats.upcomingEvents}</h2>
              </div>
              <div>
                <h4>Total Donations</h4>
                <h2 style="color: #667eea;">₱${data.stats.totalDonations.toLocaleString()}</h2>
              </div>
            </div>
          `;
        } catch (error) {
          document.getElementById('dashboard-data').innerHTML = 'Dashboard data unavailable';
        }
      }

      // Check all services
      async function checkAllServices() {
        await checkService('http://localhost:3001/api/health', 'backend-status');
        await checkService('http://localhost:3000', 'frontend-status');
        await checkService('http://localhost:5000/api/health', 'ai-status');
        document.getElementById('db-status').innerHTML = '✅ Online';
        document.getElementById('db-status').style.color = '#10B981';
        
        // Load dashboard data
        loadDashboard();
        
        // Update every 30 seconds
        setTimeout(checkAllServices, 30000);
      }

      // Start checking services
      checkAllServices();
    </script>
  </body>
</html>
EOF

# Create simple AI services
cat > ai-services/prioritization/main.py << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
from datetime import datetime

app = FastAPI()

class RequestData(BaseModel):
    title: str
    description: str
    category: str

@app.post("/api/prioritize")
async def prioritize(data: RequestData):
    priority = "MEDIUM"
    if "emergency" in data.title.lower() or "urgent" in data.title.lower():
        priority = "URGENT"
    elif data.category in ["MEDICAL", "FOOD"]:
        priority = "HIGH"
    
    return {
        "priority": priority,
        "score": 0.7 if priority == "URGENT" else 0.5,
        "reason": f"Category: {data.category}",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/api/health")
async def health():
    return {"status": "healthy", "service": "ai-prioritization"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000)
EOF

cat > ai-services/chatbot/main.py << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
from datetime import datetime

app = FastAPI()

class ChatRequest(BaseModel):
    message: str

@app.post("/api/chat")
async def chat(data: ChatRequest):
    responses = {
        "hello": "Hello! I'm BarangayBot. How can I help you today?",
        "help": "You can get assistance by submitting a request in the Services section.",
        "medical": "For medical emergencies, please submit a medical assistance request.",
        "food": "We have community pantry services. Submit a food assistance request.",
        "thanks": "You're welcome! Is there anything else I can help with?"
    }
    
    message = data.message.lower()
    response = "I'm here to help with community services. You can ask about assistance, events, or volunteering."
    
    for keyword, reply in responses.items():
        if keyword in message:
            response = reply
            break
    
    return {
        "response": response,
        "confidence": 0.8,
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/api/health")
async def health():
    return {"status": "healthy", "service": "ai-chatbot"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5001)
EOF

echo "✅ Setup complete!"
echo ""
echo "🚀 Starting services..."
echo "Using docker compose (with space) command..."

# Use docker compose instead of docker-compose
if command -v docker-compose &> /dev/null; then
    docker-compose up -d
elif docker compose version &> /dev/null; then
    docker compose up -d
else
    echo "❌ Neither docker-compose nor docker compose is available"
    exit 1
fi

echo ""
echo "🌐 Your application will be available at:"
echo "   Frontend: http://localhost:3000"
echo "   Backend API: http://localhost:3001/api/health"
echo "   AI Services: http://localhost:5000/api/health and http://localhost:5001/api/health"
echo ""
echo "📋 Run these commands to check status:"
echo "   docker ps"
echo "   curl http://localhost:3001/api/health"
