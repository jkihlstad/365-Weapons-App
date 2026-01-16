# 365 Weapons Admin Backend
# LanceDB + OpenRouter/OpenAI API Server

FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create data directory for LanceDB
RUN mkdir -p /app/lancedb_data

# Environment variables
ENV LANCEDB_PATH=/app/lancedb_data

# Run the application - uses PORT from environment
CMD ["python", "main.py"]
