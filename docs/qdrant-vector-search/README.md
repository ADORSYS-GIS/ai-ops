# Qdrant Vector Search Workspace

This workspace documents a Qdrant-based vector search setup with an API gateway layer.

Scope:
- Explore Qdrant data structures and workflows through HTTP schemas.
- Document gateway authentication behavior for this project.
- Keep examples protocol-focused (no shell command walkthroughs).

Architecture (logical):
- Client
- Envoy gateway
- Authorino external authorization
- Qdrant service

Documentation map:
- `qdrant-vector-database.md`: practical HTTP schemas for collection lifecycle, point lifecycle, query, filtering, and exploration flows.
- `practical-readme.md`: gateway contract and request/response behavior for secured traffic.
- `configmap.yaml`: Envoy bootstrap used by this setup.

Authentication model used in this workspace:
- Header name: `Authorization`
- Header value format: `APIKEY <secret-from-env>`

Primary reference:
- https://qdrant.tech/documentation/concepts/
