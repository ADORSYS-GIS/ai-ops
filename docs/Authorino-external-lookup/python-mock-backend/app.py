"""
Mock API Key Validation Backend

This service validates client API keys via HTTP.
Authorino calls this service to determine if a client's API key is valid.

Endpoints:
    GET /validate - Validates an API key from X-API-Key header
    GET /health - Health check endpoint
"""

from flask import Flask, request, jsonify
import logging
import os
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Valid client API keys
# In production, this would be a database lookup
VALID_KEYS = {
    "client-key-123": {
        "user_id": "user-001",
        "name": "Test User 1",
        "created_at": "2024-01-01T00:00:00Z"
    },
    "client-key-456": {
        "user_id": "user-002",
        "name": "Test User 2",
        "created_at": "2024-01-15T00:00:00Z"
    }
}

@app.route('/validate', methods=['GET'])
def validate_key():
    """
    Validate an API key from the X-API-Key header.
    
    Returns:
        200 OK with {"valid": true} if the key is valid
        401 Unauthorized with {"valid": false} if invalid or missing
    """
    # Extract API key from header
    api_key = request.headers.get('X-API-Key')
    
    # Log the validation attempt
    logger.info(f"Validation request received - Key: {api_key[:12] if api_key else 'None'}...")
    
    if not api_key:
        logger.warning("Validation failed: Missing API key")
        return jsonify({
            "valid": False,
            "error": "Missing API key",
            "timestamp": datetime.utcnow().isoformat()
        }), 401
    
    # Check if key is valid
    if api_key in VALID_KEYS:
        key_info = VALID_KEYS[api_key]
        logger.info(f"Validation successful for user: {key_info['user_id']}")
        return jsonify({
            "valid": True,
            "user_id": key_info["user_id"],
            "timestamp": datetime.utcnow().isoformat()
        }), 200
    else:
        logger.warning(f"Validation failed: Invalid API key")
        return jsonify({
            "valid": False,
            "error": "Invalid API key",
            "timestamp": datetime.utcnow().isoformat()
        }), 401

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy",
        "service": "mock-api-key-backend",
        "timestamp": datetime.utcnow().isoformat()
    }), 200

@app.route('/keys', methods=['GET'])
def list_keys():
    """
    List all valid API keys (for testing purposes only).
    
    This endpoint should NOT exist in production.
    """
    return jsonify({
        "keys": list(VALID_KEYS.keys()),
        "count": len(VALID_KEYS),
        "warning": "This endpoint is for testing only"
    }), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    logger.info(f"Starting Mock API Key Backend on port {port}")
    logger.info(f"Loaded {len(VALID_KEYS)} valid API keys")
    app.run(host='0.0.0.0', port=port, debug=False)