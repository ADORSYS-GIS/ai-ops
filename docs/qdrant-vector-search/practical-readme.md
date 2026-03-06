# Gateway and Auth Contract (Envoy + Authorino + Qdrant)

This document defines the HTTP contract enforced by the gateway layer in this workspace.

## 1) Traffic path

Request flow:
- Client sends HTTP request to Envoy.
- Envoy calls Authorino (`ext_authz`) for authorization.
- If authorized, Envoy forwards request to Qdrant.

## 2) Required authorization header

All protected requests must include:

```http
Authorization: APIKEY <secret>
```

Behavior:
- Missing or invalid credential: `403 Forbidden`.
- Valid credential: request is forwarded to Qdrant.

## 3) Auth policy model used here

Authorino policy intent:
- Header-based API key authentication.
- Prefix expected in header value: `APIKEY`.
- Credential material loaded from managed secrets labeled with `group: friends`.

## 4) Envoy behavior summary

Envoy listener:
- Receives HTTP traffic on `:10000`.

Envoy upstream clusters:
- `authorino` cluster for auth checks.
- `qdrant_cluster` for data operations.

Auth filter mode:
- `failure_mode_allow: false` (fail-closed).

Implication:
- If Authorino is unreachable, Envoy denies protected requests.

## 5) HTTP interaction schema through the gateway

Collection creation (example schema):

```http
PUT /collections/{collection_name}
Host: <gateway-host>:<gateway-port>
Authorization: APIKEY <secret>
Content-Type: application/json

{
  "vectors": {
    "size": 384,
    "distance": "Cosine"
  }
}
```

Collection read (example schema):

```http
GET /collections/{collection_name}
Host: <gateway-host>:<gateway-port>
Authorization: APIKEY <secret>
```

Point upsert (example schema):

```http
PUT /collections/{collection_name}/points
Host: <gateway-host>:<gateway-port>
Authorization: APIKEY <secret>
Content-Type: application/json

{
  "points": [
    {
      "id": 1,
      "vector": [0.11, 0.35, 0.27, 0.94],
      "payload": {
        "category": "book",
        "lang": "en"
      }
    }
  ]
}
```

Query (example schema):

```http
POST /collections/{collection_name}/points/query
Host: <gateway-host>:<gateway-port>
Authorization: APIKEY <secret>
Content-Type: application/json

{
  "query": [0.11, 0.35, 0.27, 0.94],
  "limit": 10,
  "with_payload": true,
  "with_vector": false
}
```

## 6) Typical response classes

- `2xx`: request accepted by gateway and processed by Qdrant.
- `403`: rejected by authorization policy.
- `4xx` from Qdrant: request shape or business validation issue.
- `5xx`: upstream connectivity or internal processing issue.

## 7) Reference

- Qdrant concepts: https://qdrant.tech/documentation/concepts/
