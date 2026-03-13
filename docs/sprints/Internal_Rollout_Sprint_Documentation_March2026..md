**AI-Ops Platform**

Sprint Documentation & User Feedback Report

March 2026 \| Internal Rollout Sprint

1\. Executive Summary

This document synthesizes the outcomes of the AI-Ops team's internal
rollout sprint conducted during the week of March 2026. The sprint's
primary objective was to present the platform to the broader
organisation for the first time in a production environment with real
stakes --- moving beyond internal QA into actual usage by colleagues
across the company.

Team members moved through the office, giving hands-on demonstrations
and collecting structured feedback. Topics covered included signing into
the LightBridge UI, generating and configuring API keys, setting up IDE
integrations (e.g., Roo Code, Zed, OpenCode), querying models via
LibreChat, and using the GitHub and LightBridge agents.

The overall response from colleagues was strongly positive. The platform
was recognised as powerful and directly applicable to daily work.
Several actionable issues were surfaced across UI, infrastructure, and
model reliability dimensions. This report organises those findings and
maps them to the platform's broader roadmap.

2\. Platform Architecture Overview

The AI-Ops platform is a self-hosted, Kubernetes-based AI gateway
infrastructure composed of the following core components:

-   LightBridge Auth & API Server --- self-service API key management
    with a web UI backed by a PostgreSQL database

-   LibreChat --- browser-based chat interface supporting multiple
    models, agents, and MCP integrations

-   Envoy Gateway --- the central API proxy and load balancer routing
    traffic to backend AI providers

-   Authorino --- the authentication and policy enforcement layer,
    supporting OAuth2, API keys, Bearer tokens, and Basic Auth

-   Keycloak --- the identity provider (IdP) used within Koufan's domain
    for SSO

-   AI Proxy (Envoy AI Gateway Operator) --- routes requests to external
    LLM providers (OpenAI, Claude, Fireworks, etc.)

-   kServe + vLLM --- self-hosted model serving infrastructure for
    open-source models (Gemma3, Llama3, GPT OSS variants)

-   MCPs (Model Context Protocol servers) --- tool integrations exposed
    to agents in LibreChat (GitHub MCP, LightBridge MCP)

Two architectural domains are in play: Koufan's domain (managing
identity and API key issuance) and Valantine's domain (the Kubernetes
cluster hosting the gateway, chat interface, and model serving
infrastructure). External users and IDE clients interact via the Envoy
gateway as the unified entry point.

3\. Sprint Objectives

This sprint was explicitly scoped as the first real-world deployment of
all platform components simultaneously. The goals were:

-   Validate end-to-end user flows in a production environment

-   Expose the platform to non-technical and semi-technical colleagues
    for the first time

-   Demonstrate the value proposition of the platform versus legacy
    tools (e.g., Kivoyo)

-   Collect structured feedback to prioritise the next development cycle

-   Surface integration issues with third-party clients (Roo Code, Zed,
    OpenCode)

4\. What Was Demonstrated

Each team member conducted live walkthroughs covering the following
flows:

4.1 LightBridge UI Onboarding

-   Sign-up and sign-in to the LightBridge self-service portal

-   Creating, viewing, and managing API keys

-   Understanding usage dashboards and endpoint configuration

4.2 IDE Integration

-   Configuring the API base URL and key in Roo Code (VS Code extension)

-   Configuring Zed IDE with the platform's custom endpoint

-   Configuring OpenCode as an OpenAI-compatible client

4.3 LibreChat Usage

-   Querying multiple models through the LibreChat browser interface

-   Using the GitHub Manager agent (MCP-powered)

-   Using the LightBridge API Key agent

4.4 Platform Vision Sharing

-   Explaining the long-term goals: self-hosted models, fine-tuning, RAG
    pipelines, usage analytics, and enterprise-grade privacy

5\. User Feedback Summary

5.1 General Sentiment

Across all sessions, the reception was notably positive. Common themes
in unprompted reactions included surprise at the breadth of what had
been built, and genuine interest in adopting the platform for everyday
work tasks. Several colleagues expressed that the platform is more
powerful than the tools they currently use.

A smaller subset of users raised concerns, primarily around data
privacy, rate limits, and stability of specific models.

5.2 Positive Highlights

  -----------------------------------------------------------------------
  **Feature / Aspect**                **Feedback**
  ----------------------------------- -----------------------------------
  Platform power & breadth            Users were "amazed by the work" ---
                                      the range of models and the
                                      self-service key management stood
                                      out

  Speed                               Models routed through Fireworks
                                      (e.g., Kimi) were noted as fast and
                                      responsive

  Multiple API keys                   Seen as a major improvement over
                                      the legacy Kivoyo system, which
                                      only offered a single shared key

  GitHub MCP agent                    Highly appreciated; users
                                      immediately saw the value for code
                                      review, PR management, and issue
                                      tracking

  LibreChat interface                 Described as simple and
                                      approachable for non-developer
                                      colleagues

  Practical utility                   Several colleagues immediately
                                      identified use cases in coding,
                                      writing, and research
  -----------------------------------------------------------------------

5.3 Issues & Concerns Raised

Issues are categorised by type below. Full backlog prioritisation
follows in Section 7.

Data Privacy

-   Multiple users were uncomfortable knowing their prompts and data are
    visible to platform administrators

-   This is the single most emotionally charged feedback theme --- it
    affected willingness to use the platform for sensitive work

-   Expectation: either strong access controls with audit trails, or
    explicit user-facing data handling policy

Rate Limits

-   Current limits were experienced as too restrictive for real
    experimentation

-   At least some users reverted to using Claude.ai or other external AI
    tools as a result

-   This directly undermines internal adoption until adjusted

Model Stability

-   Several models in the LibreChat UI are not functional or unreliable:

```{=html}
<!-- -->
```
-   Gemini models: mostly non-functional across the board

-   glm-5: silent failure / no response

-   gpt-5-mini, gpt-5-nano: reject parameters from some clients

-   gemini-3-flash: network timeout, stuck with no response

```{=html}
<!-- -->
```
-   Models visible in the UI but unavailable via API caused confusion
    ("UI/API mismatch")

-   Users who encountered broken models lost confidence in the platform
    overall

Agent Reliability

-   Both the GitHub Manager agent and the LightBridge API Key agent
    reported as having issues

-   Users could not complete intended workflows --- reduced perceived
    value of LibreChat vs. plain API access

Model Naming

-   Requests to stop renaming or aliasing models without transparency

-   Users want to know which model they are actually talking to

6\. Technical Findings

6.1 Gateway Integration (OpenCode / Roo Code)

A detailed compatibility audit was performed by one tester against the
camer.digital gateway endpoint. Three distinct layers of failure were
identified when using the gateway with OpenAI-compatible SDK clients:

-   Incomplete parameter translation: The gateway fails to strip or
    translate parameters like reasoningSummary and max_tokens before
    forwarding to certain backends, causing backend rejections

-   Response format inconsistency: Backends return slightly different
    response shapes; the gateway passes these through without
    normalisation, breaking AI SDK parsers (missing choices array,
    invalid delta objects)

-   Unreliable model routing: The /v1/models endpoint advertises models
    that fail when tool calling is included in the request

Root cause: The gateway is a third-party aggregation proxy routing to
Google Vertex AI, Fireworks, and OpenAI backends. Unlike AWS Bedrock (a
first-party managed service), it does not reliably normalise formats
across backends.

Models confirmed working with streaming + tool calling:

  ------------------------------------------------------------------------
  **Item**                   **Status**      **Notes**
  -------------------------- --------------- -----------------------------
  kimi-k2-instruct-0905      ✅ Working      Fireworks backend --- stable,
                                             full tool support

  kimi-k2-thinking           ✅ Working      Fireworks backend --- stable
                                             reasoning model

  deepseek-v3p2              ✅ Working      Fireworks backend --- stable

  minimax-m2p5               ✅ Working      Fireworks backend --- stable
  ------------------------------------------------------------------------

Models confirmed broken --- removed from active config:

  ------------------------------------------------------------------------
  **Item**                   **Status**      **Notes**
  -------------------------- --------------- -----------------------------
  gemini-3.1-pro /           ❌ Broken       Maps to non-existent Vertex
  flash-lite                                 AI preview endpoints

  gemini-3-pro /             ❌ Broken       Route not found when tools
  gemini-2-5-pro-reasoning                   included

  glm-5                      ❌ Broken       Silent failure with
                                             streaming + tools

  gemini-3-flash             ❌ Broken       Network timeout, no response

  gemini-2-5-flash-lite      ❌ Broken       Missing choices array ---
                                             breaks AI SDK parser

  gpt-5-nano / gpt-5-mini    ❌ Broken       Reject reasoningSummary param
                                             from OpenCode

  qwen3-vl-30b variants      ❌ Removed      Unusable quality in practice
  ------------------------------------------------------------------------

6.2 Tool Execution Failure (Roo Code / Streaming)

When using tool-augmented requests (e.g., read_file, edit_file) through
the gateway, the provider terminates the streaming connection at the
point of tool call detection. The platform effectively degrades to a
chatbot rather than a development agent. This is a P0 issue for IDE
users.

Recommended fix: Verify whether cogito-671b-v2-p1 (and other models)
correctly handle tool call streaming. Review provider-side timeout
configuration and implement proper tool call response handling in the
streaming layer.

6.3 Security Posture

  -------------------------------------------------------------------------
  **Item**                   **Status**      **Notes**
  -------------------------- --------------- ------------------------------
  TLS 1.2/1.3                ✅ Good         Modern cipher suites, strong
                                             encryption

  DNS Port 53 (dnsmasq 2.90) ❌ Exposed      P0 --- risk of DNS
                                             amplification / DoS attacks

  CORS Policy                ⚠️ Too          Access-Control-Allow-Origin:
                             permissive      \* --- restrict to
                                             camer.digital

  Security Headers           ❌ Missing      HSTS, CSP, X-Frame-Options,
                                             X-Content-Type-Options absent

  Authentication             ✅ Functional   API key auth working, Keycloak
                                             integration stable
  -------------------------------------------------------------------------

7\. UI Issues Backlog

The following UI issues were captured during user sessions. All are
non-critical to core functionality but materially affect user experience
and adoption.

  -----------------------------------------------------------------------
  **Issue**                             **Priority / Notes**
  ------------------------------------- ---------------------------------
  Enter key triggers submit             Low --- expected for some,
                                        surprising for others; needs
                                        consistent behaviour

  No password visibility toggle on      Low --- mismatch only discovered
  registration                          post-submission

  Notification button is dormant        Medium --- creates expectation of
                                        functionality that does not exist

  No theme toggle (dark/light mode)     Low --- frequently requested
                                        across all sessions

  Production gateway & analytics show   Medium --- UI signals system is
  no green status                       unhealthy even when functional

  Next/previous pagination fills entire Low --- poor use of space; should
  bottom half                           only appear when \>1 page

  Endpoints button only redirects to    Medium --- users expected
  API key list                          endpoint documentation or
                                        configuration

  API key refresh has unexpected        Medium --- confusing UX on the
  behaviour                             API key list page

  No logout button                      High --- basic session management
                                        missing from UI

  API key creation UI needs improvement Medium --- multiple users
                                        struggled with the flow

  Current API usage shows placeholder   High --- dashboard shows non-real
  values                                data, undermines trust

  Default page was API key page (fixed) Fixed

  Refresh token issues (fixed)          Fixed
  -----------------------------------------------------------------------

8\. What Was Accomplished This Sprint

Despite it being the first full-system deployment, the following
represent concrete achievements:

-   First production deployment of all platform components
    simultaneously --- gateway, LibreChat, LightBridge UI/backend,
    Authorino, MCPs, kServe

-   Successful end-to-end API key issuance and consumption by external
    clients (Roo Code, Zed, OpenCode)

-   Stable model serving for four confirmed models via Fireworks routing
    (Kimi K2, DeepSeek V3, MiniMax M2.5)

-   Two functional agents deployed in LibreChat: GitHub Manager and
    LightBridge API Key agent

-   Company-wide awareness raised: colleagues across the organisation
    now know the platform exists and how to begin using it

-   Comprehensive bug triage performed: both the compatibility audit
    (Report #5) and user sessions surfaced a well-structured backlog

-   Two bugs fixed during the sprint: default page routing, refresh
    token handling

9\. Remaining Work & Priorities

P0 --- Critical (Block wider adoption)

-   Fix tool execution / streaming termination in Roo Code and IDE
    clients

-   Block DNS port 53 on the production server (DoS risk)

-   Address data privacy concerns --- define and communicate data
    handling policy; implement prompt visibility controls

-   Fix agent issues: GitHub Manager and LightBridge agents both
    reported broken

P1 --- High (Needed for trust & usability)

-   Add logout button to LightBridge UI

-   Display real API usage values on dashboard (not placeholders)

-   Increase or calibrate rate limits to support genuine experimentation

-   Restrict CORS policy to authorised domains

-   Add missing security headers (HSTS, CSP, X-Frame-Options,
    X-Content-Type-Options)

-   Fix Gemini model routing or remove broken Gemini models from the UI

P2 --- Medium (Quality & developer experience)

-   Resolve notification button dormancy or remove the element

-   Fix endpoints button to serve documentation or useful routing
    information

-   Fix API key refresh page behaviour

-   Improve API key creation UI flow

-   Fix production gateway and analytics green status indicator

-   Write setup documentation for Zed IDE and other clients

-   Improve pagination controls on the API key list page

P3 --- Low (Polish)

-   Add password visibility toggle on registration form

-   Add dark/light theme toggle

-   Standardise enter key behaviour across forms

10\. Where This Fits in the Bigger Picture

The sprint represents the transition from build phase to early adoption
phase. The platform architecture is sound and the core value proposition
--- a self-hosted, privacy-respecting, multi-model AI gateway with
self-service access --- is clearly resonating with colleagues.

Several strategic directions were discussed during user sessions and are
worth naming explicitly as roadmap items:

-   Privacy-first positioning: On-premises model serving via kServe/vLLM
    (already partially deployed) is the path to prompt data never
    leaving the cluster. This directly addresses the most common concern
    raised this sprint.

-   RAG and knowledge base integration: GDrant (Vector DB) is already in
    the architecture. Connecting it to LibreChat agents for document Q&A
    is a near-term opportunity.

-   Analytics and usage visibility: Real-time usage dashboards, per-user
    and per-team quota management, and cost attribution are needed to
    make the platform viable at scale.

-   Competitive positioning: The platform's ability to aggregate
    multiple frontier models, serve open-source models locally, and
    provide enterprise-grade access control is a genuine differentiator
    versus commercial alternatives.

-   Expanded MCP ecosystem: The GitHub MCP was well received. Expanding
    to additional MCPs (Jira, Confluence, internal tooling) would
    significantly increase LibreChat's value proposition.

-   Model quality curation: The compatibility audit showed that only
    Fireworks-routed models are reliable at this stage. Short-term:
    restrict the UI to confirmed-working models. Long-term: build
    automated health-checking for model endpoints.

11\. Conclusion

This sprint successfully moved the AI-Ops platform from internal
development into its first real organisational contact. The response
validates the investment: colleagues across teams recognise the utility,
and several are ready to adopt the platform as a primary tool for
AI-assisted work.

The priority is clear: resolve the P0 issues (tool execution, privacy
controls, agent stability) to unlock the platform's value for developer
workflows. The UI and model reliability issues are tractable and
well-understood. With those addressed, the platform is well-positioned
for a broader internal launch.

*Document prepared from team field reports collected during the March
2026 internal rollout sprint.*