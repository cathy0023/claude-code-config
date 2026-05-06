---
allowed-tools: Bash(uv venv), Bash(uv pip *), Bash(uv run *), Bash(export *), Bash(curl *), Bash(uvicorn *), Bash(test *), Bash(grep *)
description: 启动 ai-sop-api 本地开发环境 — 安装依赖、设置环境变量、启动服务（仅限 ai-sop-api 项目）
argument-hint: [--install-only | --env-only | --start-only | --full]
---

# /dev-start — 本地开发环境一键启动

> **项目限定**：此命令仅限在 `ai-sop-api` 项目下使用。如果当前工作目录不是 ai-sop-api，立即停止并提示用户切换到正确项目。

## 项目检测（必须首先执行）

在执行任何步骤之前，先验证当前是否在 ai-sop-api 项目中：

```bash
test -f pyproject.toml && test -f app/main.py || echo "NOT_AI_SOP_API"
```

- 如果输出包含 `NOT_AI_SOP_API`，**立即停止**，告知用户："此命令仅限 ai-sop-api 项目使用，请切换到 ai-sop-api 项目目录后再试。"
- 如果命令成功（无输出），继续执行后续步骤。

---

根据参数执行对应的启动步骤。无参数时默认 `--full`（全部执行）。

用户参数：$ARGUMENTS

## 执行策略

根据 `$ARGUMENTS` 决定执行哪些步骤：
- `--install-only`：仅执行步骤 1（安装依赖）
- `--env-only`：仅执行步骤 2（设置环境变量）
- `--start-only`：仅执行步骤 3（启动服务）
- `--full` 或空：依次执行步骤 1 → 2 → 3

每个步骤执行前先说明即将做什么，执行后展示输出结果。

---

## 步骤 1：安装依赖

```bash
uv venv
uv pip install asyncpg valkey pyjwt fastapi uvicorn orjson httpx pydantic python-multipart aiofiles pynsq python-consul
uv pip install aiohttp boto3 apscheduler dashscope langchain langchain-core langgraph langchain-text-splitters google-api-python-client python-docx pydub oss2 alibabacloud-docmind-api20220711 deepmerge concurrent-log-handler pymysql cachetools tomli volcengine-python-sdk dashvector rich typer email-validator asyncmy
```

注意：uvloop 不支持 Windows，跳过它安装其余依赖，服务仍可正常运行。

## 步骤 2：设置环境变量

> **凭据安全**：此步骤从项目根目录的 `.env` 文件加载环境变量。请确保 `.env` 文件存在且已填入开发环境凭据（参考 `.env.example` 模板）。

先加载 `.env` 文件：

```bash
test -f .env && export $(grep -v '^#' .env | xargs) || echo "WARNING: .env not found, using environment defaults"
```

然后设置非敏感的默认值（可被 `.env` 覆盖）：

```bash
export POSTGRES__HOST="${POSTGRES__HOST:-127.0.0.1}"
export POSTGRES__PORT="${POSTGRES__PORT:-6432}"
export POSTGRES__USER="${POSTGRES__USER:-postgres}"
export POSTGRES__DATABASE="${POSTGRES__DATABASE:-megaview}"
export VALKEY__HOST="${VALKEY__HOST:-127.0.0.1}"
export VALKEY__PORT="${VALKEY__PORT:-6379}"
export ALIYUN_OSS__ENDPOINT="${ALIYUN_OSS__ENDPOINT:-https://oss-cn-zhangjiakou.aliyuncs.com}"
export USE_CONSUL=false
```

以下变量**必须**在 `.env` 中设置（无默认值）：

| 变量 | 说明 |
|------|------|
| `POSTGRES__PASSWORD` | PostgreSQL 密码 |
| `VALKEY__PASSWORD` | Valkey/Redis 密码 |
| `DASHSCOPE__API_KEY` | 阿里云 DashScope API Key |
| `DASHVECTOR__API_KEY` | DashVector API Key |
| `DASHVECTOR__ENDPOINT` | DashVector 端点地址 |
| `DOUBAO__ARK_API_KEY` | 豆包 ARK API Key |
| `ALIYUN_OSS__ACCESS_KEY_ID` | 阿里云 OSS Access Key ID |
| `ALIYUN_OSS__ACCESS_KEY_SECRET` | 阿里云 OSS Access Key Secret |
| `ALIYUN_OSS__BUCKET_NAME` | 阿里云 OSS Bucket 名称 |
| `NSQ__LOOKUPD_ADDR` | NSQ Lookup 地址 |
| `JWT__SOP_SECRET_KEY` | JWT SOP 签名密钥 |

注意：`USE_CONSUL=false` 是必须的，否则启动时会尝试连接 Consul 失败。

## 步骤 3：启动服务

```bash
uv run uvicorn app.main:app --reload --reload-dir app --port 5001
```

启动后在终端可以看到 uvicorn 的启动日志。服务地址：`http://127.0.0.1:5001`

## 验证连通性

服务启动后，在新的终端中执行：

```bash
curl http://127.0.0.1:5001/api/health
# 应返回 {"status":"ok"}
```

## 测试用 JWT Token（CI 路由认证）

> **安全提示**：测试 JWT Token 应从 `.env` 中的 `CI_TEST_JWT` 读取，不要硬编码在配置文件中。

用法：`Authorization: Bearer $CI_TEST_JWT`（token 格式：iss=mgvcore, aud=["im-agents-api"], sub="userId:orgId:workspaceId"）

## Key Gotchas

1. **uvloop 不支持 Windows**：安装依赖时跳过 uvloop
2. **USE_CONSUL=false**：本地开发必须关闭 Consul
3. **CI 路由认证**：使用 CIJWTAuth，token 格式为 mgvcore（iss=mgvcore, aud=["im-agents-api"], sub="userId:orgId:workspaceId"）
4. **SOP 路由认证**：非 CI 的 SOP 路由使用不同的 JWT 密钥
5. **凭据管理**：所有敏感凭据从 `.env` 加载，不硬编码在命令文件中
6. **端口冲突**：如果 5001 端口被占用，修改 `--port` 参数
