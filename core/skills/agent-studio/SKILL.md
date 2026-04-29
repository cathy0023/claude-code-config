---
name: agent-studio
description: "Create and manage AI Agents via agent-studio REST API. Search available tools, build agent specs, create drafts, and provide testing/publishing guidance."
---

# Agent Studio

Create AI Agents dynamically through the agent-studio API. This skill guides you through searching available tools, building a GeneratedAgentSpec, creating a draft agent, and providing API examples for testing and publishing.

## Prerequisites

Before starting, collect these configuration values from the user:

1. **BASE_URL** — agent-studio server address (default: `http://localhost:8000`)
2. **INTEGRATION_ID** — integration identifier (e.g. `cogrun_app`)
3. **TENANT_ID** — tenant identifier

Verify connectivity:

```bash
curl -sf --max-time 5 "${BASE_URL}/api/health"
```

If the health check fails, ask the user to confirm the server is running and the URL is correct.

## Workflow

### Phase 1: Understand Requirements

Ask the user:
- What should this agent do?
- Who is the target user?
- What tools/capabilities does it need?

Determine a valid `agent_name` (must match `^[a-z0-9][a-z0-9_-]{0,63}$`).

### Phase 2: Search Available Resources

**Always search the catalog first** before building a spec.

```bash
curl -s "${BASE_URL}/api/meta-agent/resources" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  | python3 -m json.tool
```

Present results to the user in natural language, grouped by category. For example:
- "Found 3 tools in the catalog: web search, knowledge base retrieval, and course creation."

**Do NOT expose internal fields** (resource_key, integration_id) to the user — use friendly names.

Confirm with the user which tools to bind.

### Phase 3: Build the Spec

Load `references/spec-schema.md` for the complete field reference.

Key rules:
1. **No `tools` field** — bind catalog tools via `selected_resources` only
2. **`selected_resources` first** — only use `generated_skills` when the catalog has no matching tool
3. **`extra="forbid"`** — do NOT add any undefined fields, or the API returns 400
4. Include at least 1 `smoke_tests` entry (recommended; 0 is allowed but will produce a warning)

Build the `GeneratedAgentSpec` JSON. Example structure:

```json
{
  "agent_name": "example-agent",
  "description": "One-line description",
  "system_prompt": "Full system prompt...",
  "model": "chat",
  "temperature": 0.3,
  "selected_resources": [
    {"resource_key": "web_search", "integration_id": "cogrun_app"}
  ],
  "generated_skills": [],
  "smoke_tests": [
    {"name": "basic", "user_message": "hello", "expected_behavior": "greets user"}
  ]
}
```

### Phase 4: Create the Draft

Submit the spec via API. **Important**: Write the spec JSON to a temporary file first to avoid shell injection from user-controlled fields (e.g. `system_prompt` containing single quotes).

```bash
# Write the complete request body to a temp file
cat <<'SPEC_EOF' > /tmp/agent-spec.json
{
  "spec_json": {
    "agent_name": "example-agent",
    "description": "One-line description",
    "system_prompt": "Full system prompt...",
    "smoke_tests": [
      {"name": "basic", "user_message": "hello", "expected_behavior": "greets user"}
    ]
  }
}
SPEC_EOF

# Submit via file reference
curl -s -X POST "${BASE_URL}/api/meta-agent/drafts" \
  -H "Content-Type: application/json" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  -d @/tmp/agent-spec.json | python3 -m json.tool
```

**On success**, extract and save:
- `draft_version_id` — needed for testing/publishing
- `agent_id`
- `agent_name`

**On 400 error**, check the error message:
- "Invalid spec" — check field names against `spec-schema.md` (remember: `extra="forbid"` at top level rejects unknown fields), fix, and retry once
- "Spec validation failed" — resource_key not found in catalog, or skill frontmatter invalid

**On same-name agent**: The REST API does NOT reject same-name agents. If an agent with the same name already exists, it reuses the existing agent record and creates a new draft version. If the agent was previously deleted (soft-delete), it gets reactivated. This is by design — no need to use a different name.

### Phase 5: Post-creation Guidance

After draft creation succeeds, inform the user and provide next steps.

Load `references/api-reference.md` for complete curl examples, then present:

1. **Draft trial chat** — test the agent interactively:
   ```bash
   curl -s -X POST "${BASE_URL}/api/meta-agent/drafts/${VERSION_ID}/chat" \
     -H "Content-Type: application/json" \
     -H "X-Integration-Id: ${INTEGRATION_ID}" \
     -H "X-Tenant-Id: ${TENANT_ID}" \
     -d '{"messages": [{"role": "user", "content": "Hello"}]}'
   ```

2. **Smoke tests** — run automated basic tests (note: current MVP only checks non-empty response):
   ```bash
   curl -s -X POST "${BASE_URL}/api/meta-agent/drafts/${VERSION_ID}/test" \
     -H "X-Integration-Id: ${INTEGRATION_ID}" \
     -H "X-Tenant-Id: ${TENANT_ID}" \
     | python3 -m json.tool
   ```

3. **Publish** — make the agent live:
   ```bash
   curl -s -X POST "${BASE_URL}/api/meta-agent/drafts/${VERSION_ID}/publish" \
     -H "X-Integration-Id: ${INTEGRATION_ID}" \
     -H "X-Tenant-Id: ${TENANT_ID}" \
     | python3 -m json.tool
   ```

If the user asks to publish, **confirm before executing**: "Are you sure you want to publish agent '{name}'? Once published, it will be available for all users."

### Phase 6: Integration Code (after publish)

After publishing, show the user how to call the agent.

**IMPORTANT**: Published dynamic agents are accessed via the **CogRun native API** (`/api/chat`) with the `agent` field, NOT the OpenAI-compatible endpoint. The OpenAI endpoint (`/api/v1/chat/completions`) strips extended fields and does not map `model` to agent name. Context headers (`X-Integration-Id`, `X-Tenant-Id`) are required for dynamic agent lookup.

**CogRun Native API (the correct way):**
```bash
curl -s -X POST "${BASE_URL}/api/chat" \
  -H "Content-Type: application/json" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  -d '{
    "agent": "{agent_name}",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

**Python (requests):**
```python
import requests

response = requests.post(
    f"{BASE_URL}/api/chat",
    headers={
        "X-Integration-Id": INTEGRATION_ID,
        "X-Tenant-Id": TENANT_ID,
    },
    json={
        "agent": "{agent_name}",
        "messages": [{"role": "user", "content": "Hello"}],
    },
)
print(response.json())
```

**Python (LangChain via CogRun native):**

Note: `ChatOpenAI` targets the OpenAI Chat Completions format. The CogRun native `/api/chat` endpoint is compatible with this format when `agent` is passed via `model_kwargs`. The `api_key` is not validated in local deployments; set a real key if your deployment requires authentication.

```python
import os
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    base_url=f"{BASE_URL}/api",
    model="{agent_name}",
    api_key=os.environ.get("COGRUN_API_KEY", "placeholder"),
    default_headers={
        "X-Integration-Id": INTEGRATION_ID,
        "X-Tenant-Id": TENANT_ID,
    },
    model_kwargs={"agent": "{agent_name}"},
)
```

## Additional Operations

These are triggered when the user explicitly requests them.

### List Agents

```bash
curl -s "${BASE_URL}/api/meta-agent/agents" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  | python3 -m json.tool
```

### View Agent Detail

```bash
curl -s "${BASE_URL}/api/meta-agent/agents/{agent_name}" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  | python3 -m json.tool
```

### Update Agent

1. First, fetch the current spec via agent detail API — note: this returns only the **published version's** spec. If the agent has no published version (draft-only), the spec will not be available via this endpoint.
2. Modify the spec based on user's requirements
3. Create a new draft with the updated spec via `POST /api/meta-agent/drafts` (using the same agent_name — the API will create a new version under the existing agent)
4. Follow the same test/publish flow

### Delete Agent

**Always confirm before deleting.** Inform the user: "This is a soft delete. The record is preserved, and creating an agent with the same name later will reactivate it."

```bash
curl -s -X DELETE "${BASE_URL}/api/meta-agent/agents/{agent_name}" \
  -H "X-Integration-Id: ${INTEGRATION_ID}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  | python3 -m json.tool
```

## Cross-Environment Sync (跨环境同步)

### 概述

在源环境通过 agent-studio 创建并发布 agent 后，可以通过 `GET /export` 将其导出为 bundle JSON 文件，保存到代码库中进行版本管理。在目标环境（如 staging、production）通过 `POST /import` 导入该 bundle，系统会自动完成创建与发布，无需手动重复配置。

### 使用流程

1. **源环境导出**：调用 `GET /api/meta-agent/agents/{agent_name}/export`，获取完整的 bundle JSON

   ```bash
   curl -s "${BASE_URL}/api/meta-agent/agents/{agent_name}/export" \
     -H "X-Integration-Id: ${INTEGRATION_ID}" \
     -H "X-Tenant-Id: ${TENANT_ID}" \
     -o agents/my-agent.bundle.json
   ```

2. **保存到代码库**：将 bundle 文件提交到代码仓库（文件位置由用户自行决定，例如 `agents/my-agent.bundle.json`）

3. **目标环境导入**：在目标环境调用 `POST /api/meta-agent/agents/import`，系统自动创建 agent 并发布

   ```bash
   curl -s -X POST "${BASE_URL}/api/meta-agent/agents/import" \
     -H "Content-Type: application/json" \
     -H "X-Integration-Id: ${INTEGRATION_ID}" \
     -H "X-Tenant-Id: ${TENANT_ID}" \
     -d @agents/my-agent.bundle.json | python3 -m json.tool
   ```

导入完成后，agent 即可通过 `/api/chat` 接口调用。若调用时返回 `AGENT_NOT_FOUND`，说明该环境尚未导入对应 bundle，导入后重试即可。

### Bundle 格式

导出的 bundle JSON 包含以下内容：

- **spec** — agent 核心定义（agent_name、system_prompt、selected_resources 等）
- **agent_config** — 运行时配置（max_tokens 等参数）
- **catalog_entries** — 工具依赖快照（记录 agent 使用的 tool catalog 条目）
- **fingerprint** — 内容指纹（基于 spec + config 计算的 SHA256 哈希，用于幂等检查）

### 幂等性

相同 fingerprint 的 bundle 重复导入时，系统会检测到目标环境已存在相同版本，返回 `already_up_to_date` 状态，不会创建新版本。这使得 CI/CD 流水线可以安全地在每次部署时执行导入操作，而不必担心产生重复数据。

### V1 限制

- 不支持批量导入 — 每次只能导入一个 agent bundle
- 不导出 `resource_type == "skill"` 的 catalog 资源 — skill 的路径依赖于本地文件系统，不可跨环境移植
- 目标环境需要预装 bundle 中引用的 tool Python 模块 — bundle 仅包含 catalog 元数据，不包含实际的工具代码

## Important Notes

- **Do NOT expose internal identifiers** (resource_key, integration_id, version_id, agent_id) to users unless they explicitly ask. Use natural language descriptions.
- **Do NOT call `POST /resources/sync`** unless the user reports missing resources. The catalog syncs automatically on server startup.
- All curl commands use `python3 -m json.tool` for readable output. If unavailable, use `jq .` as fallback.
- Replace `${BASE_URL}`, `${INTEGRATION_ID}`, `${TENANT_ID}`, `${VERSION_ID}` with actual values collected in Prerequisites.
