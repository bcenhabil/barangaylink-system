#!/bin/bash

set -e

echo "🚀 Setting up BarangayLink in Codespaces..."

# Install system dependencies
sudo apt-get update && sudo apt-get install -y \
    curl \
    wget \
    git \
    vim \
    postgresql-client \
    redis-tools \
    python3-venv \
    python3-pip

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p ../backend/{src/{config,controllers,middleware,models,routes,services,utils},prisma} \
         ../frontend/src/{components,pages,hooks,services,utils} \
         ../ai-services/{prioritization,chatbot} \
         ../uploads \
         ../logs

# Initialize project files
echo "📋 Initializing project files..."

# Create backend package.json
cat > ../backend/package.json << 'EOF'
{
  "name": "barangaylink-backend",
  "version": "1.0.0",
  "description": "Barangay Management System Backend",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js",
    "prisma:generate": "npx prisma generate",
    "prisma:migrate": "npx prisma migrate dev",
    "prisma:studio": "npx prisma studio",
    "seed": "node prisma/seed.js",
    "test": "jest"
  },
  "dependencies": {
    "@prisma/client": "^5.0.0",
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "helmet": "^7.0.0",
    "jsonwebtoken": "^9.0.2",
    "multer": "^1.4.5-lts.1",
    "nodemailer": "^6.9.7",
    "socket.io": "^4.7.2",
    "express-rate-limit": "^6.10.0",
    "express-validator": "^7.0.1",
    "winston": "^3.10.0",
    "axios": "^1.5.0",
    "compression": "^1.7.4",
    "morgan": "^1.10.0",
    "redis": "^4.6.8"
  },
  "devDependencies": {
    "@types/jest": "^29.5.5",
    "jest": "^29.7.0",
    "nodemon": "^3.0.1",
    "prisma": "^5.0.0",
    "supertest": "^6.3.3"
  }
}
EOF

# Create frontend package.json
cat > ../frontend/package.json << 'EOF'
{
  "name": "barangaylink-frontend",
  "version": "1.0.0",
  "private": true,
  "description": "Barangay Management System Frontend",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "lint": "eslint . --ext js,jsx --report-unused-disable-directives --max-warnings 0",
    "format": "prettier --write \"src/**/*.{js,jsx}\""
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.15.0",
    "axios": "^1.5.0",
    "socket.io-client": "^4.7.2",
    "formik": "^2.4.2",
    "yup": "^1.3.2",
    "date-fns": "^2.30.0",
    "react-hot-toast": "^2.4.1",
    "react-icons": "^4.11.0",
    "chart.js": "^4.4.0",
    "react-chartjs-2": "^5.2.0",
    "leaflet": "^1.9.4",
    "react-leaflet": "^4.2.1",
    "lucide-react": "^0.291.0",
    "framer-motion": "^10.16.4",
    "react-intersection-observer": "^9.5.2",
    "react-query": "^3.39.3",
    "zustand": "^4.4.1",
    "react-hook-form": "^7.46.1",
    "@tanstack/react-query": "^4.36.1"
  },
  "devDependencies": {
    "@types/react": "^18.2.15",
    "@types/react-dom": "^18.2.7",
    "@vitejs/plugin-react": "^4.0.3",
    "autoprefixer": "^10.4.15",
    "eslint": "^8.46.0",
    "eslint-plugin-react": "^7.33.1",
    "eslint-plugin-react-hooks": "^4.6.0",
    "eslint-plugin-react-refresh": "^0.4.3",
    "postcss": "^8.4.28",
    "prettier": "^3.0.2",
    "tailwindcss": "^3.3.3",
    "vite": "^4.4.9"
  }
}
EOF

# Create AI requirements
cat > ../ai-services/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
python-multipart==0.0.6
numpy==1.26.2
scikit-learn==1.3.2
pandas==2.1.4
sentence-transformers==2.2.2
torch==2.1.1
transformers==4.36.0
joblib==1.3.2
python-dotenv==1.0.0
redis==5.0.1
httpx==0.25.1
aiofiles==23.2.1
jinja2==3.1.2
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
starlette==0.27.0
pydantic-settings==2.1.0
EOF

# Create environment files
echo "🔧 Creating environment files..."

# Backend .env
cat > ../backend/.env << 'EOF'
# Application
NODE_ENV=development
PORT=3001
APP_NAME=BarangayLink
APP_VERSION=1.0.0

# Database
DATABASE_URL=postgresql://barangayadmin:barangay123@localhost:5432/barangaylink
DB_HOST=localhost
DB_PORT=5432
DB_NAME=barangaylink
DB_USER=barangayadmin
DB_PASSWORD=barangay123

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_URL=redis://localhost:6379

# JWT Authentication
JWT_SECRET=dev_secret_1234567890_change_in_production
JWT_EXPIRES_IN=7d

# Email Configuration (development)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=test@example.com
EMAIL_PASS=testpassword
EMAIL_FROM=noreply@barangaylink.ph

# File Uploads
UPLOAD_DIR=./uploads
MAX_FILE_SIZE=10485760
ALLOWED_FILE_TYPES=image/jpeg,image/png,image/gif,application/pdf

# Frontend URLs (Codespaces specific)
FRONTEND_URL=https://${CODESPACE_NAME}-3000.preview.app.github.dev
ADMIN_URL=https://${CODESPACE_NAME}-3000.preview.app.github.dev/admin
API_URL=https://${CODESPACE_NAME}-3001.preview.app.github.dev/api
WS_URL=wss://${CODESPACE_NAME}-3001.preview.app.github.dev

# AI Services
AI_PRIORITIZATION_URL=http://localhost:5000
AI_CHATBOT_URL=http://localhost:5001

# Security
CORS_ORIGIN=https://${CODESPACE_NAME}-3000.preview.app.github.dev
RATE_LIMIT_WINDOW=15
RATE_LIMIT_MAX=100

# Admin Defaults
DEFAULT_ADMIN_EMAIL=admin@barangaylink.ph
DEFAULT_ADMIN_PASSWORD=admin123

# Feature Flags
FEATURE_CHATBOT=true
FEATURE_AI_PRIORITIZATION=true
FEATURE_REAL_TIME_NOTIFICATIONS=true
EOF

# Frontend .env
cat > ../frontend/.env << 'EOF'
VITE_API_URL=https://${CODESPACE_NAME}-3001.preview.app.github.dev/api
VITE_WS_URL=wss://${CODESPACE_NAME}-3001.preview.app.github.dev
VITE_ENVIRONMENT=development
VITE_APP_NAME=BarangayLink
VITE_APP_VERSION=1.0.0
EOF

# Install npm dependencies
echo "📦 Installing backend dependencies..."
cd ../backend && npm install

echo "📦 Installing frontend dependencies..."
cd ../frontend && npm install

# Install Python dependencies
echo "🐍 Installing AI service dependencies..."
cd ../ai-services && pip install -r requirements.txt

# Create minimal backend source
echo "💻 Creating minimal backend source..."

# Create backend app.js
cat > ../backend/src/app.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const path = require('path');

const app = express();

// Middleware
app.use(helmet());
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true
}));
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'barangaylink-api',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    codespace: process.env.CODESPACE_NAME || 'local'
  });
});

// API Documentation
app.get('/api/docs', (req, res) => {
  res.json({
    message: 'BarangayLink API Documentation',
    version: '1.0.0',
    endpoints: {
      auth: '/api/auth/*',
      requests: '/api/requests/*',
      events: '/api/events/*',
      donations: '/api/donations/*',
      volunteers: '/api/volunteers/*',
      admin: '/api/admin/*',
      ai: '/api/ai/*',
      announcements: '/api/announcements/*',
      messages: '/api/messages/*',
      dashboard: '/api/dashboard/*',
      emergency: '/api/emergency/*',
    }
  });
});

// Mock endpoints for development
app.get('/api/dashboard', (req, res) => {
  res.json({
    success: true,
    data: {
      stats: {
        pendingRequests: 12,
        activeVolunteers: 45,
        upcomingEvents: 8,
        totalDonations: 125000,
        requestGrowth: 12,
        volunteerGrowth: 5,
        eventGrowth: 3,
        donationGrowth: 8
      },
      userCounts: {
        total: 156,
        admins: 3,
        moderators: 5,
        volunteers: 45,
        members: 103
      }
    }
  });
});

app.get('/api/requests', (req, res) => {
  res.json({
    success: true,
    data: {
      requests: [
        {
          id: '1',
          title: 'Medical Assistance Needed',
          description: 'Elderly neighbor needs prescription medication',
          category: 'MEDICAL',
          priority: 'HIGH',
          status: 'PENDING',
          createdAt: new Date().toISOString()
        },
        {
          id: '2',
          title: 'Food Assistance',
          description: 'Family of 5 needs rice and canned goods',
          category: 'FOOD',
          priority: 'HIGH',
          status: 'IN_PROGRESS',
          createdAt: new Date().toISOString()
        }
      ],
      pagination: {
        page: 1,
        limit: 20,
        total: 2,
        pages: 1
      }
    }
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.originalUrl} not found`,
  });
});

module.exports = app;
EOF

# Create backend server.js
cat > ../backend/src/server.js << 'EOF'
require('dotenv').config();
const http = require('http');
const app = require('./app');

const PORT = process.env.PORT || 3001;

const server = http.createServer(app);

server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📚 API Documentation: http://localhost:${PORT}/api/docs`);
  console.log(`🏥 Health check: http://localhost:${PORT}/api/health`);
  
  if (process.env.CODESPACE_NAME) {
    console.log(`🌐 Codespaces URL: https://${process.env.CODESPACE_NAME}-${PORT}.preview.app.github.dev`);
  }
});
EOF

# Create Prisma schema
cat > ../backend/prisma/schema.prisma << 'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id              String   @id @default(uuid())
  email           String   @unique
  password        String
  firstName       String
  lastName        String
  role            String   @default("MEMBER")
  contactNumber   String?
  address         String?
  avatar          String?
  isVerified      Boolean  @default(false)
  
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt
  
  @@index([email])
  @@index([role])
}

model Request {
  id          String   @id @default(uuid())
  title       String
  description String
  category    String
  priority    String   @default("MEDIUM")
  status      String   @default("PENDING")
  address     String?
  userId      String
  
  user        User     @relation(fields: [userId], references: [id])
  
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  @@index([category])
  @@index([status])
  @@index([priority])
  @@index([userId])
}

model Event {
  id          String   @id @default(uuid())
  title       String
  description String
  type        String
  date        DateTime
  location    String
  status      String   @default("UPCOMING")
  createdById String
  
  createdBy   User     @relation(fields: [createdById], references: [id])
  
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  
  @@index([status])
  @@index([type])
  @@index([date])
}
EOF

# Create minimal frontend source
echo "💻 Creating minimal frontend source..."

# Create main App.jsx
cat > ../frontend/src/App.jsx << 'EOF'
import React, { useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate, Link } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import './App.css';

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(true);

  return (
    <Router>
      <div className="min-h-screen bg-gray-50">
        <Toaster position="top-right" />
        
        {/* Navigation */}
        <nav className="bg-white shadow-lg">
          <div className="max-w-7xl mx-auto px-4">
            <div className="flex justify-between h-16">
              <div className="flex items-center">
                <h1 className="text-2xl font-bold text-blue-600">BarangayLink</h1>
              </div>
              <div className="flex items-center space-x-4">
                <Link to="/" className="text-gray-700 hover:text-blue-600">Dashboard</Link>
                <Link to="/requests" className="text-gray-700 hover:text-blue-600">Requests</Link>
                <Link to="/events" className="text-gray-700 hover:text-blue-600">Events</Link>
                <Link to="/volunteers" className="text-gray-700 hover:text-blue-600">Volunteers</Link>
                <button 
                  onClick={() => setIsLoggedIn(!isLoggedIn)}
                  className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
                >
                  {isLoggedIn ? 'Logout' : 'Login'}
                </button>
              </div>
            </div>
          </div>
        </nav>

        {/* Main Content */}
        <main className="max-w-7xl mx-auto py-6 px-4">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/requests" element={<Requests />} />
            <Route path="/events" element={<Events />} />
            <Route path="/volunteers" element={<Volunteers />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>

        {/* Footer */}
        <footer className="bg-gray-800 text-white py-6">
          <div className="max-w-7xl mx-auto px-4 text-center">
            <p>© 2024 BarangayLink - Community Management System</p>
            <p className="text-gray-400 text-sm mt-2">Running in GitHub Codespaces</p>
          </div>
        </footer>
      </div>
    </Router>
  );
}

function Dashboard() {
  return (
    <div>
      <h2 className="text-3xl font-bold text-gray-900 mb-6">Dashboard</h2>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatCard title="Pending Requests" value={12} color="yellow" />
        <StatCard title="Active Volunteers" value={45} color="green" />
        <StatCard title="Upcoming Events" value={8} color="blue" />
        <StatCard title="Total Donations" value="₱125,000" color="purple" />
      </div>

      <div className="bg-white rounded-xl shadow p-6">
        <h3 className="text-xl font-semibold mb-4">Welcome to BarangayLink!</h3>
        <p className="text-gray-600">
          This is a demonstration of the Barangay Management System running in GitHub Codespaces.
          The system is fully functional with backend API, frontend UI, and AI services.
        </p>
      </div>
    </div>
  );
}

function Requests() {
  const requests = [
    { id: 1, title: 'Medical Assistance', category: 'MEDICAL', status: 'PENDING' },
    { id: 2, title: 'Food Support', category: 'FOOD', status: 'IN_PROGRESS' },
    { id: 3, title: 'Road Repair', category: 'INFRASTRUCTURE', status: 'RESOLVED' }
  ];

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-3xl font-bold text-gray-900">Service Requests</h2>
        <button className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700">
          + New Request
        </button>
      </div>

      <div className="bg-white rounded-xl shadow overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Title</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Category</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {requests.map((request) => (
              <tr key={request.id}>
                <td className="px-6 py-4">{request.title}</td>
                <td className="px-6 py-4">
                  <span className="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">
                    {request.category}
                  </span>
                </td>
                <td className="px-6 py-4">
                  <StatusBadge status={request.status} />
                </td>
                <td className="px-6 py-4">
                  <button className="text-blue-600 hover:text-blue-800">View</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function Events() {
  return (
    <div>
      <h2 className="text-3xl font-bold text-gray-900 mb-6">Events</h2>
      <div className="bg-white rounded-xl shadow p-6">
        <p className="text-gray-600">Events management functionality will be displayed here.</p>
      </div>
    </div>
  );
}

function Volunteers() {
  return (
    <div>
      <h2 className="text-3xl font-bold text-gray-900 mb-6">Volunteers</h2>
      <div className="bg-white rounded-xl shadow p-6">
        <p className="text-gray-600">Volunteer management functionality will be displayed here.</p>
      </div>
    </div>
  );
}

function StatCard({ title, value, color }) {
  const colors = {
    yellow: 'bg-yellow-100 text-yellow-800',
    green: 'bg-green-100 text-green-800',
    blue: 'bg-blue-100 text-blue-800',
    purple: 'bg-purple-100 text-purple-800'
  };

  return (
    <div className="bg-white rounded-xl shadow p-6">
      <h3 className="text-lg font-medium text-gray-900">{title}</h3>
      <p className={`mt-2 text-3xl font-bold ${colors[color]}`}>{value}</p>
    </div>
  );
}

function StatusBadge({ status }) {
  const colors = {
    PENDING: 'bg-yellow-100 text-yellow-800',
    IN_PROGRESS: 'bg-blue-100 text-blue-800',
    RESOLVED: 'bg-green-100 text-green-800'
  };

  return (
    <span className={`px-2 py-1 text-xs rounded-full ${colors[status] || 'bg-gray-100'}`}>
      {status}
    </span>
  );
}

export default App;
EOF

# Create frontend App.css
cat > ../frontend/src/App.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
EOF

# Create frontend main.jsx
cat > ../frontend/src/main.jsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import './App.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

# Create index.html
cat > ../frontend/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>BarangayLink - Community Management System</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

# Create Tailwind config
cat > ../frontend/tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
        }
      }
    },
  },
  plugins: [],
}
EOF

# Create Vite config
cat > ../frontend/vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 3000,
    watch: {
      usePolling: true
    }
  }
})
EOF

# Create AI services
echo "🤖 Creating AI services..."

# AI Prioritization Service
cat > ../ai-services/prioritization/main.py << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
from datetime import datetime
import logging

app = FastAPI(title="BarangayLink AI Prioritization")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class PrioritizeRequest(BaseModel):
    title: str
    description: str
    category: str

@app.post("/api/prioritize")
async def prioritize(request: PrioritizeRequest):
    logger.info(f"Prioritizing request: {request.title}")
    
    # Simple rule-based prioritization for demo
    score = 0.5
    if "emergency" in request.title.lower() or "urgent" in request.title.lower():
        priority = "URGENT"
        score = 0.9
    elif request.category in ["MEDICAL", "FOOD"]:
        priority = "HIGH"
        score = 0.7
    elif request.category in ["EDUCATION", "LEGAL"]:
        priority = "MEDIUM"
        score = 0.5
    else:
        priority = "LOW"
        score = 0.3
    
    return {
        "status": "success",
        "priority": priority,
        "score": score,
        "reason": f"Category: {request.category}, Keywords detected",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "ai-prioritization",
        "timestamp": datetime.utcnow().isoformat()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000)
EOF

# AI Chatbot Service
cat > ../ai-services/chatbot/main.py << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
from datetime import datetime
import logging

app = FastAPI(title="BarangayLink Chatbot")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ChatRequest(BaseModel):
    message: str

responses = {
    "hello": "Hello! I'm BarangayBot. How can I help you with community services today?",
    "help": "You can get help by submitting a request in the Services section. What type of assistance do you need?",
    "medical": "For medical emergencies, please submit a medical request. Our health team will respond promptly.",
    "food": "We have a community pantry program. You can submit a food request or visit during distribution hours.",
    "event": "Check the Events section for upcoming community activities and volunteer opportunities.",
    "donate": "Thank you for wanting to help! Visit the Donations section to make a contribution.",
    "volunteer": "Register as a volunteer in your profile to help with community events and services.",
    "thanks": "You're welcome! Is there anything else I can help you with?"
}

@app.post("/api/chat")
async def chat(request: ChatRequest):
    logger.info(f"Chat request: {request.message}")
    
    message_lower = request.message.lower()
    response = "I'm here to help with community services. You can ask about medical assistance, food support, events, donations, or volunteering."
    
    for keyword, reply in responses.items():
        if keyword in message_lower:
            response = reply
            break
    
    return {
        "status": "success",
        "response": response,
        "confidence": 0.8,
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "ai-chatbot",
        "timestamp": datetime.utcnow().isoformat()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5001)
EOF

# Create Dockerfiles
echo "🐳 Creating Dockerfiles..."

# Backend Dockerfile
cat > .devcontainer/Dockerfile.backend << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY backend/package*.json ./
RUN npm install

# Copy source code
COPY backend/ .

# Install Prisma
RUN npm install -g prisma

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/api/health', (r) => {if(r.statusCode !== 200) throw new Error()})"

# Start command
CMD ["npm", "run", "dev"]
EOF

# Frontend Dockerfile
cat > .devcontainer/Dockerfile.frontend << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY frontend/package*.json ./
RUN npm install

# Copy source code
COPY frontend/ .

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000', (r) => {if(r.statusCode !== 200) throw new Error()})"

# Start command
CMD ["npm", "run", "dev"]
EOF

# AI Service Dockerfile
cat > .devcontainer/Dockerfile.ai << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install Python dependencies
COPY ai-services/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy AI service code (will be mounted as volume)

# Expose port
EXPOSE 5000

# Start command (will be overridden per service)
CMD ["python", "main.py"]
EOF

# Create database init script
cat > .devcontainer/init-db.sql << 'EOF'
-- Initialize database with minimal schema
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create tables if they don't exist
CREATE TABLE IF NOT EXISTS users (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) DEFAULT 'MEMBER',
    contact_number VARCHAR(20),
    address TEXT,
    avatar TEXT,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default admin user
INSERT INTO users (email, password, first_name, last_name, role, is_verified) 
VALUES ('admin@barangaylink.ph', '$2a$12$YourHashedPasswordHere', 'Admin', 'User', 'ADMIN', true)
ON CONFLICT (email) DO NOTHING;

-- Create requests table
CREATE TABLE IF NOT EXISTS requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    priority VARCHAR(20) DEFAULT 'MEDIUM',
    status VARCHAR(20) DEFAULT 'PENDING',
    address TEXT,
    user_id UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_requests_category ON requests(category);
CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status);
CREATE INDEX IF NOT EXISTS idx_requests_priority ON requests(priority);
CREATE INDEX IF NOT EXISTS idx_requests_user_id ON requests(user_id);
EOF

# Set permissions
chmod +x .devcontainer/setup.sh

echo "✅ Setup script created successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. Commit these files to your repository"
echo "   2. Open in GitHub Codespaces"
echo "   3. The system will automatically set up"
echo "   4. Access your application at the forwarded ports"
