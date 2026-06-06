from fastapi import FastAPI, HTTPException, Request, Query, Body, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, Any, Optional
from db import supabase
import sys
import os
import requests
import traceback
import tempfile
from datetime import datetime
from pydantic import BaseModel


# Add parent directory to path for config import
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import Config class for Gemini API configuration
from config import Config
import google.generativeai as genai

# Ollama URL configuration (optional, for /ai/query endpoint)
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")

app = FastAPI()

@app.on_event("startup")
async def startup_event():
    print("=" * 50)
    print("BACKEND STARTUP LOG")
    print("=" * 50)
    print("✓ FastAPI app initialized")
    print(f"✓ Backend running on http://0.0.0.0:8000")
    if Config.GOOGLE_API_KEY:
        print("✓ Google API Key configured")
    else:
        print("✗ Google API Key NOT configured")
    if supabase:
        print("✓ Supabase connected")
    else:
        print("✗ Supabase NOT connected")
    print("=" * 50)
    print("IMPORTANT: Use http://localhost:8000 or http://127.0.0.1:8000 from client")
    print("NOT http://0.0.0.0:8000 (0.0.0.0 is bind address, not connectable)")
    print("=" * 50)

class HealthAssistantRequest(BaseModel):
    query: str
    user_id: Optional[str] = None
    model: Optional[str] = None
    history: Optional[list[dict]] = None


class SOSRequest(BaseModel):
    user_name: str
    contacts: list[str]

# Configure Gemini API on startup

if Config.validate_required():
    genai.configure(api_key=Config.GOOGLE_API_KEY)
    print(f"Gemini API configured successfully with model: {Config.GEMINI_MODEL}")
else:
    print("Warning: Google API key not configured. Health assistant will not work.")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    print(f"\n[REQUEST] {request.method} {request.url.path}")
    print(f"[REQUEST] Host: {request.headers.get('host', 'unknown')}")
    print(f"[REQUEST] Origin: {request.headers.get('origin', 'unknown')}")
    response = await call_next(request)
    print(f"[RESPONSE] {request.method} {request.url.path} → {response.status_code}")
    return response

_DEFAULT_METRICS: dict[str, str] = {
    "blood_pressure": "120/80",
    "blood_sugar": "95",
    "heart_rate": "72",
    "sleep_hours": "7",
    "steps": "10000",
    "body_temp": "98.6",
    "spo2": "98",
    "resp_rate": "16",
    "weight": "68",
    "bmi": "22.4",
}

ADHIRA_PROMPT = """You are Adhira, a warm motherly health companion.
Rules: Max 2 sentences. No diagnosis. No bullet points. Be caring but concise.
Priority: Always trust what the user says in conversation over stored health metrics. Metrics are background context only — if user reports a symptom, address that symptom directly."""


# GET endpoint - Get user metrics
@app.get("/health/metrics")
async def get_metrics(user_id: str = Query(..., description="The user's ID")):
    if not supabase:
        raise HTTPException(503, detail="Database not configured")
    
    try:
        response = supabase.table("health_metrics") \
                        .select("*") \
                        .eq("user_id", user_id) \
                        .execute()
        
        if response.data:
            row = response.data[0]
            data = {
                field: row.get(field, default)
                for field, default in _DEFAULT_METRICS.items()
            }
            data["updated_at"] = row.get("updated_at")
            return {"status": "ok", "data": data}
        
        # No row found — return defaults
        return {
            "status": "ok",
            "data": {
                **_DEFAULT_METRICS,
                "updated_at": None,
            }
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        raise HTTPException(500, detail=str(e))

# POST endpoint - Upsert user metrics
@app.post("/health/update")
async def update_metrics(request: Request):
    print("\n[METRICS] Update request received")
    if not supabase:
        print("[METRICS] ERROR: Supabase not configured")
        raise HTTPException(503, detail="Database not configured")

    try:
        body = await request.json()
        user_id = body.get("user_id")
        print(f"[METRICS] User: {user_id} | Body keys: {list(body.keys())}")
        
        if not user_id:
            raise HTTPException(400, detail="user_id is required")

        # Build record with all fields (only override non-null values)
        record = {"user_id": user_id}
        for field in _DEFAULT_METRICS:
            val = body.get(field)
            if val is not None:
                record[field] = val

        record["updated_at"] = datetime.utcnow().isoformat()

        # UPSERT — insert if user_id doesn't exist, otherwise update
        print(f"[METRICS] Upserting record for user {user_id}...")
        result = supabase.table("health_metrics") \
                        .upsert(record, on_conflict="user_id") \
                        .execute()
        print(f"[METRICS] Upsert successful")

        upserted = result.data[0] if result.data else record

        data = {
            field: upserted.get(field, _DEFAULT_METRICS[field])
            for field in _DEFAULT_METRICS
        }
        data["updated_at"] = upserted.get("updated_at")

        return {"status": "ok", "data": data}

    except Exception as e:
        print(f"Error: {str(e)}")
        raise HTTPException(500, detail=str(e))

# POST endpoint - Send prompt to remote Ollama model
@app.post("/ai/query")
async def ai_query(data: Dict[str, Any] = Body(...)):
    """
    Send prompt to remote Ollama model (running on another PC through ngrok)
    """
    try:
        prompt = data.get("prompt")
        model_name = data.get("model", "adhira")   # default model

        if not prompt:
            raise HTTPException(400, detail="Prompt is required")

        if not OLLAMA_URL:
            raise HTTPException(503, detail="Ollama URL not configured. Please set OLLAMA_URL environment variable.")

        response = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": model_name,
                "prompt": prompt
            },
            timeout=60
        )

        response.raise_for_status()

        return {
            "status": "success",
            "model": model_name,
            "response": response.json().get("response", "")
        }

    except HTTPException:
        raise
    except requests.exceptions.RequestException as e:
        print("Ollama Connection Error:", e)
        raise HTTPException(503, detail=f"Failed to connect to Ollama service: {str(e)}")
    except Exception as e:
        print("Ollama Error:", e)
        raise HTTPException(500, detail=f"Ollama error: {str(e)}")

# -----------------------------------------------
# HEALTH ASSISTANT ENDPOINT (WITH HEALTH CONTEXT)
# -----------------------------------------------

@app.post("/health/assistant")
async def health_assistant(request: Request):
    """
    Health assistant endpoint integrated with Gemini API.
    Fetches user health metrics and includes them in the prompt if user_id is provided.
    """
    try:
        print("\n[CHAT] Request received")
        # Validate API key is configured
        if not Config.GOOGLE_API_KEY:
            print("[CHAT] ERROR: Google API key not configured")
            raise HTTPException(503, detail="Google API key not configured. Please set GOOGLE_API_KEY in environment variables.")

        data = await request.json()
        query = data.get("query", "")
        user_id = data.get("user_id")
        model_name = data.get("model", Config.GEMINI_MODEL)
        history = data.get("history", [])
        medicine_names: list = data.get("medicine_names", [])

        print(f"[CHAT] Query: {query[:50]}... | User: {user_id} | Model: {model_name}")

        if not query:
            print("[CHAT] ERROR: Query is empty")
            raise HTTPException(400, detail="Query is required")

        if not query.strip():
            raise HTTPException(400, detail="Query cannot be empty")

        # Validate query length
        if len(query) > 4000:
            raise HTTPException(400, detail="Query is too long (max 4000 characters)")

        # -------------------------------------------------------
        # FETCH HEALTH METRICS IF USER_ID PROVIDED
        # -------------------------------------------------------
        context = ""
        if user_id:
            try:
                response = supabase.table("health_metrics") \
                    .select("blood_pressure,blood_sugar,heart_rate,sleep_hours,steps,spo2,bmi,body_temp") \
                    .eq("user_id", user_id) \
                    .order("updated_at", desc=True) \
                    .limit(1) \
                    .execute()

                if response.data:
                    metrics = response.data[0]
                    metric_parts = []
                    for k, v in metrics.items():
                        if v is not None:
                            metric_parts.append(f"{k}={v}")
                    if metric_parts:
                        context = "Health: " + ", ".join(metric_parts)
            except Exception as e:
                print(f"Warning: Could not fetch health metrics for user {user_id}: {e}")
                context = ""

        if medicine_names:
            med_context = "Current medications: " + ", ".join(medicine_names)
            context = (context + "\n" + med_context).strip() if context else med_context

        # -------------------------------------------------------
        # BUILD FINAL PROMPT
        # -------------------------------------------------------
        if history:
            # Take last 5 history items to avoid bloating the prompt
            history_items = history[-5:] if len(history) > 5 else history
            history_text = "\n".join([f"{h.get('role', 'user')}: {h.get('content', '')}" for h in history_items])
            full_prompt = ADHIRA_PROMPT + "\nPrior conversation:\n" + history_text + "\n" + context + "\nUser: " + query
        else:
            full_prompt = ADHIRA_PROMPT + "\n" + context + "\nUser: " + query

        # Initialize the Gemini model
        print("[CHAT] Initializing Gemini model...")
        model = genai.GenerativeModel(model_name)

        # Generate content with error handling
        try:
            print("[CHAT] Calling Gemini API...")
            response = model.generate_content(full_prompt)
            print("[CHAT] Gemini response received")

            # Extract response text
            if not response or not response.text:
                raise HTTPException(500, detail="Empty response from Gemini API")

            response_text = response.text.strip()

            if not response_text:
                raise HTTPException(500, detail="Empty response from Gemini API")

            return {
                "status": "success",
                "response": response_text,
                "model": model_name
            }

        except Exception as gemini_error:
            error_msg = str(gemini_error)
            print(f"Gemini API Error: {error_msg}")

            # Handle specific Gemini API errors
            if "API_KEY_INVALID" in error_msg or "API key" in error_msg.lower():
                raise HTTPException(401, detail="Invalid Google API key")
            elif "quota" in error_msg.lower() or "rate limit" in error_msg.lower():
                raise HTTPException(429, detail="API quota exceeded. Please try again later.")
            elif "safety" in error_msg.lower():
                raise HTTPException(400, detail="Content was blocked by safety filters. Please rephrase your query.")
            else:
                raise HTTPException(500, detail=f"Gemini API error: {error_msg}")

    except HTTPException:
        raise
    except Exception as e:
        print(f"Health Assistant Error: {str(e)}")
        raise HTTPException(500, detail=f"Health assistant error: {str(e)}")


# -----------------------------------------------
# MEDICAL DOCUMENT ANALYSIS ENDPOINT
# -----------------------------------------------

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
ALLOWED_TYPES = {
    "application/pdf",
    "image/jpeg", "image/jpg", "image/png",
    "image/webp", "image/heic", "image/heif",
}

DOC_ANALYSIS_PROMPT = """You are Adhira, a warm and knowledgeable health companion.
A user has shared a medical document. Analyze it conversationally — like a caring friend
explaining results in plain language. Be concise, warm, and clear.
Highlight any values that are out of normal range. Avoid scare tactics.
End with a brief, reassuring note or practical suggestion."""


@app.post("/health/analyze-document")
async def analyze_document(
    file: UploadFile = File(...),
    question: str = Form(default="Please explain this medical document."),
):
    """
    Analyze a medical document (image or PDF) using Gemini.
    - Images: sent directly to Gemini Vision.
    - PDFs: text extracted via PyMuPDF, then sent to Gemini.
    """
    if not Config.GOOGLE_API_KEY:
        raise HTTPException(503, detail="Google API key not configured.")

    # --- Validate content type ---
    content_type = (file.content_type or "").lower()
    if content_type not in ALLOWED_TYPES:
        raise HTTPException(
            400,
            detail=f"Unsupported file type '{content_type}'. Please upload a PDF or image (JPEG, PNG, WebP).",
        )

    # --- Read file bytes ---
    file_bytes = await file.read()
    if len(file_bytes) > MAX_FILE_SIZE:
        raise HTTPException(413, detail="File is too large. Maximum size is 10 MB.")
    if len(file_bytes) == 0:
        raise HTTPException(400, detail="Uploaded file is empty.")

    model = genai.GenerativeModel(Config.GEMINI_MODEL)
    full_prompt = f"{DOC_ANALYSIS_PROMPT}\n\nUser question: {question}"

    try:
        if content_type == "application/pdf":
            # --- PDF path: extract text with PyMuPDF ---
            try:
                import fitz  # PyMuPDF
            except ImportError:
                raise HTTPException(
                    503,
                    detail="PDF processing library not installed. Please install PyMuPDF.",
                )

            tmp_path = None
            try:
                with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
                    tmp.write(file_bytes)
                    tmp_path = tmp.name

                doc = fitz.open(tmp_path)
                extracted_text = "".join(page.get_text() for page in doc)
                doc.close()
            finally:
                if tmp_path and os.path.exists(tmp_path):
                    os.unlink(tmp_path)

            if not extracted_text.strip():
                raise HTTPException(
                    422,
                    detail="Could not extract text from this PDF. It may be a scanned image. Please try uploading a photo of the report instead.",
                )

            # Trim to avoid exceeding token limits
            trimmed = extracted_text[:12000]
            response = model.generate_content(
                f"{full_prompt}\n\nDocument content:\n{trimmed}"
            )

        else:
            # --- Image path: Gemini Vision ---
            import PIL.Image
            import io
            pil_image = PIL.Image.open(io.BytesIO(file_bytes))
            response = model.generate_content([full_prompt, pil_image])

        if not response or not response.text:
            raise HTTPException(500, detail="Gemini returned an empty response.")

        return {"status": "success", "response": response.text.strip()}

    except HTTPException:
        raise
    except Exception as e:
        err = str(e)
        print(f"[DOC_ANALYSIS] Error: {err}")
        if "quota" in err.lower() or "rate limit" in err.lower():
            raise HTTPException(
                429,
                detail="I'm a little busy right now — my AI quota is full. Please try again in a moment.",
            )
        if "safety" in err.lower():
            raise HTTPException(400, detail="The document was flagged by safety filters. Please try a different file.")
        raise HTTPException(500, detail=f"Document analysis failed: {err}")


@app.post("/sos/alert")
async def send_sos(request: SOSRequest):
    api_key = os.getenv("FAST2SMS_API_KEY")
    if not api_key:
        print(f"[SOS] {datetime.now().isoformat()} - FAILED: FAST2SMS_API_KEY not configured")
        raise HTTPException(
            status_code=503,
            detail="FAST2SMS_API_KEY is not configured on server",
        )

    user_name = (request.user_name or "").strip()
    if not user_name:
        user_name = "ADHIRA User"

    if not request.contacts:
        print(f"[SOS] {datetime.now().isoformat()} - FAILED: No contacts provided by {user_name}")
        raise HTTPException(status_code=400, detail="At least one contact is required")

    if len(request.contacts) > 5:
        print(f"[SOS] {datetime.now().isoformat()} - FAILED: Too many contacts ({len(request.contacts)}) by {user_name}")
        raise HTTPException(status_code=400, detail="Maximum 5 contacts allowed")

    cleaned_contacts = []
    for raw in request.contacts:
        phone = (raw or "").strip()
        if not phone.isdigit() or len(phone) != 10:
            print(f"[SOS] {datetime.now().isoformat()} - FAILED: Invalid phone '{raw}' by {user_name}")
            raise HTTPException(
                status_code=400,
                detail=f"Invalid phone number: {raw}. Must be exactly 10 digits.",
            )
        cleaned_contacts.append(phone)

    message = (
        f"SOS ALERT: {user_name} needs immediate help! "
        "This is an emergency alert from ADHIRA health assistant app. "
        "Please contact them immediately."
    )
    numbers = ",".join(cleaned_contacts)

    print(f"[SOS] {datetime.now().isoformat()} - REQUEST: user={user_name} contacts={cleaned_contacts}")

    try:
        print(f"[SOS] {datetime.now().isoformat()} - Calling Fast2SMS Quick SMS API... (numbers count={len(cleaned_contacts)})")
        response = requests.get(
            "https://www.fast2sms.com/dev/bulkV2",
            params={
                "authorization": api_key,
                "message": message,
                "language": "english",
                "route": "q",
                "numbers": numbers,
            },
            headers={"cache-control": "no-cache"},
            timeout=15,
        )
        print(f"[SOS] {datetime.now().isoformat()} - Fast2SMS HTTP status: {response.status_code}")
        print(f"[SOS] {datetime.now().isoformat()} - Fast2SMS raw response: {response.text}")
        result = response.json()
        print(f"[SOS] {datetime.now().isoformat()} - Fast2SMS JSON response: {result}")
    except requests.exceptions.Timeout:
        print(f"[SOS] {datetime.now().isoformat()} - FAILED: Fast2SMS timeout for {user_name}")
        raise HTTPException(status_code=504, detail="Fast2SMS request timed out")
    except requests.exceptions.RequestException as e:
        print(f"[SOS] {datetime.now().isoformat()} - FAILED: Fast2SMS request error: {str(e)}")
        raise HTTPException(status_code=502, detail=f"Fast2SMS request failed: {str(e)}")
    except ValueError as e:
        print(f"[SOS] {datetime.now().isoformat()} - FAILED: Fast2SMS invalid JSON response: {str(e)}")
        raise HTTPException(status_code=502, detail="Invalid response from Fast2SMS")

    if result.get("return") is True:
        print(f"[SOS] {datetime.now().isoformat()} - SUCCESS: SOS sent to {len(cleaned_contacts)} contact(s) for {user_name}")
        return {"status": "success", "message": "SOS sent"}

    fast2sms_status = result.get("status_code", result.get("return", "unknown"))
    fast2sms_msg = result.get("message", result)

    if isinstance(fast2sms_msg, list):
        fast2sms_msg = "; ".join(str(m) for m in fast2sms_msg)

    error_detail = str(fast2sms_msg)

    if fast2sms_status == 999:
        error_detail = (
            "Fast2SMS account not activated. You need to complete a transaction "
            f"of ₹100 or more before using the API. (API said: {error_detail})"
        )

    print(f"[SOS] {datetime.now().isoformat()} - FAILED: {error_detail} (full response: {result})")
    raise HTTPException(status_code=500, detail=f"SMS failed: {error_detail}")

# -----------------------------------------------
# FOOD-MEDICATION CONFLICT ENDPOINTS
# -----------------------------------------------

_FOOD_CATEGORIES = {
    "Citrus": ["Orange", "Lemon", "Lime", "Grapefruit", "Tangerine", "Citrus juices"],
    "Caffeine": ["Coffee", "Tea", "Cola", "Energy drinks", "Chocolate", "Cocoa", "Pre-workout"],
    "Dairy": ["Milk", "Cheese", "Yogurt", "Paneer", "Butter", "Ghee"],
    "Alcohol": ["Beer", "Wine", "Whiskey", "Vodka", "Rum"],
    "Leafy Greens": ["Spinach", "Kale", "Lettuce", "Broccoli", "Cabbage"],
    "High Fat": ["Burgers", "Pizza", "Fried chicken", "Samosa", "Chips"],
    "High Sugar": ["Chocolates", "Sweets", "Candy", "Cakes", "Pastries"],
    "Spicy": ["Chilli", "Hot sauces", "Spicy curries"],
    "High Sodium": ["Chips", "Papad", "Pickles", "Instant noodles"],
}

_MEDICATION_CONFLICTS = {
    "Paracetamol": {
        "conflicts": ["Alcohol", "Caffeine"],
        "message": "Avoid alcohol and excess caffeine due to liver and side-effect risk."
    },
    "Ibuprofen": {
        "conflicts": ["Alcohol", "Caffeine", "Spicy"],
        "message": "Can increase gastric irritation and bleeding risk."
    },
    "Amoxicillin": {
        "conflicts": ["Dairy", "Citrus", "Caffeine"],
        "message": "Can reduce absorption and affect effectiveness."
    },
    "Metformin": {
        "conflicts": ["Alcohol", "High Sugar"],
        "message": "Can worsen glucose control and increase risk profile."
    },
}

_MEDICATION_MAP = {
    "Paracetamol": "Paracetamol",
    "Ibuprofen": "Ibuprofen",
    "Aspirin": "Ibuprofen",
    "Amoxicillin": "Amoxicillin",
    "Azithromycin": "Amoxicillin",
    "Metformin": "Metformin",
    "Glucophage": "Metformin",
}


import asyncio
import functools


@app.post("/food/conflicts")
async def check_food_conflicts(request: Request):
    """
    Check for food-medication conflicts.

    Conflict computation is instant (in-memory). DB persistence runs
    in a background thread so the response returns immediately,
    even if the food_conflicts table doesn't exist yet in Supabase.

    Body:
      - user_id: str (required)
      - medicine_names: list[str]
      - selected_foods: list[str]

    Returns conflicts for the CURRENTLY selected foods only.
    When a food is deselected, it won't appear in selected_foods,
    so it won't show up in conflicts.
    """
    try:
        data = await request.json()
        user_id = data.get("user_id", "")
        medicine_names: list = data.get("medicine_names", [])
        selected_foods: list = data.get("selected_foods", [])

        if not user_id:
            raise HTTPException(400, detail="user_id is required")

        # --- INSTANT in-memory computation (no DB needed) ---
        conflicts = []

        for med_name in medicine_names:
            med_category = _MEDICATION_MAP.get(med_name)
            if not med_category:
                continue
            med_data = _MEDICATION_CONFLICTS.get(med_category)
            if not med_data:
                continue

            for food in selected_foods:
                for category_name, foods_list in _FOOD_CATEGORIES.items():
                    if food in foods_list and category_name in med_data["conflicts"]:
                        conflicts.append({
                            "medication": med_name,
                            "food": food,
                            "category": category_name,
                            "message": med_data["message"],
                        })

        # --- Fire-and-forget DB persistence in background thread ---
        # This prevents the table-not-found / connection timeout from
        # blocking the actual conflict result response.
        if supabase is not None:
            loop = asyncio.get_event_loop()
            loop.run_in_executor(
                None,
                functools.partial(
                    _persist_food_conflict,
                    user_id,
                    medicine_names,
                    selected_foods,
                    conflicts,
                ),
            )

        return {
            "status": "success",
            "conflicts": conflicts,
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Food Conflict Error: {str(e)}")
        raise HTTPException(500, detail=str(e))


def _persist_food_conflict(
    user_id: str,
    medicine_names: list,
    selected_foods: list,
    conflicts: list,
) -> None:
    """Synchronous helper to persist a conflict check in Supabase.
    Runs in a background thread so it never blocks the response."""
    if supabase is None:
        return
    try:
        supabase.table("food_conflicts").insert({
            "user_id": user_id,
            "medicine_names": medicine_names,
            "selected_foods": selected_foods,
            "conflicts": conflicts,
            "created_at": datetime.now().isoformat(),
        }).execute()
    except Exception as e:
        print(f"Warning: Could not persist food conflict check (table may not exist yet): {e}")


@app.get("/food/conflicts/history")
async def get_food_conflict_history(user_id: str = Query(..., description="The user's ID")):
    """Get the last 10 food conflict checks for a user."""
    if not supabase:
        raise HTTPException(503, detail="Database not configured")
    try:
        response = supabase.table("food_conflicts") \
            .select("id, medicine_names, selected_foods, conflicts, created_at") \
            .eq("user_id", user_id) \
            .order("created_at", desc=True) \
            .limit(10) \
            .execute()
        return {"status": "success", "history": response.data}
    except Exception as e:
        print(f"Food Conflict History Error: {str(e)}")
        raise HTTPException(500, detail=str(e))

# -----------------------------------------------
# HEALTH CHECK ENDPOINT - Backend Diagnostics
# -----------------------------------------------

@app.get("/health/check")
async def health_check():
    diagnostics = {
        "timestamp": datetime.now().isoformat(),
        "status": "healthy",
        "checks": {},
        "errors": []
    }
    
    diagnostics["checks"]["python_version"] = {
        "status": "ok",
        "version": sys.version
    }

    try:
        diagnostics["checks"]["fastapi"] = {
            "status": "ok",
            "version": "unknown"
        }
    except Exception as e:
        diagnostics["checks"]["fastapi"] = {
            "status": "error",
            "error": str(e)
        }
        diagnostics["errors"].append(f"FastAPI check failed: {str(e)}")

    try:
        if supabase:
            test_query = supabase.table("health_metrics").select("user_id").limit(1).execute()
            diagnostics["checks"]["supabase"] = {
                "status": "ok",
                "connection": "successful"
            }
        else:
            diagnostics["checks"]["supabase"] = {
                "status": "warning",
                "connection": "not configured"
            }
    except Exception as e:
        diagnostics["checks"]["supabase"] = {
            "status": "error",
            "error": str(e)
        }
        diagnostics["errors"].append(f"Supabase connection failed: {str(e)}")

    try:
        from config import Config
        if Config.validate_required():
            diagnostics["checks"]["google_api"] = {
                "status": "ok",
                "configured": True
            }
        else:
            diagnostics["checks"]["google_api"] = {
                "status": "error",
                "error": "Google API key not configured"
            }
            diagnostics["errors"].append("Google API key not configured")
    except Exception as e:
        diagnostics["checks"]["google_api"] = {
            "status": "error",
            "error": str(e)
        }
        diagnostics["errors"].append(f"Google API check failed: {str(e)}")

    # Environment variable check (support both naming conventions)
    env_vars_to_check = {
        "GOOGLE_API_KEY": ["GOOGLE_API_KEY"],
        "SUPABASE_URL": ["SUPABASE_URL", "SUPABASE_PROJECT_URL"],
        "SUPABASE_KEY": ["SUPABASE_KEY", "SUPABASE_API_KEY"]
    }
    missing_env = []
    for var_name, possible_vars in env_vars_to_check.items():
        found = False
        for var in possible_vars:
            if os.getenv(var):
                found = True
                break
        if not found:
            missing_env.append(var_name)

    if missing_env:
        diagnostics["checks"]["environment"] = {
            "status": "error",
            "missing_vars": missing_env
        }
        diagnostics["errors"].append(f"Missing environment variables: {', '.join(missing_env)}")
    else:
        diagnostics["checks"]["environment"] = {
            "status": "ok",
            "configured": True
        }

    if diagnostics["errors"]:
        diagnostics["status"] = "unhealthy"
    
    return diagnostics

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)