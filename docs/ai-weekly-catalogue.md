# AI Weekly — Presentation Topic Catalogue

This document is a living catalogue of presentation ideas for the **AI Weekly** sessions handled by the AI-Ops team. Anyone on the team can (and should) add entries. The goal is to build up a rich pool of well-thought-out topics so we're never scrambling when it's our turn to schedule a session.

**Contribution rhythm:** every team member adds at least one entry per week.

---

## How to Add an Entry

Copy the template below, fill it in, and add it under the [Catalogue](#catalogue) section. Entries are listed in reverse chronological order (newest first). Incomplete entries — i.e. those missing any required field — will be flagged during review.

> The **Full Proposal** section is optional but strongly encouraged if you feel strongly about a topic or want to make the case for prioritizing it.

---

## Entry Template

```markdown
---

### 🏷️ Title
<!-- A clear, engaging title. Think conference talk — specific and punchy. -->

**Added by:** @username  
**Date added:** YYYY-MM-DD  
**Status:** `Proposed` | `Scheduled` | `Presented`

---

#### 📝 Description
<!-- 3–5 sentences. What is this about, why is it relevant now, and what angle does the presentation take? -->

#### 🛠️ Technologies Involved
<!-- Bullet list of tools, frameworks, protocols, or concepts featured. -->
-
-

#### 🎯 Benefit to the Audience
<!-- What does someone walk away with? Be specific. -->

#### 🗂️ Outline
<!-- A structured breakdown of how the session would flow. -->
1.
2.
3.
4.
5.

#### 📄 Full Proposal *(optional)*
<!-- Expand on the description and flesh out the outline. A paragraph or two of genuine thinking beats a polished essay. -->
```

---

## Catalogue

---

### 🏷️ Meet the AI-Ops Team: What We Do and How We Can Help You

**Added by:** @Koufan-De-King  
**Date added:** 2026-03-22  
**Status:** `Proposed`

---

#### 📝 Description

Most people at the office have heard of the AI-Ops team but aren't quite sure what we actually do day-to-day — and more importantly, what we can do *for them*. This session is our chance to fix that. We'll walk through why the team exists, what problem we're solving at an organisational level, and give a clear, visual overview of the platform we're building and maintaining. No deep technical dives — this is a "here's the map" session, not a "here's how the engine works" one. We'll also share a glimpse of where we're headed next, and close with a quick demo of how any colleague can get started using our platform today.

#### 🛠️ Technologies Involved

- Converse AI Gateway (Envoy-based)
- LibreChat (chat interface)
- Arize Phoenix (observability)
- LightBridge (self-service API key portal)
- Authorino (authentication — mentioned in passing)
- Various AI model providers (OpenAI, Mistral, self-hosted models, etc.)

> ⚠️ This is a presentation-first session. No hands-on component beyond a brief live demo. Prior technical knowledge is not required from the audience.

#### 🎯 Benefit to the Audience

Colleagues will leave with a clear picture of what the AI-Ops team does, what infrastructure is available to them right now, and exactly how to get started — generating an API key and plugging it into a tool of their choice. They'll also know who to come to when they have AI-related needs or ideas, which is half the point.

#### 🗂️ Outline

1. **Opening** — Brief, informal intro to the session. Set the tone: this is a "get to know us" talk, not a lecture.
2. **Why does this team exist?** — The case for a centralised AI infrastructure hub: easier governance, consistent access, reduced duplication of effort across teams, and staying ahead of the curve on emerging AI tools and methodologies.
3. **Architecture overview** — A single, well-annotated diagram covering the full platform:
   - The Envoy AI Gateway as the central traffic hub
   - The model providers sitting behind it (cloud and self-hosted)
   - LibreChat as the primary chat interface for end users
   - Authorino handling authentication (no implementation details — just "it's there and it works")
   - Arize Phoenix for observability and usage monitoring
   - LightBridge: the self-service frontend and backend for API key management
4. **What's coming next** — A light, forward-looking segment. Tease upcoming additions (e.g. Anthropic models, new MCP integrations), framed as promises to the audience rather than a roadmap review.
5. **Live demo: getting started in 5 minutes** — A walkthrough of the one thing every attendee can do right now: log into LightBridge, generate an API key, and configure it as a provider in a tool of their choice.
6. **Q&A** — Open floor. Keep it informal.

#### 📄 Full Proposal

The AI-Ops team is still relatively new to most of the company, and that invisibility is a real problem — not because we need the spotlight, but because our whole value proposition depends on other teams actually knowing we exist and using what we build. A well-run AI Weekly session is one of the best opportunities we have to close that gap in one go, in front of a broad audience.

The architecture diagram is the centrepiece of this talk. It should be clean, readable at a glance, and annotated just enough that a non-technical attendee can point to a box and say "oh, that's the thing that handles my login." The goal isn't to impress anyone with complexity — it's to give people a mental model they'll retain. One good diagram, explained well, is worth more than twenty slides.

The "what's coming next" segment deserves particular care. It should feel like a conversation between colleagues, not a product roadmap presentation. Mentioning something concrete like Anthropic model availability is the kind of thing that makes people lean forward — it signals that the team is paying attention to what the rest of the company actually wants. Keep it brief and keep the energy light.

The LightBridge demo should be short enough that no one loses the thread, but complete enough that someone could replicate it alone afterward. The ideal outcome: at least one attendee generates their first API key during or immediately after the session.

---

## Presented Sessions

> Sessions that have already been delivered move here for reference.

| Date | Title | Presenter(s) |
|------|-------|--------------|
| —    | —     | —            |
