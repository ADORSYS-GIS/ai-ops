# MCP Servers for adorsys AI Platform (Envoy-Based SaaS)

Since we are developers, we need production-grade applications behind our AI platform.  
The idea is to:

- Deploy MCP-compatible servers internally  
- Expose them through Envoy AI Gateway  
- Secure them via Authorino / OAuth2 / API Keys  
- Offer them as internal SaaS capabilities to LibreChat / RooCode  

---

## Architectural Constraints

For our stack (Envoy + Gateway API + enterprise routing):

- ✅ **Streamable HTTP MCP servers are optimal**
- ⚠️ **SSE-only servers are usable but fragile behind proxies**
- ❌ **STDIO-only servers are not suitable for cluster deployment**

We should only prioritize MCP servers that:

- Properly implement the MCP API (`tools/list`, `tools/call`)  
- Expose `/mcp`  
- Work with HTTP transport  
- Are implemented in **Go, Rust, or TypeScript**  
- Support proper authentication (OAuth2 / API Key)  

If implemented in something else (e.g., Python), mark as **Not Optimal** and wait.

---

# Proposed MCP Server Candidates

| Tool | Connectivity | Auth | Description | Optimal | Endpoint |
|------|--------------|------|------------|---------| ---------|
| [Jira MCP and confluence](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/getting-started-with-the-atlassian-remote-mcp-server/) | streamable-http | OAuth2 | Issue & sprint management | No (py) | https://mcp.atlassian.com/v1/mcp
| [Brave Search MCP](https://github.com/brave/brave-search-mcp-server) | http streamable | API Key | Web search capability | Yes (ts) | custom |
| [Firecrawl MCP ](https://docs.firecrawl.dev/mcp-server)| streamable-http | API Key | Crawl & extract structured data | Yes(js) | https://mcp.firecrawl.dev/{FIRECRAWL_API_KEY}/v2/mcp |
| [Context7 MCP](https://github.com/upstash/context7) | streamable-http | API Key | Library & documentation lookup | Yes (ts) | https://mcp.context7.com/mcp | 
| [Tavily MCP](https://docs.tavily.com/documentation/mcp) | streamable-http | API Key | AI-optimized web search | Yes (js) | https://mcp.tavily.com/mcp/?tavilyApiKey=<your-api-key> |
| [Qdrant MCP](https://github.com/qdrant/mcp-server-qdrant) | http streamable | API Key | Connect to Qdrant vector DB | No (Py) | custom |
| Kubernetes MCP | streamable-http | Service Account / OAuth2 | Cluster inspection & operations | depends on implementation | custom |
| [Terraform MCP](https://developer.hashicorp.com/terraform/mcp-server/deploy#run-in-docker) | streamable-http | API Key | Infra state analysis | Yes (go) | custom |
| [ArgoCD MCP](https://github.com/argoproj-labs/mcp-for-argocd) | streamable-http | OAuth2 | GitOps monitoring | depends on implementation | custom |

##  Recommendation

1. Only onboard MCP servers that pass `tools/list` over HTTP.
2. Standardize paths:
   ```
   /mcp/github
   /mcp/kubernetes
   /mcp/search
   ```