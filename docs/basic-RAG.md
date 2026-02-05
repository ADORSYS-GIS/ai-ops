# RAG API Tutorial with Ollama

This tutorial demonstrates how to run the **RAG API** with **local Ollama models** to index documents and perform retrieval-augmented question answering.

---

## What Is the RAG API?

The RAG API (by danny-avila) is a FastAPI service that provides Retrieval-Augmented Generation (RAG). It combines:

* **PostgreSQL + pgvector** for vector storage
* **LangChain** for document loading and chunking
* **Embedding providers** such as Ollama or OpenAI

It is commonly used by LibreChat, but works perfectly well as a standalone RAG backend.

---

## API Endpoints

The API exposes the following endpoints:

* **POST `/embed`** – Upload and index a document
* **POST `/query`** – Query indexed documents
* **DELETE `/delete`** – Delete an indexed document (`file_id` required)
* **GET `/health`** – Health check

---

## Prerequisites

* Docker and Docker Compose
* ~5 GB free disk space for models
* Basic familiarity with the command line

---

## Step 1: Clone the Repository and Configure Environment

```bash
git clone https://github.com/danny-avila/rag_api.git
cd rag_api
```

Create a `.env` file:

```bash
cat > .env << 'EOF'
# Database
POSTGRES_DB=ragdb
POSTGRES_USER=raguser
POSTGRES_PASSWORD=ragpass
DB_HOST=vectordb
DB_PORT=5432

# API
RAG_PORT=8000
COLLECTION_NAME=my_documents

# Ollama
EMBEDDINGS_PROVIDER=ollama
EMBEDDINGS_MODEL=nomic-embed-text
OLLAMA_BASE_URL=http://ollama:11434

# Chunking
CHUNK_SIZE=1000
CHUNK_OVERLAP=200

# Debug
DEBUG_RAG_API=True
EOF
```

---

## Step 2: Docker Compose Configuration

```yaml
version: '3.8'

services:
  vectordb:
    image: ankane/pgvector:latest
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    healthcheck:
      test: ollama --version || exit 1
      interval: 10s
      timeout: 5s
      retries: 5

  rag_api:
    build: .
    ports:
      - "${RAG_PORT}:${RAG_PORT}"
    env_file:
      - .env
    depends_on:
      vectordb:
        condition: service_healthy
      ollama:
        condition: service_healthy

volumes:
  pgdata:
  ollama_data:
```

---

## Step 3: Start Services and Pull Models

```bash
docker-compose up -d
sleep 30
```

Pull models into Ollama:

```bash
docker exec $(docker ps -qf "name=ollama") ollama pull nomic-embed-text
docker exec $(docker ps -qf "name=ollama") ollama pull llama3.2
docker exec $(docker ps -qf "name=ollama") ollama list
```

---

## Step 4: Index a Document

```bash
cat > sample_document.txt << 'EOF'
Introduction to Machine Learning

Machine learning is a subset of artificial intelligence that focuses on
building systems that learn from data.

The three main types are:
1. Supervised Learning
2. Unsupervised Learning
3. Reinforcement Learning

Popular frameworks include TensorFlow, PyTorch, and scikit-learn.
EOF
```

```bash
curl -X POST http://localhost:8000/embed \
  -F "file=@sample_document.txt" \
  -F "file_id=doc123"
```

---

## Step 5: Query the Document

```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What are the three types of machine learning?",
    "file_id": "doc123"
  }'
```

The response is a list of `[document, similarity_score]` pairs.

---

## Step 6: Complete RAG Pipeline (Python)

```python
#!/usr/bin/env python3
"""
Complete RAG Pipeline Example
"""
import requests
import json

RAG_API_URL = "http://localhost:8000"
OLLAMA_URL = "http://localhost:11434"

def upload_document(filepath, file_id):
    """Upload and index a document"""
    with open(filepath, 'rb') as f:
        files = {'file': f}
        data = {'file_id': file_id}
        response = requests.post(f"{RAG_API_URL}/embed", files=files, data=data)
    response.raise_for_status()
    return response.json()

def query_documents(query, file_id):
    """Query indexed documents - NOTE: file_id is SINGULAR"""
    payload = {
        "query": query,
        "file_id": file_id  # SINGULAR, not file_ids!
    }
    response = requests.post(f"{RAG_API_URL}/query", json=payload)
    response.raise_for_status()
    return response.json()

def generate_answer(query, context, model="llama3.2"):
    """Generate answer using Ollama"""
    prompt = f"""Based on the following context, answer the question concisely.

Context:
{context}

Question: {query}

Answer:"""
    
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False
    }
    response = requests.post(f"{OLLAMA_URL}/api/generate", json=payload)
    response.raise_for_status()
    return response.json()['response']

def rag_pipeline(query, file_id):
    """Complete RAG pipeline"""
    print(f"Query: {query}\n")
    
    # Retrieve relevant context
    print("Retrieving context...")
    results = query_documents(query, file_id)
    
    if not results or len(results) == 0:
        return "No relevant context found."
    
    # Extract content from results
    # Results are in format: [[{doc}, score], [{doc}, score], ...]
    contexts = []
    for item in results:
        if isinstance(item, list) and len(item) > 0:
            doc = item[0]
            if isinstance(doc, dict) and 'page_content' in doc:
                contexts.append(doc['page_content'])
                score = item[1] if len(item) > 1 else 0
                print(f"  Found chunk (score: {score:.3f})")
    
    if not contexts:
        return "No content found in results."
    
    context = "\n\n".join(contexts[:3])  # Use top 3 chunks
    
    # Generate answer
    print("\nGenerating answer...")
    answer = generate_answer(query, context)
    
    return answer

# Main execution
if __name__ == "__main__":
    print("=" * 80)
    print("RAG Pipeline Demo".center(80))
    print("=" * 80 + "\n")
    
    # Upload document
    print("1. Uploading document...")
    result = upload_document("sample_document.txt", "ml_doc")
    print(f"   Status: {result.get('message')}\n")
    
    # Ask questions
    questions = [
        "What are the three types of machine learning?",
        "What frameworks are mentioned for machine learning?",
    ]
    
    for question in questions:
        print("-" * 80)
        answer = rag_pipeline(question, "ml_doc")
        print(f"\nAnswer: {answer}\n")
```

---

## Notes

* `file_id` is singular
* Query responses are lists, not objects with a `results` field
* Files are stored under the default `user_id = "public"`

---

## Supported File Types

Text, documents, code, structured data, and common web formats are supported.

---

## Cleanup

```bash
docker-compose down -v
docker volume rm rag_api_ollama_data
```

---

## Summary

This setup provides a clean, local RAG stack using Ollama for embeddings and generation. It is lightweight, extensible, and suitable for experimentation or production prototyping.
