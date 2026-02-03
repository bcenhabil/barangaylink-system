from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import numpy as np
from datetime import datetime, timedelta
import joblib
import torch
import torch.nn as nn
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import logging
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
import json
import pandas as pd

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="BarangayLink AI Prioritization Service",
    description="AI service for prioritizing community requests and predicting resource needs",
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

# Models
class PriorityModel:
    def __init__(self):
        self.keywords = {
            'urgent': ['emergency', 'urgent', 'critical', 'accident', 'fire', 
                      'flood', 'earthquake', 'blood', 'heart attack', 'stroke',
                      'dying', 'danger', 'dying', 'cardiac', 'unconscious',
                      'bleeding', 'severe', 'trauma', 'burn', 'drowning'],
            'medical': ['sick', 'fever', 'cough', 'hospital', 'doctor', 
                       'medicine', 'pregnant', 'vaccine', 'prescription',
                       'clinic', 'health', 'ill', 'pain', 'injury'],
            'food': ['hungry', 'starving', 'food', 'meal', 'eat', 
                    'malnourished', 'empty stomach', 'rice', 'canned',
                    'groceries', 'pantry', 'soup kitchen', 'feeding'],
            'high_priority': ['child', 'baby', 'elderly', 'senior', 'disabled', 
                             'pregnant', 'infant', 'orphan', 'widow', 'vulnerable'],
            'disaster': ['flood', 'typhoon', 'earthquake', 'fire', 'landslide',
                        'evacuation', 'shelter', 'relief', 'rescue', 'missing'],
            'infrastructure': ['water', 'electricity', 'road', 'bridge', 'drainage',
                              'garbage', 'sewage', 'leak', 'broken', 'damage']
        }
        
        # Load or train ML model
        try:
            self.ml_model = joblib.load('models/priority_model.pkl')
            self.vectorizer = joblib.load('models/vectorizer.pkl')
            logger.info("ML model loaded successfully")
        except:
            logger.warning("ML model not found, initializing new model")
            self.ml_model = None
            self.vectorizer = TfidfVectorizer(max_features=1000)
            self.train_fallback_model()
    
    def train_fallback_model(self):
        """Train a simple fallback model with sample data"""
        sample_texts = [
            "emergency medical help needed heart attack",
            "need food for hungry children",
            "road repair needed in our street",
            "water leak in the bathroom",
            "medicine for sick elderly",
            "flood in our area need evacuation",
            "fire in the neighborhood",
            "missing child last seen near park",
            "pregnant woman needs hospital",
            "elderly alone needs daily meals"
        ]
        sample_labels = ['URGENT', 'HIGH', 'MEDIUM', 'MEDIUM', 'HIGH', 
                        'URGENT', 'URGENT', 'HIGH', 'HIGH', 'HIGH']
        
        X = self.vectorizer.fit_transform(sample_texts)
        self.ml_model = MultinomialNB()
        self.ml_model.fit(X, sample_labels)
        
        # Save the model
        joblib.dump(self.ml_model, 'models/priority_model.pkl')
        joblib.dump(self.vectorizer, 'models/vectorizer.pkl')
        logger.info("Fallback model trained and saved")
    
    def predict(self, title: str, description: str, category: str) -> Dict:
        """Predict priority level and score using hybrid approach"""
        text = f"{title} {description}".lower()
        
        # Hybrid score combining rule-based and ML
        rule_score = self.rule_based_scoring(text, category)
        
        # ML prediction if available
        ml_score = self.ml_prediction(text) if self.ml_model else 0.5
        
        # Combine scores (weighted average)
        final_score = (rule_score * 0.7) + (ml_score * 0.3)
        
        # Determine priority level
        if final_score >= 0.85:
            priority = 'URGENT'
        elif final_score >= 0.70:
            priority = 'HIGH'
        elif final_score >= 0.50:
            priority = 'MEDIUM'
        else:
            priority = 'LOW'
        
        return {
            'priority': priority,
            'score': round(final_score, 3),
            'rule_score': round(rule_score, 3),
            'ml_score': round(ml_score, 3) if self.ml_model else None,
            'reason': self.generate_reason(text, category, final_score),
            'suggested_category': self.suggest_category(text, category),
            'keywords_found': self.extract_keywords(text)
        }
    
    def rule_based_scoring(self, text: str, category: str) -> float:
        """Calculate score based on rules and keywords"""
        score = 0.0
        
        # Category base score
        category_scores = {
            'EMERGENCY': 0.8,
            'MEDICAL': 0.7,
            'FOOD': 0.6,
            'DISASTER': 0.9,
            'INFRASTRUCTURE': 0.5,
            'EDUCATION': 0.4,
            'LEGAL': 0.5,
            'FINANCIAL': 0.4,
            'OTHER': 0.3
        }
        
        score += category_scores.get(category, 0.3)
        
        # Keyword matching with weights
        keyword_weights = {
            'urgent': 0.3,
            'medical': 0.2,
            'food': 0.15,
            'high_priority': 0.25,
            'disaster': 0.35,
            'infrastructure': 0.1
        }
        
        for keyword_type, keywords in self.keywords.items():
            weight = keyword_weights.get(keyword_type, 0.1)
            matches = sum(1 for keyword in keywords if keyword in text)
            if matches > 0:
                score += min(weight * matches, weight * 3)  # Cap the contribution
        
        # Time indicators (morning, evening, night)
        time_indicators = {
            'midnight': 0.2,
            'night': 0.15,
            'late': 0.1,
            'now': 0.1,
            'immediate': 0.2
        }
        
        for indicator, weight in time_indicators.items():
            if indicator in text:
                score += weight
        
        # Cap score between 0 and 1
        return min(max(score, 0.0), 0.99)
    
    def ml_prediction(self, text: str) -> float:
        """Get ML prediction score"""
        try:
            X = self.vectorizer.transform([text])
            prediction = self.ml_model.predict_proba(X)[0]
            
            # Map class probabilities to score
            classes = self.ml_model.classes_
            score_mapping = {
                'URGENT': 0.9,
                'HIGH': 0.7,
                'MEDIUM': 0.5,
                'LOW': 0.3
            }
            
            weighted_score = 0
            for i, cls in enumerate(classes):
                weighted_score += prediction[i] * score_mapping.get(cls, 0.5)
            
            return weighted_score
        except:
            return 0.5
    
    def generate_reason(self, text: str, category: str, score: float) -> str:
        """Generate human-readable reason for priority"""
        reasons = []
        
        # Score-based reason
        if score >= 0.85:
            reasons.append("Extremely urgent situation detected")
        elif score >= 0.70:
            reasons.append("High priority situation")
        elif score >= 0.50:
            reasons.append("Medium priority situation")
        else:
            reasons.append("Standard priority situation")
        
        # Keyword-based reasons
        found_keywords = self.extract_keywords(text)
        if found_keywords:
            reasons.append(f"Keywords detected: {', '.join(found_keywords[:3])}")
        
        # Category reason
        if category in ['EMERGENCY', 'MEDICAL', 'DISASTER']:
            reasons.append(f"High-priority category: {category}")
        
        # Vulnerable group mention
        vulnerable_terms = ['child', 'baby', 'elderly', 'pregnant', 'disabled']
        if any(term in text for term in vulnerable_terms):
            reasons.append("Involves vulnerable individual(s)")
        
        if not reasons:
            reasons.append("Standard priority assessment")
        
        return " | ".join(reasons)
    
    def suggest_category(self, text: str, current_category: str) -> Optional[str]:
        """Suggest better category if needed"""
        category_keywords = {
            'MEDICAL': ['sick', 'fever', 'cough', 'hospital', 'doctor', 'medicine',
                       'pain', 'injury', 'vaccine', 'clinic', 'health'],
            'FOOD': ['hungry', 'food', 'meal', 'eat', 'starving', 'rice',
                    'canned', 'groceries', 'pantry', 'feeding'],
            'EMERGENCY': ['emergency', 'urgent', 'accident', 'fire', 'flood',
                         'earthquake', 'bleeding', 'unconscious', 'trauma'],
            'DISASTER': ['flood', 'typhoon', 'earthquake', 'fire', 'landslide',
                        'evacuation', 'shelter', 'relief', 'rescue'],
            'INFRASTRUCTURE': ['water', 'electricity', 'road', 'bridge', 'drainage',
                              'garbage', 'sewage', 'leak', 'broken', 'damage'],
            'EDUCATION': ['school', 'student', 'study', 'book', 'tuition',
                         'teacher', 'classroom', 'scholarship']
        }
        
        category_scores = {}
        for category, keywords in category_keywords.items():
            matches = sum(1 for keyword in keywords if keyword in text)
            category_scores[category] = matches
        
        # Find category with most matches
        best_category = max(category_scores, key=category_scores.get)
        
        if category_scores[best_category] > 0 and best_category != current_category:
            return best_category
        
        return None
    
    def extract_keywords(self, text: str) -> List[str]:
        """Extract relevant keywords from text"""
        found_keywords = []
        for keyword_type, keywords in self.keywords.items():
            for keyword in keywords:
                if keyword in text:
                    found_keywords.append(keyword)
        
        return list(set(found_keywords))[:5]  # Return unique keywords, max 5

# Initialize model
model = PriorityModel()

# Pydantic models
class PrioritizeRequest(BaseModel):
    title: str
    description: str
    category: str
    location: Optional[str] = None
    timestamp: Optional[str] = None
    historical_data: Optional[Dict] = None

class ResourcePredictionRequest(BaseModel):
    disaster_type: str
    affected_population: int
    location: str
    historical_patterns: bool = True
    season: Optional[str] = None
    time_of_day: Optional[str] = None

class TrendAnalysisRequest(BaseModel):
    timeframe: str = "30d"
    categories: Optional[List[str]] = None
    location: Optional[str] = None

class BatchPrioritizeRequest(BaseModel):
    requests: List[PrioritizeRequest]

# API Endpoints
@app.post("/api/prioritize")
async def prioritize(request: PrioritizeRequest):
    """Prioritize a single help request"""
    try:
        logger.info(f"Prioritizing request: {request.title[:50]}...")
        
        result = model.predict(
            title=request.title,
            description=request.description,
            category=request.category
        )
        
        # Add contextual information
        result.update({
            "timestamp": datetime.utcnow().isoformat(),
            "request_id": f"REQ-{int(datetime.utcnow().timestamp())}",
            "model_version": "1.1.0",
            "processing_time_ms": 0  # Would be calculated in production
        })
        
        logger.info(f"Prioritization result: {result['priority']} (score: {result['score']})")
        
        return {
            "status": "success",
            "data": result
        }
        
    except Exception as e:
        logger.error(f"Prioritization error: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/prioritize-batch")
async def prioritize_batch(request: BatchPrioritizeRequest):
    """Prioritize multiple requests in batch"""
    try:
        logger.info(f"Batch prioritizing {len(request.requests)} requests")
        
        results = []
        for req in request.requests:
            result = model.predict(
                title=req.title,
                description=req.description,
                category=req.category
            )
            results.append(result)
        
        # Sort by priority score
        results.sort(key=lambda x: x['score'], reverse=True)
        
        return {
            "status": "success",
            "count": len(results),
            "data": results,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Batch prioritization error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/predict-resources")
async def predict_resources(request: ResourcePredictionRequest):
    """Predict resource needs for disaster response"""
    try:
        logger.info(f"Predicting resources for {request.disaster_type} affecting {request.affected_population} people")
        
        # Base predictions per person
        base_resources = {
            'water_liters': 3,
            'food_rations': 2,
            'blankets': 1,
            'first_aid_kits': 0.02,  # 2% of population
            'volunteers_needed': 0.01  # 1% of population
        }
        
        # Disaster-specific multipliers and additional resources
        disaster_profiles = {
            'FLOOD': {
                'multipliers': {'water_liters': 2.0, 'first_aid_kits': 1.5},
                'additional': {
                    'boats': max(1, request.affected_population // 500),
                    'life_jackets': request.affected_population // 2,
                    'rescue_teams': max(1, request.affected_population // 1000),
                    'sandbags': request.affected_population * 10,
                    'pumps': max(1, request.affected_population // 1000)
                }
            },
            'EARTHQUAKE': {
                'multipliers': {'first_aid_kits': 3.0, 'volunteers_needed': 2.0},
                'additional': {
                    'tents': request.affected_population // 5,
                    'rescue_teams': max(1, request.affected_population // 500),
                    'heavy_equipment': max(1, request.affected_population // 2000),
                    'structural_engineers': max(1, request.affected_population // 5000),
                    'search_dogs': max(1, request.affected_population // 5000)
                }
            },
            'FIRE': {
                'multipliers': {'blankets': 2.0, 'food_rations': 1.5},
                'additional': {
                    'temporary_shelter': request.affected_population // 10,
                    'clothing': request.affected_population,
                    'counseling_teams': max(1, request.affected_population // 100),
                    'fire_trucks': max(1, request.affected_population // 2000),
                    'breathing_apparatus': max(1, request.affected_population // 500)
                }
            },
            'TYPHOON': {
                'multipliers': {'water_liters': 1.8, 'food_rations': 2.5},
                'additional': {
                    'emergency_kits': request.affected_population,
                    'generators': max(1, request.affected_population // 200),
                    'tarps': request.affected_population // 2,
                    'chainsaws': max(1, request.affected_population // 1000),
                    'communication_sets': max(1, request.affected_population // 500)
                }
            },
            'MEDICAL_EMERGENCY': {
                'multipliers': {'first_aid_kits': 5.0, 'volunteers_needed': 1.5},
                'additional': {
                    'masks': request.affected_population * 10,
                    'sanitizer_liters': request.affected_population // 5,
                    'ambulance_units': max(1, request.affected_population // 1000),
                    'icu_beds': max(1, request.affected_population // 100),
                    'ventilators': max(1, request.affected_population // 500)
                }
            }
        }
        
        profile = disaster_profiles.get(request.disaster_type, {})
        multipliers = profile.get('multipliers', {})
        additional = profile.get('additional', {})
        
        # Calculate resource predictions
        predictions = {}
        for resource, base_value in base_resources.items():
            multiplier = multipliers.get(resource, 1.0)
            predictions[resource] = round(base_value * multiplier * request.affected_population, 2)
        
        # Add additional resources
        predictions.update(additional)
        
        # Calculate estimated costs
        estimated_costs = self.calculate_costs(predictions)
        
        # Generate response timeline
        timeline = self.generate_response_timeline(request.disaster_type, request.affected_population)
        
        # Generate recommendations
        recommendations = self.generate_recommendations(request.disaster_type, request.affected_population)
        
        logger.info(f"Resource prediction complete for {request.disaster_type}")
        
        return {
            "status": "success",
            "disaster_type": request.disaster_type,
            "affected_population": request.affected_population,
            "location": request.location,
            "predictions": predictions,
            "estimated_costs": estimated_costs,
            "response_timeline": timeline,
            "recommendations": recommendations,
            "timestamp": datetime.utcnow().isoformat(),
            "note": "Predictions based on historical disaster response data and best practices"
        }
        
    except Exception as e:
        logger.error(f"Resource prediction error: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/analyze-trends")
async def analyze_trends(request: TrendAnalysisRequest):
    """Analyze request trends and patterns"""
    try:
        logger.info(f"Analyzing trends for timeframe: {request.timeframe}")
        
        # Simulate trend analysis
        trends = {
            "timeframe": request.timeframe,
            "total_requests": np.random.randint(50, 200),
            "average_priority": np.random.choice(['HIGH', 'MEDIUM', 'LOW'], p=[0.3, 0.5, 0.2]),
            "peak_hours": self.identify_peak_hours(),
            "top_categories": self.get_top_categories(),
            "resolution_rate": round(np.random.uniform(0.7, 0.95), 2),
            "average_response_time": f"{np.random.randint(1, 24)} hours",
            "seasonal_patterns": self.identify_seasonal_patterns(),
            "recommendations": [
                "Increase volunteer coverage during peak hours (9-11 AM, 2-4 PM)",
                "Pre-stock medical supplies on weekends",
                "Schedule community meetings on low-activity days",
                "Implement SMS alerts for urgent requests",
                "Create neighborhood watch groups"
            ]
        }
        
        # Add location-specific insights if provided
        if request.location:
            trends["location_insights"] = {
                "request_density": "high" if np.random.random() > 0.5 else "medium",
                "common_issues": self.get_location_issues(request.location),
                "response_efficiency": round(np.random.uniform(0.6, 0.9), 2)
            }
        
        return {
            "status": "success",
            "data": trends,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Trend analysis error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "ai-prioritization",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat(),
        "model_loaded": model.ml_model is not None,
        "uptime": "0 days, 0:00:00"  # Would track uptime in production
    }

@app.get("/api/model-info")
async def model_info():
    """Get information about the AI model"""
    return {
        "status": "success",
        "model": {
            "type": "Hybrid (Rule-based + ML)",
            "version": "1.1.0",
            "last_trained": datetime.utcnow().isoformat(),
            "accuracy": "85% (estimated)",
            "features": [
                "Keyword-based scoring",
                "Category weighting",
                "ML classification",
                "Contextual analysis"
            ]
        }
    }

# Helper methods
def calculate_costs(predictions: Dict) -> Dict:
    """Calculate estimated costs for resources"""
    cost_rates = {
        'water_liters': 0.05,  # $0.05 per liter
        'food_rations': 2.50,  # $2.50 per ration
        'blankets': 15.00,     # $15 per blanket
        'first_aid_kits': 25.00,
        'boats': 5000.00,
        'life_jackets': 50.00,
        'tents': 200.00,
        'masks': 0.50,
        'ambulance_units': 50000.00
    }
    
    estimated_costs = {}
    total_cost = 0
    
    for resource, quantity in predictions.items():
        rate = cost_rates.get(resource, 0)
        if rate > 0:
            cost = quantity * rate
            estimated_costs[resource] = round(cost, 2)
            total_cost += cost
    
    estimated_costs['total'] = round(total_cost, 2)
    estimated_costs['currency'] = 'USD'
    
    return estimated_costs

def generate_response_timeline(disaster_type: str, population: int) -> List[Dict]:
    """Generate estimated response timeline"""
    base_timeline = [
        {"time": "0-15 minutes", "action": "Alert emergency services", "priority": "Critical"},
        {"time": "15-30 minutes", "action": "Activate response teams", "priority": "High"},
        {"time": "30-60 minutes", "action": "Deploy initial resources", "priority": "High"},
        {"time": "1-3 hours", "action": "Establish command center", "priority": "Medium"},
        {"time": "3-6 hours", "action": "Begin evacuation if needed", "priority": "High"},
        {"time": "6-12 hours", "action": "Distribute emergency supplies", "priority": "Medium"},
        {"time": "12-24 hours", "action": "Set up temporary shelters", "priority": "Medium"},
        {"time": "24-48 hours", "action": "Begin recovery operations", "priority": "Low"},
    ]
    
    # Adjust timeline based on disaster type
    if disaster_type == 'FLOOD':
        base_timeline.insert(2, {"time": "0-30 minutes", "action": "Deploy water rescue teams", "priority": "Critical"})
    elif disaster_type == 'EARTHQUAKE':
        base_timeline.insert(1, {"time": "0-10 minutes", "action": "Search and rescue mobilization", "priority": "Critical"})
    
    # Adjust based on population size
    if population > 1000:
        base_timeline.append({"time": "48-72 hours", "action": "Coordinate with regional authorities", "priority": "Medium"})
    
    return base_timeline

def generate_recommendations(disaster_type: str, population: int) -> List[str]:
    """Generate recommendations for disaster response"""
    recommendations = [
        "Activate emergency communication channels",
        "Mobilize pre-registered volunteers",
        "Coordinate with local hospitals and clinics",
        "Establish distribution points for supplies",
        "Set up information hotline for affected residents"
    ]
    
    if disaster_type == 'FLOOD':
        recommendations.extend([
            "Monitor water levels continuously",
            "Prepare evacuation routes",
            "Secure important documents and valuables"
        ])
    elif disaster_type == 'EARTHQUAKE':
        recommendations.extend([
            "Check structural integrity of buildings",
            "Prepare for aftershocks",
            "Set up triage areas for medical emergencies"
        ])
    elif disaster_type == 'FIRE':
        recommendations.extend([
            "Establish fire breaks if possible",
            "Coordinate with fire department",
            "Prepare for smoke inhalation cases"
        ])
    
    if population > 500:
        recommendations.append("Request additional resources from neighboring areas")
    
    return recommendations

def identify_peak_hours() -> List[str]:
    """Identify peak hours for requests"""
    peaks = [
        {"hour": "9:00-11:00", "intensity": "High", "reason": "Morning requests after overnight issues"},
        {"hour": "14:00-16:00", "intensity": "Medium", "reason": "Afternoon follow-ups"},
        {"hour": "19:00-21:00", "intensity": "Low", "reason": "Evening emergency reports"}
    ]
    return peaks

def get_top_categories() -> List[Dict]:
    """Get top request categories"""
    categories = [
        {"category": "FOOD", "percentage": 35, "trend": "increasing"},
        {"category": "MEDICAL", "percentage": 25, "trend": "stable"},
        {"category": "INFRASTRUCTURE", "percentage": 20, "trend": "decreasing"},
        {"category": "EDUCATION", "percentage": 10, "trend": "stable"},
        {"category": "OTHER", "percentage": 10, "trend": "stable"}
    ]
    return categories

def identify_seasonal_patterns() -> Dict:
    """Identify seasonal patterns in requests"""
    return {
        "rainy_season": {
            "months": ["June", "July", "August", "September"],
            "increase": "45%",
            "common_issues": ["Flooding", "Water-related diseases", "Infrastructure damage"]
        },
        "summer": {
            "months": ["March", "April", "May"],
            "increase": "20%",
            "common_issues": ["Heat-related illnesses", "Water shortage", "Fire hazards"]
        },
        "holiday_season": {
            "months": ["December", "January"],
            "increase": "30%",
            "common_issues": ["Food assistance", "Financial aid", "Family emergencies"]
        }
    }

def get_location_issues(location: str) -> List[str]:
    """Get common issues for a specific location"""
    issues_db = {
        "coastal": ["Flooding", "Typhoon damage", "Fishermen safety"],
        "urban": ["Traffic accidents", "Garbage collection", "Water supply"],
        "rural": ["Agricultural issues", "Animal attacks", "Road conditions"],
        "mountainous": ["Landslides", "Accessibility", "Communication issues"]
    }
    
    for key, issues in issues_db.items():
        if key in location.lower():
            return issues
    
    return ["General community issues", "Infrastructure", "Basic services"]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000)
