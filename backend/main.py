"""
365 Weapons Admin Backend
LanceDB Vector Search + LangGraph Agent Orchestration API
"""

import os
import json
import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import lancedb
import numpy as np
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

# ============================================================================
# Configuration
# ============================================================================

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
AUTH_TOKEN = os.getenv("API_AUTH_TOKEN", "your-secret-token")
EMBEDDING_MODEL = "text-embedding-3-small"
EMBEDDING_DIMENSION = 1536

# ============================================================================
# Database Setup
# ============================================================================

db = None
openai_client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize connections on startup."""
    global db, openai_client

    # Initialize LanceDB (uses local storage, can be configured for S3)
    db_path = os.getenv("LANCEDB_PATH", "./lancedb_data")
    db = lancedb.connect(db_path)

    # Initialize OpenAI client for embeddings
    if OPENAI_API_KEY:
        openai_client = OpenAI(api_key=OPENAI_API_KEY)

    print(f"LanceDB initialized at {db_path}")
    yield

    print("Shutting down...")

# ============================================================================
# FastAPI App
# ============================================================================

app = FastAPI(
    title="365 Weapons Admin API",
    description="LanceDB Vector Search and LangGraph Agent Orchestration",
    version="1.0.0",
    lifespan=lifespan
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
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
    alpha: float = 0.5  # Balance between vector and keyword search
    filter: Optional[Dict[str, Any]] = None

class InsertRequest(BaseModel):
    table: str
    documents: List[Dict[str, Any]]

class DeleteRequest(BaseModel):
    table: str
    ids: List[str]

class CreateTableRequest(BaseModel):
    table: str
    schema_fields: Dict[str, str]  # field_name: field_type

class GraphRunRequest(BaseModel):
    graph_name: str
    input_message: str
    context: Optional[Dict[str, Any]] = None
    config: Optional[Dict[str, Any]] = None

class GraphState(BaseModel):
    messages: List[Dict[str, Any]] = []
    current_agent: Optional[str] = None
    context: Dict[str, Any] = {}
    tool_calls: List[Dict[str, Any]] = []
    result: Optional[str] = None
    error: Optional[str] = None
    is_complete: bool = False

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
        # Create with default schema
        db.create_table(table_name, data=[{
            "id": "placeholder",
            "text": "placeholder",
            "vector": [0.0] * EMBEDDING_DIMENSION,
            "metadata": "{}"
        }])
        # Delete placeholder
        table = db.open_table(table_name)
        table.delete('id = "placeholder"')

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

        # Generate query embedding
        query_embedding = get_embedding(request.query)

        # Perform search
        results = table.search(query_embedding).limit(request.limit).to_pandas()

        # Convert to list of dicts
        items = results.to_dict(orient='records')

        # Parse metadata JSON strings
        for item in items:
            if 'metadata' in item and isinstance(item['metadata'], str):
                try:
                    item['metadata'] = json.loads(item['metadata'])
                except:
                    pass
            # Remove vector from response (too large)
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

        # Generate query embedding
        query_embedding = get_embedding(request.query)

        # Vector search
        vector_results = table.search(query_embedding).limit(request.limit * 2).to_pandas()

        # Keyword search (simple text matching)
        keyword_results = table.search(request.query, query_type="fts").limit(request.limit * 2).to_pandas()

        # Combine and rerank using alpha
        combined = {}

        for idx, row in vector_results.iterrows():
            doc_id = row.get('id', str(idx))
            score = 1.0 / (idx + 1)  # Rank-based score
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

        # Sort by combined score
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

        # Process documents
        records = []
        for doc in request.documents:
            # Generate embedding from text field
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

        # Insert into table
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

        # Delete each ID
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

        # Create with placeholder data
        db.create_table(request.table, data=[{
            "id": "placeholder",
            "text": "placeholder",
            "vector": [0.0] * EMBEDDING_DIMENSION,
            "metadata": "{}"
        }])

        # Remove placeholder
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
# LangGraph Endpoints
# ============================================================================

@app.get("/langgraph")
async def langgraph_health():
    """Health check for LangGraph service."""
    return {
        "status": "healthy",
        "service": "langgraph",
        "available_graphs": ["admin_assistant", "order_processor", "analytics"]
    }

@app.post("/langgraph/run")
async def run_graph(
    request: GraphRunRequest,
    token: str = Depends(verify_token)
):
    """Run a LangGraph workflow."""
    try:
        # Initialize state
        state = GraphState(
            messages=[{
                "id": str(uuid.uuid4()),
                "role": "user",
                "content": request.input_message,
                "timestamp": datetime.utcnow().isoformat()
            }],
            context=request.context or {}
        )

        # Route to appropriate graph
        if request.graph_name == "admin_assistant":
            result = await run_admin_assistant(state, request.config)
        elif request.graph_name == "order_processor":
            result = await run_order_processor(state, request.config)
        elif request.graph_name == "analytics":
            result = await run_analytics_agent(state, request.config)
        else:
            raise HTTPException(status_code=404, detail=f"Graph {request.graph_name} not found")

        return {
            "status": "success",
            "graph": request.graph_name,
            "result": result.dict()
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

async def run_admin_assistant(state: GraphState, config: Optional[Dict] = None) -> GraphState:
    """Run the admin assistant graph."""
    if not openai_client:
        state.error = "OpenAI client not configured"
        state.is_complete = True
        return state

    try:
        # Simple assistant using OpenAI
        messages = [
            {"role": "system", "content": """You are an AI assistant for the 365 Weapons admin dashboard.
            You help administrators manage orders, products, and business analytics.
            Be concise and helpful."""}
        ]

        for msg in state.messages:
            messages.append({
                "role": msg.get("role", "user"),
                "content": msg.get("content", "")
            })

        response = openai_client.chat.completions.create(
            model="gpt-4-turbo-preview",
            messages=messages,
            max_tokens=1000
        )

        assistant_message = response.choices[0].message.content

        state.messages.append({
            "id": str(uuid.uuid4()),
            "role": "assistant",
            "content": assistant_message,
            "agent_name": "admin_assistant",
            "timestamp": datetime.utcnow().isoformat()
        })

        state.result = assistant_message
        state.current_agent = "admin_assistant"
        state.is_complete = True

    except Exception as e:
        state.error = str(e)
        state.is_complete = True

    return state

async def run_order_processor(state: GraphState, config: Optional[Dict] = None) -> GraphState:
    """Run the order processing graph."""
    # Placeholder for order processing logic
    state.result = "Order processing completed"
    state.current_agent = "order_processor"
    state.is_complete = True
    return state

async def run_analytics_agent(state: GraphState, config: Optional[Dict] = None) -> GraphState:
    """Run the analytics agent graph."""
    # Placeholder for analytics logic
    state.result = "Analytics processing completed"
    state.current_agent = "analytics"
    state.is_complete = True
    return state

# ============================================================================
# Root Endpoint
# ============================================================================

@app.get("/")
async def root():
    """API root endpoint."""
    return {
        "service": "365 Weapons Admin API",
        "version": "1.0.0",
        "endpoints": {
            "lancedb": "/lancedb",
            "langgraph": "/langgraph"
        },
        "status": "healthy"
    }

# ============================================================================
# Run Server
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
