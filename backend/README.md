# 365 Weapons Admin Backend

LanceDB Vector Search + LangGraph Agent Orchestration API for the 365 Weapons iOS Admin app.

## Features

- **Vector Search** - Semantic search over products, documents, and knowledge base
- **Hybrid Search** - Combined vector + keyword search for better results
- **LangGraph Agents** - AI-powered admin assistant, order processor, and analytics

## API Endpoints

### LanceDB (Vector Search)
- `GET /lancedb` - Health check
- `POST /lancedb/search` - Vector similarity search
- `POST /lancedb/hybrid-search` - Combined vector + keyword search
- `POST /lancedb/insert` - Insert documents with auto-embeddings
- `POST /lancedb/delete` - Delete documents by ID
- `GET /lancedb/tables` - List all tables
- `POST /lancedb/tables` - Create new table

### LangGraph (Agent Orchestration)
- `GET /langgraph` - Health check
- `POST /langgraph/run` - Execute an agent graph

---

## Deployment Options

### Option 1: Railway (Recommended)

Railway provides persistent storage needed for LanceDB.

1. **Create Railway Account**
   ```
   https://railway.app
   ```

2. **Install Railway CLI**
   ```bash
   npm install -g @railway/cli
   railway login
   ```

3. **Deploy from this directory**
   ```bash
   cd backend
   railway init
   railway up
   ```

4. **Set Environment Variables**
   ```bash
   railway variables set OPENAI_API_KEY=sk-your-key
   railway variables set API_AUTH_TOKEN=your-secure-token
   ```

5. **Add Custom Domain**
   - Go to Railway Dashboard → Your Project → Settings → Domains
   - Add `api.365weapons.com`
   - Update your DNS with the provided CNAME record

### Option 2: Render

1. **Create Render Account**
   ```
   https://render.com
   ```

2. **Create New Web Service**
   - Connect your GitHub repo
   - Select the `backend` directory
   - Runtime: Python 3
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`

3. **Add Environment Variables**
   - `OPENAI_API_KEY`: Your OpenAI API key
   - `API_AUTH_TOKEN`: Your secure auth token

4. **Add Custom Domain**
   - Go to Settings → Custom Domains
   - Add `api.365weapons.com`

### Option 3: Fly.io

1. **Install Fly CLI**
   ```bash
   curl -L https://fly.io/install.sh | sh
   fly auth login
   ```

2. **Create fly.toml**
   ```toml
   app = "365weapons-api"
   primary_region = "sjc"

   [build]
     dockerfile = "Dockerfile"

   [http_service]
     internal_port = 8000
     force_https = true

   [mounts]
     source = "lancedb_data"
     destination = "/app/lancedb_data"
   ```

3. **Deploy**
   ```bash
   fly launch
   fly secrets set OPENAI_API_KEY=sk-your-key
   fly secrets set API_AUTH_TOKEN=your-token
   fly deploy
   ```

4. **Add Custom Domain**
   ```bash
   fly certs create api.365weapons.com
   ```

### Option 4: Vercel (Limited)

⚠️ **Note**: Vercel serverless functions have limitations:
- 10-60 second timeout
- No persistent storage (must use LanceDB Cloud or external DB)
- Cold starts affect performance

For Vercel, modify to use LanceDB Cloud:

1. **Sign up for LanceDB Cloud**
   ```
   https://lancedb.com
   ```

2. **Update code to use cloud connection**
   ```python
   db = lancedb.connect(
       "db://your-project",
       api_key="your-lancedb-api-key"
   )
   ```

---

## DNS Configuration

After deploying, add a CNAME record to your domain:

| Type | Name | Value |
|------|------|-------|
| CNAME | api | your-railway-app.up.railway.app |

Or for other providers:
- Render: `your-app.onrender.com`
- Fly.io: `your-app.fly.dev`

---

## Local Development

1. **Create virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # or `venv\Scripts\activate` on Windows
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Set environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

4. **Run server**
   ```bash
   uvicorn main:app --reload --port 8000
   ```

5. **Test endpoints**
   ```bash
   # Health check
   curl http://localhost:8000/

   # LanceDB health
   curl http://localhost:8000/lancedb

   # Search (requires auth)
   curl -X POST http://localhost:8000/lancedb/search \
     -H "Authorization: Bearer your-token" \
     -H "Content-Type: application/json" \
     -d '{"query": "laser engraving", "table": "products_embeddings"}'
   ```

---

## iOS App Configuration

After deployment, update the iOS app to use your new endpoints:

```swift
// In LanceDBClient.swift
LanceDBConfig.serverEndpoint = "https://api.365weapons.com/lancedb"

// In LangGraphService.swift
LangGraphConfig.serverEndpoint = "https://api.365weapons.com/langgraph"
```

Configure the auth token in the app's Settings or via the `SecureConfigManager`.

---

## Security Notes

1. **Generate a strong auth token**
   ```bash
   openssl rand -hex 32
   ```

2. **Keep your OpenAI API key secure**
   - Never commit to git
   - Use environment variables only

3. **Enable HTTPS** - All providers above support automatic HTTPS

4. **Rate limiting** - Consider adding rate limiting for production
