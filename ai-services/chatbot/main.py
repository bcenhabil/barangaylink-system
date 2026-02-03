from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import json
import re
from datetime import datetime
import logging
from sentence_transformers import SentenceTransformer, util
import numpy as np
from difflib import SequenceMatcher
import pandas as pd

app = FastAPI(
    title="BarangayLink Chatbot Service",
    description="AI chatbot for community assistance and FAQs",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class Chatbot:
    def __init__(self):
        # Load knowledge base
        try:
            with open('knowledge_base.json', 'r', encoding='utf-8') as f:
                self.knowledge_base = json.load(f)
            logger.info(f"Loaded {len(self.knowledge_base)} knowledge base entries")
        except FileNotFoundError:
            logger.warning("Knowledge base file not found, using default")
            self.knowledge_base = self.create_default_knowledge_base()
        
        # Load Filipino knowledge base
        try:
            with open('knowledge_base_filipino.json', 'r', encoding='utf-8') as f:
                self.knowledge_base_filipino = json.load(f)
            logger.info(f"Loaded {len(self.knowledge_base_filipino)} Filipino knowledge base entries")
        except FileNotFoundError:
            logger.warning("Filipino knowledge base not found")
            self.knowledge_base_filipino = []
        
        # Initialize sentence transformer for semantic search
        try:
            self.model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')
            logger.info("Sentence transformer model loaded successfully")
        except Exception as e:
            logger.warning(f"Failed to load sentence transformer: {e}")
            self.model = None
        
        # Precompute embeddings for knowledge base
        if self.model:
            self.kb_embeddings = self.precompute_embeddings()
            self.kb_filipino_embeddings = self.precompute_filipino_embeddings()
        
        # Common patterns for quick matching
        self.patterns = self.initialize_patterns()
        
        # User session management
        self.user_sessions = {}
    
    def create_default_knowledge_base(self):
        """Create default knowledge base if file not found"""
        return [
            {
                "id": "1",
                "question": "How do I submit a request for help?",
                "answer": "You can submit a help request by going to the Services section and clicking 'New Request'. Fill in the details about what you need help with, and our AI will prioritize it for faster assistance.",
                "category": "requests",
                "tags": ["request", "help", "submit", "assistance"],
                "actions": ["Go to Services", "View Tutorial"],
                "language": "en"
            },
            {
                "id": "2",
                "question": "What types of assistance are available?",
                "answer": "We provide assistance in several categories: Medical, Food, Education, Emergency, Infrastructure, Legal, Financial, and other community needs. Select the category that best fits your situation when submitting a request.",
                "category": "services",
                "tags": ["categories", "assistance", "types", "help"],
                "actions": ["View Categories", "Submit Request"],
                "language": "en"
            }
        ]
    
    def initialize_patterns(self):
        """Initialize quick matching patterns"""
        return {
            'greetings': {
                'patterns': ['hello', 'hi', 'hey', 'good morning', 'good afternoon', 'good evening', 'kamusta', 'mabuhay'],
                'response': "Hello! I'm BarangayBot, your community assistant. How can I help you today?",
                'actions': ['Submit Request', 'Browse Events', 'Make Donation']
            },
            'thanks': {
                'patterns': ['thank you', 'thanks', 'salamat', 'maraming salamat'],
                'response': "You're welcome! Is there anything else I can help you with?",
                'actions': []
            },
            'farewell': {
                'patterns': ['bye', 'goodbye', 'see you', 'paalam', 'ingat'],
                'response': "Goodbye! Remember, I'm here 24/7 to help with any community needs.",
                'actions': []
            }
        }
    
    def precompute_embeddings(self):
        """Precompute embeddings for English knowledge base"""
        texts = [item['question'] + " " + item.get('answer', '') for item in self.knowledge_base]
        return self.model.encode(texts, convert_to_tensor=True, show_progress_bar=False)
    
    def precompute_filipino_embeddings(self):
        """Precompute embeddings for Filipino knowledge base"""
        if not self.knowledge_base_filipino:
            return None
        texts = [item['question'] + " " + item.get('answer', '') for item in self.knowledge_base_filipino]
        return self.model.encode(texts, convert_to_tensor=True, show_progress_bar=False)
    
    def detect_language(self, text: str) -> str:
        """Detect if text is in English or Filipino"""
        filipino_words = ['ako', 'ikaw', 'siya', 'kami', 'tayo', 'sila', 'ito', 'iyan', 'iyon',
                         'ang', 'ng', 'sa', 'ni', 'kay', 'para', 'dahil', 'kung', 'nang',
                         'pero', 'at', 'o', 'kaso', 'mga', 'po', 'opo', 'hindi', 'oo']
        
        text_lower = text.lower()
        filipino_count = sum(1 for word in filipino_words if word in text_lower)
        english_count = len(text_lower.split())
        
        if filipino_count / max(english_count, 1) > 0.3:
            return 'filipino'
        return 'english'
    
    def get_response(self, query: str, context: Dict = None) -> Dict:
        """Get response for user query with context awareness"""
        session_id = context.get('session_id') if context else None
        language = self.detect_language(query)
        
        # Check for quick patterns first
        pattern_response = self.check_patterns(query.lower())
        if pattern_response:
            return pattern_response
        
        # Get user context if available
        user_context = self.get_user_context(session_id, context)
        
        # Try semantic search if model available
        if self.model:
            semantic_response = self.semantic_search(query, language, user_context)
            if semantic_response['confidence'] > 0.6:
                return semantic_response
        
        # Fallback to keyword matching
        return self.keyword_matching(query, language, user_context)
    
    def check_patterns(self, query: str) -> Optional[Dict]:
        """Check for quick pattern matches"""
        for category, config in self.patterns.items():
            patterns = config['patterns']
            if any(pattern in query for pattern in patterns):
                return self.format_response(
                    config['response'],
                    confidence=0.95,
                    category=category,
                    suggested_actions=config['actions']
                )
        return None
    
    def semantic_search(self, query: str, language: str, context: Dict) -> Dict:
        """Find best matching response using semantic search"""
        # Select appropriate knowledge base
        if language == 'filipino' and self.kb_filipino_embeddings is not None:
            kb = self.knowledge_base_filipino
            embeddings = self.kb_filipino_embeddings
        else:
            kb = self.knowledge_base
            embeddings = self.kb_embeddings
        
        query_embedding = self.model.encode(query, convert_to_tensor=True)
        
        # Compute cosine similarities
        similarities = util.cos_sim(query_embedding, embeddings)[0]
        
        # Find best match
        best_idx = similarities.argmax().item()
        best_score = similarities[best_idx].item()
        
        # Apply context boosting if available
        if context.get('recent_category'):
            best_item = kb[best_idx]
            if context['recent_category'] in best_item.get('category', ''):
                best_score *= 1.2  # Boost score for relevant category
        
        if best_score > 0.5:  # Threshold
            best_match = kb[best_idx]
            return self.format_response(
                best_match['answer'],
                confidence=best_score,
                category=best_match.get('category', 'general'),
                sources=[best_match.get('source', 'Knowledge Base')],
                suggested_actions=best_match.get('actions', []),
                language=language
            )
        
        return self.format_response(
            "I'm not sure about that. Could you rephrase or ask about something else?",
            confidence=0.3,
            suggested_actions=['Browse FAQ', 'Contact Support'],
            language=language
        )
    
    def keyword_matching(self, query: str, language: str, context: Dict) -> Dict:
        """Keyword-based response matching"""
        query_lower = query.lower()
        
        # Service-related queries
        service_patterns = {
            r'request|help|assistance|need help|tulong|saklolo': {
                'response': "You can submit a help request in the Services section. What type of assistance do you need?",
                'actions': ['Medical Help', 'Food Support', 'Emergency'],
                'confidence': 0.8,
                'category': 'requests'
            },
            r'medical|doctor|hospital|sick|medicine|doktor|gamot|sakit': {
                'response': "For medical emergencies, call 911 immediately. For non-emergencies, submit a medical request through our system.",
                'actions': ['Submit Medical Request', 'Find Health Center', 'Emergency Contacts'],
                'confidence': 0.85,
                'category': 'medical'
            },
            r'food|hunger|meal|eat|gutom|pagkain|bigas': {
                'response': "We have food assistance programs. Submit a food request or visit our community pantry during operating hours.",
                'actions': ['Submit Food Request', 'View Pantry Locations', 'Donate Food'],
                'confidence': 0.8,
                'category': 'food'
            },
            r'event|activity|program|meeting|pulong|gathering': {
                'response': "Check the Events section for upcoming community activities. You can also register as a volunteer for events!",
                'actions': ['Browse Events', 'Volunteer Registration', 'Create Event'],
                'confidence': 0.8,
                'category': 'events'
            },
            r'donate|donation|contribute|help financially|bigay|abuloy|donasyon': {
                'response': "Thank you for wanting to help! Visit the Donations section to contribute. All donations are tracked transparently.",
                'actions': ['Make Donation', 'View Campaigns', 'Donation History'],
                'confidence': 0.9,
                'category': 'donations'
            },
            r'volunteer|volunteering|help others|tumulong|boluntaryo': {
                'response': "That's wonderful! Register as a volunteer in your profile settings, then browse available opportunities.",
                'actions': ['Volunteer Registration', 'View Opportunities', 'My Assignments'],
                'confidence': 0.85,
                'category': 'volunteers'
            },
            r'clearance|certificate|document|permit|cedula|permito': {
                'response': "For barangay clearances, please visit the office with: 1) Valid ID, 2) Proof of residency, 3) Purpose of clearance.",
                'actions': ['Requirements List', 'Office Hours', 'Online Request'],
                'confidence': 0.8,
                'category': 'documents'
            },
            r'complaint|problem|issue|reklamo|problema': {
                'response': "You can submit a formal complaint through the Services section. Please provide detailed information and evidence if available.",
                'actions': ['Submit Complaint', 'View Process', 'Status Tracking'],
                'confidence': 0.8,
                'category': 'complaints'
            },
            r'contact|phone|number|tawag|telepono': {
                'response': "You can contact the barangay office at (02) 123-4567 during office hours (Monday-Friday, 8AM-5PM).",
                'confidence': 0.7,
                'actions': ['Emergency Contacts', 'Office Location', 'Email Support'],
                'category': 'contact'
            },
            r'emergency|emergency|aksidente|sakuna|sunog|baha': {
                'response': "In life-threatening emergencies, call 911 immediately. For community emergencies, submit an emergency alert through our system.",
                'confidence': 0.9,
                'actions': ['Submit Emergency', 'Emergency Contacts', 'Disaster Preparedness'],
                'category': 'emergency'
            },
            r'location|address|map|directions|lokasyon|address|mapa': {
                'response': "The barangay office is located at [Your Barangay Address]. You can view it on the map in the Contact section.",
                'confidence': 0.7,
                'actions': ['View on Map', 'Get Directions', 'Office Hours'],
                'category': 'location'
            }
        }
        
        # Check patterns
        for pattern, config in service_patterns.items():
            if re.search(pattern, query_lower, re.IGNORECASE):
                # Boost confidence if category matches user context
                confidence = config['confidence']
                if context.get('recent_category') == config['category']:
                    confidence = min(confidence * 1.2, 0.95)
                
                return self.format_response(
                    config['response'],
                    confidence=confidence,
                    category=config['category'],
                    suggested_actions=config['actions'],
                    language=language
                )
        
        # Default response
        default_responses = {
            'english': "I'm still learning. For specific questions, please contact the barangay office directly or check our FAQ section.",
            'filipino': "Pasensya na, hindi ko pa alam ang sagot diyan. Para sa mga tiyak na tanong, pakikontak ang opisina ng barangay o tingnan ang aming FAQ."
        }
        
        return self.format_response(
            default_responses.get(language, default_responses['english']),
            confidence=0.3,
            suggested_actions=['Contact Support', 'Browse FAQ', 'Submit General Inquiry'],
            language=language
        )
    
    def get_user_context(self, session_id: Optional[str], context: Dict) -> Dict:
        """Get user context from session"""
        if not session_id or session_id not in self.user_sessions:
            return {
                'recent_queries': [],
                'recent_category': None,
                'preferred_language': context.get('language', 'english')
            }
        
        session = self.user_sessions[session_id]
        return {
            'recent_queries': session.get('recent_queries', [])[-5:],  # Last 5 queries
            'recent_category': session.get('recent_category'),
            'preferred_language': session.get('preferred_language', 'english')
        }
    
    def update_user_session(self, session_id: str, query: str, response_category: str):
        """Update user session with latest interaction"""
        if session_id not in self.user_sessions:
            self.user_sessions[session_id] = {
                'recent_queries': [],
                'recent_category': None,
                'created_at': datetime.utcnow().isoformat()
            }
        
        session = self.user_sessions[session_id]
        session['recent_queries'].append({
            'query': query,
            'timestamp': datetime.utcnow().isoformat()
        })
        
        # Keep only last 10 queries
        if len(session['recent_queries']) > 10:
            session['recent_queries'] = session['recent_queries'][-10:]
        
        session['recent_category'] = response_category
        session['last_active'] = datetime.utcnow().isoformat()
    
    def format_response(self, response: str, confidence: float, 
                       category: str = 'general', sources: List[str] = None, 
                       suggested_actions: List[str] = None, language: str = 'english') -> Dict:
        """Format response in standard structure"""
        return {
            'response': response,
            'confidence': round(confidence, 2),
            'category': category,
            'sources': sources or [],
            'suggested_actions': suggested_actions or [],
            'language': language,
            'timestamp': datetime.utcnow().isoformat(),
            'response_id': f"RES-{int(datetime.utcnow().timestamp())}"
        }

# Initialize chatbot
chatbot = Chatbot()

# Pydantic models
class ChatRequest(BaseModel):
    message: str
    context: Optional[Dict] = None
    session_id: Optional[str] = None

class FeedbackRequest(BaseModel):
    session_id: str
    response_id: str
    helpful: bool
    feedback: Optional[str] = None

class KnowledgeBaseUpdate(BaseModel):
    entries: List[Dict]

# API Endpoints
@app.post("/api/chat")
async def chat(request: ChatRequest):
    """Chat with the AI assistant"""
    try:
        logger.info(f"Chat request: {request.message[:50]}...")
        
        response = chatbot.get_response(
            query=request.message,
            context={
                'session_id': request.session_id,
                'language': request.context.get('language', 'english') if request.context else 'english',
                'user_role': request.context.get('user_role') if request.context else None
            }
        )
        
        # Update user session
        if request.session_id:
            chatbot.update_user_session(request.session_id, request.message, response['category'])
        
        logger.info(f"Chat response: {response['confidence']} confidence")
        
        return {
            "status": "success",
            "data": response
        }
        
    except Exception as e:
        logger.error(f"Chat error: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/chat/feedback")
async def submit_feedback(request: FeedbackRequest):
    """Submit feedback on chatbot responses"""
    try:
        logger.info(f"Feedback received: helpful={request.helpful}")
        
        # Store feedback for model improvement
        feedback_data = {
            'session_id': request.session_id,
            'response_id': request.response_id,
            'helpful': request.helpful,
            'feedback': request.feedback,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # In production, store in database
        # For now, just log it
        logger.info(f"Feedback stored: {feedback_data}")
        
        return {
            "status": "success",
            "message": "Thank you for your feedback! It helps me improve."
        }
        
    except Exception as e:
        logger.error(f"Feedback error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/knowledge-base/update")
async def update_knowledge_base(request: KnowledgeBaseUpdate):
    """Update the knowledge base (admin only)"""
    try:
        # In production, add authentication and validation
        chatbot.knowledge_base.extend(request.entries)
        
        # Recompute embeddings if model available
        if chatbot.model:
            chatbot.kb_embeddings = chatbot.precompute_embeddings()
        
        logger.info(f"Knowledge base updated with {len(request.entries)} new entries")
        
        return {
            "status": "success",
            "message": f"Added {len(request.entries)} entries to knowledge base",
            "total_entries": len(chatbot.knowledge_base)
        }
        
    except Exception as e:
        logger.error(f"Knowledge base update error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/knowledge-base")
async def get_knowledge_base():
    """Get chatbot knowledge base statistics"""
    return {
        "status": "success",
        "data": {
            "english_entries": len(chatbot.knowledge_base),
            "filipino_entries": len(chatbot.knowledge_base_filipino),
            "categories": list(set(item.get('category', 'general') for item in chatbot.knowledge_base)),
            "model_available": chatbot.model is not None,
            "active_sessions": len(chatbot.user_sessions)
        }
    }

@app.get("/api/sessions/{session_id}")
async def get_session(session_id: str):
    """Get chatbot session data"""
    if session_id in chatbot.user_sessions:
        session = chatbot.user_sessions[session_id]
        return {
            "status": "success",
            "data": {
                "session_id": session_id,
                "created_at": session.get('created_at'),
                "last_active": session.get('last_active'),
                "recent_queries": session.get('recent_queries', []),
                "recent_category": session.get('recent_category')
            }
        }
    else:
        raise HTTPException(status_code=404, detail="Session not found")

@app.delete("/api/sessions/{session_id}")
async def delete_session(session_id: str):
    """Delete chatbot session"""
    if session_id in chatbot.user_sessions:
        del chatbot.user_sessions[session_id]
        return {
            "status": "success",
            "message": "Session deleted"
        }
    else:
        raise HTTPException(status_code=404, detail="Session not found")

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "ai-chatbot",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat(),
        "model_loaded": chatbot.model is not None,
        "knowledge_base_entries": len(chatbot.knowledge_base) + len(chatbot.knowledge_base_filipino),
        "active_sessions": len(chatbot.user_sessions)
    }

@app.get("/api/languages")
async def get_supported_languages():
    """Get supported languages"""
    return {
        "status": "success",
        "languages": [
            {"code": "en", "name": "English", "native": "English"},
            {"code": "fil", "name": "Filipino", "native": "Filipino"}
        ],
        "default": "en"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5001)
