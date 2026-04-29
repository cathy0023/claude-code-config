# GeneratedAgentSpec Schema Reference

## Overview

`GeneratedAgentSpec` defines the complete specification for a dynamic agent.
The **top-level** model uses `extra="forbid"` — any field not listed in the top-level schema will cause a 400 error. Sub-schemas (`ResourceRef`, `GeneratedSkillSpec`, `SmokeTestCase`) do NOT have this restriction.

## Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `agent_name` | `str` | Yes | — | Agent identifier. Must match `^[a-z0-9][a-z0-9_-]{0,63}$` |
| `description` | `str` | Yes | — | One-line description of the agent |
| `system_prompt` | `str` | Yes | — | Full system prompt for the agent |
| `agents_md` | `str` | No | `""` | AGENTS.md content (optional behavioral guidance) |
| `model` | `str` | No | `""` | Model category or specific model name. Categories: `"thinking"` (complex reasoning), `"instinct"` (fast response), `"chat"` (daily conversation). Empty = default (chat) |
| `temperature` | `float` | No | `0.3` | Sampling temperature |
| `selected_resources` | `list[ResourceRef]` | No | `[]` | Tools from the catalog to bind |
| `generated_skills` | `list[GeneratedSkillSpec]` | No | `[]` | Custom skill definitions (text-only guidance) |
| `smoke_tests` | `list[SmokeTestCase]` | No | `[]` | Validation test cases (at least 1 recommended; 0 is allowed but produces a warning) |

## Sub-schemas

### ResourceRef

Binds an existing tool from the resource catalog.

```json
{
  "resource_key": "web_search",
  "integration_id": "cogrun_app",
  "binding_alias": null
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `resource_key` | `str` | Yes | The tool's key in the catalog |
| `integration_id` | `str` | Yes | The integration that owns the tool |
| `binding_alias` | `str \| null` | No | Optional alias for the tool binding |

### GeneratedSkillSpec

A text-only behavioral skill (NOT an executable tool).

```json
{
  "name": "answer-style",
  "description": "Guide the agent to answer in a specific style",
  "skill_content": "---\nname: answer-style\ndescription: Answer style guide\n---\n\nAlways answer concisely..."
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `str` | Yes | Skill identifier |
| `description` | `str` | Yes | What this skill does |
| `skill_content` | `str` | Yes | Full SKILL.md content with YAML frontmatter |

### SmokeTestCase

```json
{
  "name": "basic-greeting",
  "user_message": "Hello, what can you do?",
  "expected_behavior": "Agent introduces itself and lists capabilities"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `str` | Yes | Test case name |
| `user_message` | `str` | Yes | User input to send |
| `expected_behavior` | `str` | No | Description of expected agent behavior (for documentation; current MVP only checks non-empty response) |

## Critical Rules

1. **No `tools` field** — binding tools MUST use `selected_resources`. Using a `tools` field causes a 400 error.

2. **`selected_resources` over `generated_skills`** — if a capability exists in the catalog as a `[tool]`, bind it via `selected_resources`. Only use `generated_skills` for pure text guidance that has no catalog equivalent.

3. **`extra="forbid"` (top-level only)** — do NOT add any fields not listed in this top-level schema. The API will reject the request with a 400 error. Sub-schemas (ResourceRef, GeneratedSkillSpec, SmokeTestCase) are more lenient.

4. **`agent_name` format** — must match `^[a-z0-9][a-z0-9_-]{0,63}$`. Examples: `web-searcher`, `qa-assistant`, `course_designer01`.

5. **`agent_name` must not conflict with static agents** — names like `agent-studio`, `default` are reserved by the static registry and will cause a validation error.

6. **`smoke_tests` is recommended but not required** — 0 tests will produce a warning but will NOT block draft creation.

## Complete Example

```json
{
  "agent_name": "web-searcher",
  "description": "A web search assistant that helps users find information online",
  "system_prompt": "You are a web search assistant. When users ask questions, use the web_search tool to find relevant information and provide concise, accurate answers with sources.",
  "model": "chat",
  "temperature": 0.3,
  "selected_resources": [
    {
      "resource_key": "web_search",
      "integration_id": "cogrun_app"
    }
  ],
  "generated_skills": [],
  "smoke_tests": [
    {
      "name": "basic-search",
      "user_message": "Search for today's tech news",
      "expected_behavior": "Calls web_search tool and returns search results"
    }
  ]
}
```

## Minimal Example (no tools)

```json
{
  "agent_name": "greeting-bot",
  "description": "A friendly greeting bot",
  "system_prompt": "You are a friendly greeting bot. Always respond warmly and helpfully.",
  "smoke_tests": [
    {
      "name": "greet",
      "user_message": "Hello",
      "expected_behavior": "Responds with a friendly greeting"
    }
  ]
}
```
