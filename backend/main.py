"""
365 Weapons Admin Backend
LanceDB Vector Search + AI Services API

- OpenAI: Embeddings, TTS, Whisper (speech)
- OpenRouter: Chat completions, AI assistants
"""

import os
import json
import uuid
import base64
import tempfile
from datetime import datetime
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Header, Depends, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import lancedb
import numpy as np
import httpx
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

# ============================================================================
# Configuration
# ============================================================================

# OpenAI - for embeddings, TTS, and Whisper
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
EMBEDDING_MODEL = "text-embedding-3-small"
EMBEDDING_DIMENSION = 1536

# OpenRouter - for chat and AI completions
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
DEFAULT_CHAT_MODEL = "anthropic/claude-3.5-sonnet"  # or "openai/gpt-4-turbo"

# Auth
AUTH_TOKEN = os.getenv("API_AUTH_TOKEN", "your-secret-token")

# ============================================================================
# Database Setup
# ============================================================================

db = None
openai_client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize connections on startup."""
    global db, openai_client

    # Initialize LanceDB
    db_path = os.getenv("LANCEDB_PATH", "./lancedb_data")
    db = lancedb.connect(db_path)

    # Initialize OpenAI client for embeddings/TTS/Whisper
    if OPENAI_API_KEY:
        openai_client = OpenAI(api_key=OPENAI_API_KEY)

    print(f"LanceDB initialized at {db_path}")
    print(f"OpenAI configured: {bool(OPENAI_API_KEY)}")
    print(f"OpenRouter configured: {bool(OPENROUTER_API_KEY)}")
    yield

    print("Shutting down...")

# ============================================================================
# FastAPI App
# ============================================================================

app = FastAPI(
    title="365 Weapons Admin API",
    description="LanceDB Vector Search, OpenRouter AI, OpenAI TTS/Whisper",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# Authentication
# ============================================================================

async def verify_token(authorization: str = Header(None)):
    """Verify the Bearer token."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing authorization header")

    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization format")

    token = authorization.replace("Bearer ", "")
    if token != AUTH_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid token")

    return token

# ============================================================================
# Pydantic Models
# ============================================================================

class SearchRequest(BaseModel):
    query: str
    table: str = "products_embeddings"
    limit: int = 10
    filter: Optional[Dict[str, Any]] = None

class HybridSearchRequest(BaseModel):
    query: str
    table: str = "products_embeddings"
    limit: int = 10
    alpha: float = 0.5
    filter: Optional[Dict[str, Any]] = None

class InsertRequest(BaseModel):
    table: str
    documents: List[Dict[str, Any]]

class DeleteRequest(BaseModel):
    table: str
    ids: List[str]

class CreateTableRequest(BaseModel):
    table: str
    schema_fields: Dict[str, str]

# OpenRouter Chat Models
class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    model: str = DEFAULT_CHAT_MODEL
    max_tokens: int = 1000
    temperature: float = 0.7
    stream: bool = False

class AgentRequest(BaseModel):
    agent_type: str  # "admin_assistant", "order_processor", "analytics"
    message: str
    context: Optional[Dict[str, Any]] = None
    model: str = DEFAULT_CHAT_MODEL

# OpenAI TTS/Whisper Models
class TTSRequest(BaseModel):
    text: str
    voice: str = "alloy"  # alloy, echo, fable, onyx, nova, shimmer
    model: str = "tts-1"  # tts-1 or tts-1-hd
    speed: float = 1.0
    response_format: str = "mp3"  # mp3, opus, aac, flac

class TranscriptionResponse(BaseModel):
    text: str
    language: Optional[str] = None
    duration: Optional[float] = None

# ============================================================================
# Helper Functions
# ============================================================================

def get_embedding(text: str) -> List[float]:
    """Generate embedding using OpenAI."""
    if not openai_client:
        raise HTTPException(status_code=500, detail="OpenAI client not configured")

    response = openai_client.embeddings.create(
        model=EMBEDDING_MODEL,
        input=text
    )
    return response.data[0].embedding

def ensure_table_exists(table_name: str):
    """Ensure the table exists, create if not."""
    if table_name not in db.table_names():
        db.create_table(table_name, data=[{
            "id": "placeholder",
            "text": "placeholder",
            "vector": [0.0] * EMBEDDING_DIMENSION,
            "metadata": "{}"
        }])
        table = db.open_table(table_name)
        table.delete('id = "placeholder"')

async def call_openrouter(
    messages: List[Dict[str, str]],
    model: str = DEFAULT_CHAT_MODEL,
    max_tokens: int = 1000,
    temperature: float = 0.7
) -> str:
    """Call OpenRouter API for chat completions."""
    if not OPENROUTER_API_KEY:
        raise HTTPException(status_code=500, detail="OpenRouter API key not configured")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{OPENROUTER_BASE_URL}/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://365weapons.com",
                "X-Title": "365 Weapons Admin"
            },
            json={
                "model": model,
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": temperature
            },
            timeout=60.0
        )

        if response.status_code != 200:
            error_detail = response.text
            raise HTTPException(status_code=response.status_code, detail=f"OpenRouter error: {error_detail}")

        result = response.json()
        return result["choices"][0]["message"]["content"]

# ============================================================================
# LanceDB Endpoints
# ============================================================================

@app.get("/lancedb")
async def lancedb_health():
    """Health check for LanceDB service."""
    return {
        "status": "healthy",
        "service": "lancedb",
        "tables": db.table_names() if db else []
    }

@app.post("/lancedb/search")
async def vector_search(
    request: SearchRequest,
    token: str = Depends(verify_token)
):
    """Perform vector similarity search."""
    try:
        ensure_table_exists(request.table)
        table = db.open_table(request.table)

        query_embedding = get_embedding(request.query)
        results = table.search(query_embedding).limit(request.limit).to_pandas()

        items = results.to_dict(orient='records')
        for item in items:
            if 'metadata' in item and isinstance(item['metadata'], str):
                try:
                    item['metadata'] = json.loads(item['metadata'])
                except:
                    pass
            if 'vector' in item:
                del item['vector']

        return {
            "status": "success",
            "results": items,
            "query": request.query,
            "count": len(items)
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/lancedb/hybrid-search")
async def hybrid_search(
    request: HybridSearchRequest,
    token: str = Depends(verify_token)
):
    """Perform hybrid vector + keyword search."""
    try:
        ensure_table_exists(request.table)
        table = db.open_table(request.table)

        query_embedding = get_embedding(request.query)
        vector_results = table.search(query_embedding).limit(request.limit * 2).to_pandas()

        try:
            keyword_results = table.search(request.query, query_type="fts").limit(request.limit * 2).to_pandas()
        except:
            keyword_results = vector_results.head(0)  # Empty if FTS not available

        combined = {}
        for idx, row in vector_results.iterrows():
            doc_id = row.get('id', str(idx))
            score = 1.0 / (idx + 1)
            combined[doc_id] = {
                'data': row.to_dict(),
                'vector_score': score * (1 - request.alpha),
                'keyword_score': 0
            }

        for idx, row in keyword_results.iterrows():
            doc_id = row.get('id', str(idx))
            score = 1.0 / (idx + 1)
            if doc_id in combined:
                combined[doc_id]['keyword_score'] = score * request.alpha
            else:
                combined[doc_id] = {
                    'data': row.to_dict(),
                    'vector_score': 0,
                    'keyword_score': score * request.alpha
                }

        ranked = sorted(
            combined.items(),
            key=lambda x: x[1]['vector_score'] + x[1]['keyword_score'],
            reverse=True
        )[:request.limit]

        results = []
        for doc_id, scores in ranked:
            item = scores['data']
            if 'vector' in item:
                del item['vector']
            if 'metadata' in item and isinstance(item['metadata'], str):
                try:
                    item['metadata'] = json.loads(item['metadata'])
                except:
                    pass
            item['_score'] = scores['vector_score'] + scores['keyword_score']
            results.append(item)

        return {
            "status": "success",
            "results": results,
            "query": request.query,
            "count": len(results)
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/lancedb/insert")
async def insert_documents(
    request: InsertRequest,
    token: str = Depends(verify_token)
):
    """Insert documents with auto-generated embeddings."""
    try:
        ensure_table_exists(request.table)
        table = db.open_table(request.table)

        records = []
        for doc in request.documents:
            text = doc.get('text', doc.get('content', doc.get('description', '')))
            if not text:
                text = json.dumps(doc)

            embedding = get_embedding(text)

            record = {
                'id': doc.get('id', str(uuid.uuid4())),
                'text': text,
                'vector': embedding,
                'metadata': json.dumps({k: v for k, v in doc.items() if k not in ['id', 'text', 'vector']})
            }
            records.append(record)

        table.add(records)

        return {
            "status": "success",
            "inserted": len(records),
            "table": request.table
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/lancedb/delete")
async def delete_documents(
    request: DeleteRequest,
    token: str = Depends(verify_token)
):
    """Delete documents by ID."""
    try:
        if request.table not in db.table_names():
            raise HTTPException(status_code=404, detail=f"Table {request.table} not found")

        table = db.open_table(request.table)
        for doc_id in request.ids:
            table.delete(f'id = "{doc_id}"')

        return {
            "status": "success",
            "deleted": len(request.ids),
            "table": request.table
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/lancedb/tables")
async def create_table(
    request: CreateTableRequest,
    token: str = Depends(verify_token)
):
    """Create a new table."""
    try:
        if request.table in db.table_names():
            return {
                "status": "exists",
                "table": request.table,
                "message": "Table already exists"
            }

        db.create_table(request.table, data=[{
            "id": "placeholder",
            "text": "placeholder",
            "vector": [0.0] * EMBEDDING_DIMENSION,
            "metadata": "{}"
        }])

        table = db.open_table(request.table)
        table.delete('id = "placeholder"')

        return {
            "status": "success",
            "table": request.table,
            "message": "Table created"
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/lancedb/tables")
async def list_tables(token: str = Depends(verify_token)):
    """List all tables."""
    return {
        "status": "success",
        "tables": db.table_names() if db else []
    }

# ============================================================================
# OpenRouter Chat Endpoints
# ============================================================================

@app.get("/openrouter")
async def openrouter_health():
    """Health check for OpenRouter service."""
    return {
        "status": "healthy" if OPENROUTER_API_KEY else "not_configured",
        "service": "openrouter",
        "default_model": DEFAULT_CHAT_MODEL
    }

@app.post("/openrouter/chat")
async def chat_completion(
    request: ChatRequest,
    token: str = Depends(verify_token)
):
    """Chat completion via OpenRouter."""
    try:
        messages = [{"role": m.role, "content": m.content} for m in request.messages]

        response = await call_openrouter(
            messages=messages,
            model=request.model,
            max_tokens=request.max_tokens,
            temperature=request.temperature
        )

        return {
            "status": "success",
            "model": request.model,
            "response": response
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/openrouter/agent")
async def run_agent(
    request: AgentRequest,
    token: str = Depends(verify_token)
):
    """Run an AI agent via OpenRouter."""
    try:
        # Build system prompt based on agent type
        system_prompts = {
            "admin_assistant": """You are an AI assistant for the 365 Weapons admin dashboard.
You help administrators manage orders, products, partners, and business operations.
Be concise, professional, and helpful. Provide actionable insights when possible.""",

            "order_processor": """You are an order processing assistant for 365 Weapons.
Help analyze orders, suggest status updates, identify issues, and provide shipping recommendations.
Focus on efficiency and accuracy.""",

            "analytics": """You are a business analytics assistant for 365 Weapons.
Analyze sales data, identify trends, provide insights on revenue, popular products, and partner performance.
Present data clearly and suggest actionable improvements.""",

            "products": """You are a product management assistant for 365 Weapons.
Help with product descriptions, pricing suggestions, inventory management, and category organization.
Understand firearm services like porting, optic cuts, and slide work."""
        }

        system_prompt = system_prompts.get(
            request.agent_type,
            "You are a helpful assistant for the 365 Weapons admin dashboard."
        )

        # Add context to system prompt if provided
        if request.context:
            context_str = json.dumps(request.context, indent=2)
            system_prompt += f"\n\nCurrent context:\n{context_str}"

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": request.message}
        ]

        response = await call_openrouter(
            messages=messages,
            model=request.model,
            max_tokens=1500,
            temperature=0.7
        )

        return {
            "status": "success",
            "agent_type": request.agent_type,
            "model": request.model,
            "response": response
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# OpenAI TTS Endpoints
# ============================================================================

@app.get("/openai/tts")
async def tts_health():
    """Health check for TTS service."""
    return {
        "status": "healthy" if OPENAI_API_KEY else "not_configured",
        "service": "openai_tts",
        "voices": ["alloy", "echo", "fable", "onyx", "nova", "shimmer"],
        "models": ["tts-1", "tts-1-hd"]
    }

@app.post("/openai/tts")
async def text_to_speech(
    request: TTSRequest,
    token: str = Depends(verify_token)
):
    """Convert text to speech using OpenAI TTS."""
    if not openai_client:
        raise HTTPException(status_code=500, detail="OpenAI client not configured")

    try:
        response = openai_client.audio.speech.create(
            model=request.model,
            voice=request.voice,
            input=request.text,
            speed=request.speed,
            response_format=request.response_format
        )

        # Return audio as streaming response
        content_types = {
            "mp3": "audio/mpeg",
            "opus": "audio/opus",
            "aac": "audio/aac",
            "flac": "audio/flac"
        }

        return StreamingResponse(
            response.iter_bytes(),
            media_type=content_types.get(request.response_format, "audio/mpeg"),
            headers={
                "Content-Disposition": f"attachment; filename=speech.{request.response_format}"
            }
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/openai/tts/base64")
async def text_to_speech_base64(
    request: TTSRequest,
    token: str = Depends(verify_token)
):
    """Convert text to speech and return as base64."""
    if not openai_client:
        raise HTTPException(status_code=500, detail="OpenAI client not configured")

    try:
        response = openai_client.audio.speech.create(
            model=request.model,
            voice=request.voice,
            input=request.text,
            speed=request.speed,
            response_format=request.response_format
        )

        # Read all bytes and encode to base64
        audio_bytes = response.read()
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')

        return {
            "status": "success",
            "format": request.response_format,
            "voice": request.voice,
            "audio_base64": audio_base64
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# OpenAI Whisper Endpoints
# ============================================================================

@app.get("/openai/whisper")
async def whisper_health():
    """Health check for Whisper service."""
    return {
        "status": "healthy" if OPENAI_API_KEY else "not_configured",
        "service": "openai_whisper",
        "models": ["whisper-1"],
        "supported_formats": ["mp3", "mp4", "mpeg", "mpga", "m4a", "wav", "webm"]
    }

@app.post("/openai/whisper/transcribe")
async def transcribe_audio(
    file: UploadFile = File(...),
    language: Optional[str] = None,
    token: str = Depends(verify_token)
):
    """Transcribe audio to text using OpenAI Whisper."""
    if not openai_client:
        raise HTTPException(status_code=500, detail="OpenAI client not configured")

    try:
        # Read the uploaded file
        audio_content = await file.read()

        # Create a temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file.filename.split('.')[-1]}") as tmp:
            tmp.write(audio_content)
            tmp_path = tmp.name

        try:
            # Transcribe
            with open(tmp_path, "rb") as audio_file:
                kwargs = {"model": "whisper-1", "file": audio_file}
                if language:
                    kwargs["language"] = language

                transcript = openai_client.audio.transcriptions.create(**kwargs)

            return {
                "status": "success",
                "text": transcript.text,
                "filename": file.filename
            }

        finally:
            # Clean up temp file
            os.unlink(tmp_path)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/openai/whisper/transcribe-base64")
async def transcribe_audio_base64(
    audio_base64: str = None,
    filename: str = "audio.mp3",
    language: Optional[str] = None,
    token: str = Depends(verify_token)
):
    """Transcribe base64-encoded audio to text."""
    if not openai_client:
        raise HTTPException(status_code=500, detail="OpenAI client not configured")

    if not audio_base64:
        raise HTTPException(status_code=400, detail="audio_base64 is required")

    try:
        # Decode base64
        audio_bytes = base64.b64decode(audio_base64)

        # Get file extension
        ext = filename.split('.')[-1] if '.' in filename else 'mp3'

        # Create temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix=f".{ext}") as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name

        try:
            with open(tmp_path, "rb") as audio_file:
                kwargs = {"model": "whisper-1", "file": audio_file}
                if language:
                    kwargs["language"] = language

                transcript = openai_client.audio.transcriptions.create(**kwargs)

            return {
                "status": "success",
                "text": transcript.text
            }

        finally:
            os.unlink(tmp_path)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# Root Endpoint
# ============================================================================

@app.get("/")
async def root():
    """API root endpoint."""
    return {
        "service": "365 Weapons Admin API",
        "version": "1.1.0",
        "endpoints": {
            "lancedb": "/lancedb - Vector search",
            "openrouter": "/openrouter - AI chat (Claude, GPT, etc.)",
            "tts": "/openai/tts - Text to speech",
            "whisper": "/openai/whisper - Speech to text"
        },
        "status": {
            "lancedb": "healthy" if db else "not_initialized",
            "openai": "configured" if OPENAI_API_KEY else "not_configured",
            "openrouter": "configured" if OPENROUTER_API_KEY else "not_configured"
        }
    }

# ============================================================================
# Run Server
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
