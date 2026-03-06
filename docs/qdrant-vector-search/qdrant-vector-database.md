# Qdrant Exploration Guide (HTTP Schema Only)

This guide explains how to explore and validate a Qdrant vector database through HTTP request schemas.

Reference pages:
- https://qdrant.tech/documentation/concepts/
- https://api.qdrant.tech/api-reference

## 1) Base request model

Base URL pattern:

```http
https://<qdrant-host>:6333
```

Gateway-authenticated header model used in this workspace:

```http
Authorization: APIKEY <secret>
```

JSON requests should include:

```http
Content-Type: application/json
```

## 2) Collection lifecycle

List collections:

```http
GET /collections
```

Check collection existence:

```http
GET /collections/{collection_name}/exists
```

Create collection (single dense vector):

```http
PUT /collections/{collection_name}

{
  "vectors": {
    "size": 384,
    "distance": "Cosine"
  }
}
```

Create collection (named vectors):

```http
PUT /collections/{collection_name}

{
  "vectors": {
    "image": {
      "size": 4,
      "distance": "Dot"
    },
    "text": {
      "size": 8,
      "distance": "Cosine"
    }
  }
}
```

Create collection (uint8 vectors):

```http
PUT /collections/{collection_name}

{
  "vectors": {
    "size": 1024,
    "distance": "Cosine",
    "datatype": "uint8"
  }
}
```

Read collection info:

```http
GET /collections/{collection_name}
```

Delete collection:

```http
DELETE /collections/{collection_name}
```

## 3) Point lifecycle

Upsert points:

```http
PUT /collections/{collection_name}/points

{
  "points": [
    {
      "id": 1,
      "vector": [0.91, 0.12, 0.44, 0.73],
      "payload": {
        "category": "book",
        "lang": "en",
        "published_year": 2024
      }
    },
    {
      "id": 2,
      "vector": [0.81, 0.18, 0.40, 0.68],
      "payload": {
        "category": "book",
        "lang": "fr",
        "published_year": 2022
      }
    }
  ]
}
```

Upsert points (named vectors):

```http
PUT /collections/{collection_name}/points

{
  "points": [
    {
      "id": 1001,
      "vector": {
        "image": [0.22, 0.31, 0.44, 0.58],
        "text": [0.10, 0.03, 0.28, 0.91, 0.12, 0.44, 0.71, 0.36]
      },
      "payload": {
        "doc_type": "product"
      }
    }
  ]
}
```

Retrieve multiple points by IDs:

```http
POST /collections/{collection_name}/points

{
  "ids": [1, 2, 1001],
  "with_payload": true,
  "with_vector": false
}
```

Retrieve one point:

```http
GET /collections/{collection_name}/points/{id}
```

Delete points by IDs:

```http
POST /collections/{collection_name}/points/delete

{
  "points": [1, 2]
}
```

Set payload values:

```http
POST /collections/{collection_name}/points/payload

{
  "payload": {
    "source": "manual-review",
    "quality": "verified"
  },
  "points": [1001]
}
```

## 4) Query and exploration

Universal query endpoint (vector similarity, filtering, recommendation-like flows):

```http
POST /collections/{collection_name}/points/query

{
  "query": [0.91, 0.12, 0.44, 0.73],
  "limit": 10,
  "with_payload": true,
  "with_vector": false
}
```

Query with filter constraints:

```http
POST /collections/{collection_name}/points/query

{
  "query": [0.91, 0.12, 0.44, 0.73],
  "filter": {
    "must": [
      {
        "key": "lang",
        "match": {
          "value": "en"
        }
      },
      {
        "key": "published_year",
        "range": {
          "gte": 2020
        }
      }
    ]
  },
  "limit": 5,
  "with_payload": true
}
```

Scroll for full exploration / pagination:

```http
POST /collections/{collection_name}/points/scroll

{
  "limit": 50,
  "with_payload": true,
  "with_vector": false,
  "offset": 1001
}
```

Scroll ordered by payload field:

```http
POST /collections/{collection_name}/points/scroll

{
  "limit": 20,
  "order_by": "published_year",
  "with_payload": true
}
```

Count points in collection:

```http
POST /collections/{collection_name}/points/count

{
  "exact": true
}
```

Count points matching a filter:

```http
POST /collections/{collection_name}/points/count

{
  "filter": {
    "must": [
      {
        "key": "category",
        "match": {
          "value": "book"
        }
      }
    ]
  },
  "exact": true
}
```

## 5) Interpretation checklist

Healthy exploration sequence:
- `GET /collections` confirms connectivity.
- `PUT /collections/{collection_name}` sets schema.
- `PUT /collections/{collection_name}/points` confirms ingestion.
- `POST /collections/{collection_name}/points/query` validates semantic retrieval quality.
- `POST /collections/{collection_name}/points/scroll` audits corpus content and payload consistency.
- `POST /collections/{collection_name}/points/count` verifies scale and filter selectivity.

## 6) Notes about headers

Qdrant API reference commonly documents `api-key` for direct API key auth.
In this workspace, requests go through an Envoy+Authorino policy and are expected to use:

```http
Authorization: APIKEY <secret>
```
