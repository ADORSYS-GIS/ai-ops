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

### 🏷️ Creating a Personalized Learning Skill with Claude

**Added by:** @Koufan-De-King  
**Date added:** 2026-03-22  
**Status:** `Proposed`

---

#### 📝 Description

Most people use Claude the same way every session — starting from scratch, re-explaining their background, their preferred level of detail, how they like examples framed. But Claude can do better than that. This session walks through a workflow where you have a genuine learning conversation with Claude on a topic of your choice, and then — once you've noticed what clicked and what didn't — you ask Claude to distil your learning style and preferences into a reusable *skill*: a structured prompt document that Claude can load in any future session to teach you anything, exactly the way you absorb it best. The result is a personal learning assistant that gets more tailored the more you refine it, without any coding or tooling required.

#### 🛠️ Technologies Involved

- Claude (claude.ai or any API-connected interface)
- Claude's custom skills / system prompt mechanism
- Markdown (for authoring and storing the skill file)
- Any Claude-compatible client (claude.ai, LibreChat, Cursor, etc.)

#### 🎯 Benefit to the Audience

Attendees will walk away knowing how to turn Claude into a genuinely personalised tutor — one that reflects their own learning style rather than a generic one. Concretely, they'll understand what a learning skill looks like, how to prompt Claude to build one from a real conversation, and how to store and reuse it across sessions and tools. It's a low-effort, high-return workflow anyone can adopt the same day.

#### 🗂️ Outline

1. **Opening: the problem with starting from scratch every time** — A quick, relatable framing of why "just ask Claude" isn't always enough. Every session is stateless. Claude doesn't know you prefer holistic overviews before details, or that analogies land better for you than abstract definitions, or that you like a one-liner takeaway at the end of every section. You end up re-teaching Claude about yourself, over and over.

2. **What is a learning skill?** — Introduce the concept: a skill is a short, structured markdown document that captures your learning preferences, communication style expectations, and the output format you want Claude to consistently produce. It lives in a file, gets loaded into Claude's context, and turns any future learning session into one that feels tailor-made. Show a real example — the `teach-me-tech` skill — and walk through what's in it and why each part matters.

3. **Live demo part 1: a learning conversation** — Pick a concrete technical topic (e.g. Kubernetes taints and tolerations, or how an LLM attention mechanism works) and have a genuine learning exchange with Claude on screen. Narrate what's happening: when Claude's explanation lands, when it doesn't, when you ask for a different angle. This is the raw material the skill will be built from.

4. **Live demo part 2: extracting the skill** — Ask Claude, right there in the same conversation, to reflect on the exchange and write a reusable learning skill based on what it observed about how you engaged. Show the output. Walk through it line by line — what it captured, what you might tweak, and how to save it.

5. **Reusing the skill: a before/after comparison** — Open a fresh Claude session. Ask about a new topic without the skill. Then load the skill and ask the same question. Let the difference speak for itself.

6. **Practical tips and pitfalls** — How to refine the skill over time, how to keep it from getting too long, and how to use it across different clients (claude.ai Projects, LibreChat system prompts, Cursor rules, etc.).

7. **Q&A** — Open floor.

#### 📄 Full Proposal

The deeper idea behind this session is that most people are dramatically underusing Claude as a learning tool — not because they lack curiosity, but because they haven't thought about the *interface* between their learning style and the model's defaults. Claude is extraordinarily adaptable, but it adapts on demand, not automatically. The skill workflow is essentially a way of making that adaptation persistent.

What makes this session particularly well-suited for the AI Weekly format is that it's both immediately practical and genuinely surprising to most people. The concept of "teaching Claude how to teach you" isn't something most users have encountered, even among developers who use Claude daily. The live demo is the session's strongest asset — watching a skill get generated in real time, from a real conversation, makes the whole thing feel tangible rather than abstract.

The `teach-me-tech` skill is the perfect worked example to anchor the talk. It was built after a real session on Kubernetes taints, tolerations, and affinities — a non-trivial topic that required a specific kind of explanation (ontology first, then practicals; contrasts with known concepts; analogies welcome but never as a substitute for direct explanation; one-liner takeaways at the end of dense paragraphs). The skill captures all of that, and the before/after comparison of a Claude session with and without it loaded is immediately convincing.

One thing worth being deliberate about in the talk: the skill isn't magic, and it isn't permanent without maintenance. As your understanding deepens, your learning needs change. Part of the workflow is knowing when to revisit and refine the skill — and Claude can help with that too. Mentioning this keeps expectations honest and frames the skill as a living document rather than a one-time artifact.

The session should close with everyone in the room feeling like they could go home, have a learning conversation with Claude about something they've been meaning to understand better, and come out of it with their own skill file. That's the bar.

---

---

### 🏷️ Meet the AI-Ops Team: What We Do and How We Can Help You

**Added by:** @Koufan-De-King  
**Date added:** 2026-03-22  
**Status:** `Presented`

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
| 2026-03-23 | Meet the AI-Ops Team: What We Do and How We Can Help You | @Koufan-De-King |
