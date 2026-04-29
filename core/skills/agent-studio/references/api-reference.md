# Agent Studio API Reference

## Base URL

Default: `http://localhost:8000`

Configurable via environment variable. All examples use `${BASE_URL}` as the variable name.

## Authentication / Context Headers

All requests should include context headers. The middleware extracts these with **highest priority** (over body/query params):

| Header | Required | Description |
|--------|----------|-------------|
| `X-Integration-Id` | Yes (for most endpoints) | Integration identifier |
| `X-Tenant-Id` | Yes (for most endpoints) | Tenant identifier |
| `X-User-Id` | No | User identifier (for audit) |
| `Content-Type` | Yes (for POST) | `application/json` |

## Health Check

```bash
curl -sf --max-time 5 "${BASE_URL}/api/health"
```

Response: `{"status": "ok", ...}`

---

## 1. Search Resources

List available tools and skills from the catalog.

**Endpoint:** `GET /api/meta-agent/resources`

**Query Parameters:**

| Param | Type | Description |
|-------|------|-------------|
| `integration_id` | `str` | Filter by integration (also accepted via header) |
| `resource_type` | `str` | Filter: `"tool"` or `"skill"` |
| `tags` | `str` | Comma-separated tag filter |
| `keyword` | `str` | Keyword search |
| `category` | `str` | Category filter |

**Example:**

```bash
curl -s "${BASE_URL}/api/meta-agent/resources" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  | python3 -m json.tool
```

**Response:**

```json
{
  "resources": [
    {
      "id": 1,
      "integration_id": "cogrun_app",
      "resource_type": "tool",
      "resource_key": "web_search",
      "name": "Web Search",
      "description": "Real-time web search",
      "tags": ["general", "search", "web"],
      "category": "general"
    }
  ],
  "categories": [
    {"key": "general", "display_name": "General", "count": 1}
  ],
  "total": 1
}
```

---

## 2. Create Draft

Create a new agent draft from a GeneratedAgentSpec.

**Endpoint:** `POST /api/meta-agent/drafts`

**Request Body:**

```json
{
  "spec_json": { ... },
  "integration_id": "optional-if-header-set",
  "tenant_id": "optional-if-header-set"
}
```

`spec_json` must be a valid GeneratedAgentSpec object (see `spec-schema.md`).

**Example:**

```bash
curl -s -X POST "${BASE_URL}/api/meta-agent/drafts" \
  -H "Content-Type: application/json" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  -H "X-User-Id: ${USER_ID}" \
  -d '{
    "spec_json": {
      "agent_name": "my-agent",
      "description": "My custom agent",
      "system_prompt": "You are a helpful assistant.",
      "smoke_tests": [
        {"name": "basic", "user_message": "hello", "expected_behavior": "greets user"}
      ]
    }
  }' | python3 -m json.tool
```

Note: `X-User-Id` is optional but recommended — it populates the `created_by` field for audit trail.

**Success Response (200):**

```json
{
  "draft_version_id": 42,
  "agent_id": 10,
  "agent_name": "my-agent",
  "version": 1,
  "spec": { ... },
  "warnings": []
}
```

**Common Error Responses (400):**

| Error | Cause |
|-------|-------|
| `"Invalid spec: ... extra inputs are not permitted"` | Unknown field in top-level spec (`extra="forbid"`) |
| `"Invalid spec: agent_name must match ..."` | Invalid agent_name format |
| `"Spec validation failed: ... conflicts with a static agent"` | agent_name conflicts with built-in static agent (e.g. `agent-studio`, `default`) |
| `"Spec validation failed: Resource not found: ..."` | `selected_resources` references a resource_key not in the catalog |
| `"Spec validation failed: Skill '...' missing valid YAML frontmatter"` | `generated_skills` entry has invalid or missing YAML frontmatter |
| `"integration_id and tenant_id required"` | Missing context headers or body fields |

**Notes:**
- If an agent with the same name already exists (active), the API reuses the existing agent record and creates a new draft version under it.
- If an agent with the same name was previously soft-deleted, it will be reactivated and a new draft version created.
- The REST API does NOT reject same-name agents — this differs from the tool-layer `create_agent` which blocks active duplicates.

---

## 3. List Drafts

List agents with pending draft versions.

**Endpoint:** `GET /api/meta-agent/drafts`

**Query Parameters:** `integration_id`, `tenant_id`

**Example:**

```bash
curl -s "${BASE_URL}/api/meta-agent/drafts?integration_id=${INTEGRATION_ID}&tenant_id=${TENANT_ID}" \
  | python3 -m json.tool
```

---

## 4. Draft Trial Chat

Chat with a draft agent for testing before publishing.

**Endpoint:** `POST /api/meta-agent/drafts/{version_id}/chat`

**Request Body:** OpenAI-compatible chat format.

**Example:**

```bash
curl -s -X POST "${BASE_URL}/api/meta-agent/drafts/${VERSION_ID}/chat" \
  -H "Content-Type: application/json" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  -d '{
    "messages": [{"role": "user", "content": "Hello, what can you do?"}]
  }' | python3 -m json.tool
```

**Notes:**
- The draft is temporarily loaded into the registry for this request.
- Supports streaming via `"stream": true`.

---

## 5. Run Smoke Tests

Execute predefined smoke tests against a draft agent.

**Endpoint:** `POST /api/meta-agent/drafts/{version_id}/test`

**Query Parameters:** `integration_id`, `tenant_id` (optional if derivable from version)

**Example:**

```bash
curl -s -X POST "${BASE_URL}/api/meta-agent/drafts/${VERSION_ID}/test" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  | python3 -m json.tool
```

**Response:**

```json
{
  "version_id": 42,
  "total": 2,
  "passed": 2,
  "failed": 0,
  "all_passed": true,
  "cases": [
    {
      "name": "basic",
      "passed": true,
      "response": "Hello! I can help you with...",
      "error": null,
      "duration_ms": 1200
    }
  ]
}
```

**Note:** Current MVP pass criterion is "non-empty response". The `expected_behavior` field is for documentation only and is not semantically matched.

---

## 6. Publish Draft

Publish a draft version to make it a live agent. Idempotent.

**Endpoint:** `POST /api/meta-agent/drafts/{version_id}/publish`

**Example:**

```bash
curl -s -X POST "${BASE_URL}/api/meta-agent/drafts/${VERSION_ID}/publish" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  | python3 -m json.tool
```

**Response:**

```json
{
  "version_id": 42,
  "agent_name": "my-agent",
  "status": "published",
  "message": "Published successfully"
}
```

**Notes:**
- Already-published versions return success (idempotent).
- Only `"draft"` status versions can be published.

---

## 7. List Agents

List dynamic agents for an integration/tenant pair.

**Endpoint:** `GET /api/meta-agent/agents`

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `integration_id` | `str` | — | Required |
| `tenant_id` | `str` | — | Required |
| `status` | `str` | `"active"` | Filter: `"active"` or `"deleted"` |
| `limit` | `int` | `100` | Max results |
| `offset` | `int` | `0` | Pagination offset |

**Example:**

```bash
curl -s "${BASE_URL}/api/meta-agent/agents?integration_id=${INTEGRATION_ID}&tenant_id=${TENANT_ID}" \
  | python3 -m json.tool
```

**Response:**

```json
{
  "agents": [
    {
      "id": 10,
      "integration_id": "cogrun_app",
      "tenant_id": "tenant_001",
      "agent_name": "my-agent",
      "status": "active",
      "current_version": 1,
      "created_at": "2026-03-11T10:00:00"
    }
  ],
  "total": 1
}
```

---

## 8. Agent Detail

Get detailed information about a specific agent.

**Endpoint:** `GET /api/meta-agent/agents/{agent_name}`

**Query Parameters:** `integration_id`, `tenant_id`

**Example:**

```bash
curl -s "${BASE_URL}/api/meta-agent/agents/my-agent?integration_id=${INTEGRATION_ID}&tenant_id=${TENANT_ID}" \
  | python3 -m json.tool
```

**Response:**

```json
{
  "agent": {
    "id": 10,
    "agent_name": "my-agent",
    "status": "active",
    "current_version": 1,
    ...
  },
  "published_version": { ... },
  "versions": [
    {"id": 42, "version": 1, "version_status": "published", ...}
  ],
  "resources": [...],
  "skills": [...]
}
```

---

## 9. Delete Agent

Soft-delete an agent and unload it from the registry.

**Endpoint:** `DELETE /api/meta-agent/agents/{agent_name}`

**Example:**

```bash
curl -s -X DELETE "${BASE_URL}/api/meta-agent/agents/my-agent" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  | python3 -m json.tool
```

**Response:**

```json
{
  "message": "Agent 'my-agent' deleted"
}
```

**Important:** This is a **soft delete**. The database record is preserved. If you later create a new agent with the same name, the old record will be reactivated.

---

## 10. Export Agent Bundle

Export a published agent as a portable bundle for cross-environment sync.

**Endpoint:** `GET /api/meta-agent/agents/{agent_name}/export`

**Query Parameters:** `integration_id`, `tenant_id`

**Example:**

```bash
curl -s "${BASE_URL}/api/meta-agent/agents/my-agent/export" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  | python3 -m json.tool
```

**Response:**

```json
{
  "bundle_version": "1.0",
  "exported_at": "2026-03-12T10:00:00Z",
  "source_env": "",
  "spec": { ... },
  "agent_config": { "max_tokens": 4096, ... },
  "catalog_entries": [
    {
      "resource_key": "web_search",
      "integration_id": "cogrun_app",
      "name": "Web Search",
      "description": "Real-time web search",
      "resource_type": "tool",
      "import_path": "cogrun.tools.web_search.WebSearchTool",
      "tags_json": ["general", "search"],
      "schema_json": null
    }
  ],
  "version": 3,
  "fingerprint": "a1b2c3d4e5f6...64-char-hex..."
}
```

**Notes:**
- Only published agents can be exported. Returns 404 if agent has no published version.
- Catalog entries with `resource_type == "skill"` are excluded (skill paths are not portable).
- The bundle file location is decided by the user.

---

## 11. Import Agent Bundle

Import an agent from a portable bundle. Automatically creates/updates and publishes the agent.

**Endpoint:** `POST /api/meta-agent/agents/import`

**Request Body:** The bundle JSON (same format as export output).

**Example:**

```bash
curl -s -X POST "${BASE_URL}/api/meta-agent/agents/import" \
  -H "Content-Type: application/json" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  -d @agents/my-agent.bundle.json | python3 -m json.tool
```

**Success Response (200):**

```json
{
  "status": "imported",
  "agent_name": "my-agent",
  "version": 1
}
```

**Idempotent Response (200):**

```json
{
  "status": "already_up_to_date",
  "agent_name": "my-agent"
}
```

**Validation Error (400):**

```json
{
  "status": "validation_failed",
  "agent_name": null,
  "version": null,
  "errors": ["Resource not found: web_search"]
}
```

**Notes:**
- Idempotent: If the existing published version has the same fingerprint, returns `already_up_to_date`.
- Tool catalog entries from the bundle are upserted, but existing entries' `import_path` is NOT updated (security).
- The imported agent is automatically published after creation.

---

## 12. Sync Resources (Manual)

Manually trigger catalog synchronization. Normally not needed — the server syncs on startup.

**Endpoint:** `POST /api/meta-agent/resources/sync`

**Example:**

```bash
curl -s -X POST "${BASE_URL}/api/meta-agent/resources/sync" \
  | python3 -m json.tool
```

---

## Using Published Agents

After publishing, dynamic agents are accessible via the **CogRun native chat API** (`/api/chat`).

**IMPORTANT**: The OpenAI-compatible endpoint (`/api/v1/chat/completions`) strips extended fields in OpenAI mode — the `model` field is NOT mapped to the dynamic agent name. You MUST use the CogRun native API with the `agent` field. Context headers (`X-Integration-Id`, `X-Tenant-Id`) are required for dynamic agent lookup.

### CogRun Native API (recommended)

```bash
curl -s -X POST "${BASE_URL}/api/chat" \
  -H "Content-Type: application/json" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  -d '{
    "agent": "my-agent",
    "messages": [{"role": "user", "content": "Hello"}]
  }' | python3 -m json.tool
```

### Python (requests)

```python
import requests

response = requests.post(
    f"{BASE_URL}/api/chat",
    headers={
        "X-Integration-Id": INTEGRATION_ID,
        "X-Tenant-Id": TENANT_ID,
    },
    json={
        "agent": "my-agent",
        "messages": [{"role": "user", "content": "Hello"}],
    },
)
print(response.json())
```

### Python (LangChain)

Note: The `api_key` is not validated in local deployments; set a real key if your deployment requires authentication.

```python
import os
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    base_url=f"{BASE_URL}/api",
    model="my-agent",
    api_key=os.environ.get("COGRUN_API_KEY", "placeholder"),
    default_headers={
        "X-Integration-Id": INTEGRATION_ID,
        "X-Tenant-Id": TENANT_ID,
    },
    model_kwargs={"agent": "my-agent"},
)
response = llm.invoke("Hello")
print(response.content)
```

---

## Error Codes

### AGENT_NOT_FOUND

Returned when calling `/api/chat` or `/api/v1/chat/completions` with an agent that doesn't exist in the registry.

**CogRun Native API (`/api/chat`):**

```json
HTTP 404
{
  "detail": {
    "code": "AGENT_NOT_FOUND",
    "message": "Agent 'my-agent' not found in this environment",
    "agent_name": "my-agent"
  }
}
```

**OpenAI Compatible API (`/api/v1/chat/completions`):**

```json
HTTP 404
{
  "error": {
    "message": "Agent 'my-agent' not found in this environment",
    "type": "not_found_error",
    "param": null,
    "code": "AGENT_NOT_FOUND"
  }
}
```

**Cross-env sync usage:** When receiving `AGENT_NOT_FOUND`, the client can import the agent bundle via `POST /api/meta-agent/agents/import` and retry the request.
