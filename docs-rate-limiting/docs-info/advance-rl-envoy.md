--If want to test more envoy rate limit features --
## Request based rate limiting
```yaml
  rateLimit:
    global:
      rules:
      - clientSelectors:
        - headers:
          - name: x-user-id
            value: user1
        limit:
          requests: 3
          unit: Hour
```
## Token base rate limiting
```yaml
  rateLimit:
    type: Global
    global:
      rules:
      - clientSelectors:
        - headers:
          - name: x-user-id
            type: Distinct
        limit:
          requests: 10000
          unit: Hour
        cost:
          request:
            from: Number
            number: 0
          response:
            from: Metadata
            metadata:
              namespace: io.envoy.ai_gateway
              key: llm_total_token
```