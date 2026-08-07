---
allowed-tools: Bash(python3 *), Bash(pip3 *), Bash(aliyunlog *), Bash(cat *), Bash(date *), Bash(which *)
description: 阿里云 SLS 生产日志查询 — 查 megaview-server/server (cn-zhangjiakou 生产环境)，含 trace_id 链路排查工作流
argument-hint: [latest | errors | <搜索关键词>] [--hours N] [--lines N] [--from <time> --to <time>]
---

# /sls-log — 阿里云 SLS 生产日志查询

> **⚠️ 重要认知（2026-08 教训沉淀）**：
> `aliyunlog log get_log_all` CLI 存在已知 bug —— 用 `--query="*"` 会 hang/超时，用具体关键词可能静默返回 0（但数据其实存在）。
> **遇到"关键词查不到、全量又超时"的矛盾时，立即切换 Python SDK 直连**（见下文「SDK 直连方案」），不要反复用 CLI 试。
> 排查"某会话/某请求的完整链路"时，标准流程是 **先定位 trace_id，再沿 trace_id 展开**（见「trace_id 链路排查工作流」）。

> **用途**：通过阿里云 SLS CLI 直连日志服务，查询 `megaview-server` 生产环境的 `server` logstore。

用户参数：$ARGUMENTS

## 连接信息

```
Project:  megaview-server
Logstore: server
Region:   cn-zhangjiakou
Profile:  main (~/.aliyunlogcli)
环境:     生产
```

## 前置检查：确保 CLI 可用

每次执行前，按顺序检查并自动补齐：

### 1. 检查 aliyunlog CLI

```bash
aliyunlog --version 2>/dev/null || echo "NEED_INSTALL"
```

### 2. 如果需要，安装 CLI

```bash
pip3 install aliyun-log-python-sdk aliyun-log-cli -U --no-cache
```

### 3. 检查配置文件

```bash
cat ~/.aliyunlogcli 2>/dev/null || echo "NEED_CONFIG"
```

### 4. 如果需要，生成配置文件

写入 `~/.aliyunlogcli`（AK 为只读权限，从 `D:\download\阿里云日志服务CLI.md` 中获取）：

```toml
[main]
access-id = <从阿里云日志服务CLI.md获取>
access-key = <从阿里云日志服务CLI.md获取>
region-endpoint = cn-zhangjiakou.log.aliyuncs.com
sts-token =
```

### 5. 再次验证

```bash
aliyunlog --version
```

## 参数解析规则

1. 第一个参数（可选）：`latest` | `errors` | `<搜索关键词>`
2. `--hours N`：时间窗口（往前推 N 小时），默认 1
3. `--lines N`：返回条数，默认 100
4. `--from <time>` / `--to <time>`：精确时间范围，指定后覆盖 `--hours`
5. **无参数 → latest，最近 1 小时，100 条**

## 操作模式

| 模式 | 说明 |
|------|------|
| `latest`（默认） | 查询最近 N 小时的日志 |
| `errors` | 搜索 level: ERROR |
| `<关键词>` | 全文搜索指定关键词 |
| `--from` / `--to` | 精确时间范围查询 |

### 使用示例

```
/sls-log                                              → 最近 1h，100 条
/sls-log latest --hours 3                             → 最近 3h，100 条
/sls-log latest --hours 2 --lines 200                 → 最近 2h，200 条
/sls-log errors                                       → 最近 1h 的 ERROR 日志
/sls-log errors --hours 6                             → 最近 6h 的 ERROR
/sls-log errors --hours 24 --lines 200                → 最近 24h 的 ERROR，200 条
/sls-log "timeout"                                    → 最近 1h 搜 timeout
/sls-log "userId=12345" --hours 24                    → 最近 24h 搜 userId
/sls-log --from "2026-07-10 10:00:00" --to "2026-07-10 12:00:00"  → 时间范围
```

### 实战案例（排查"某会话的 LLM 完整输入"）

> 案例背景：查 conv_id=498992109（org396）在 7-15 跑会话纪要时发给 LLM 的完整 prompt。

**① 定位 trace**（用户给"会话ID + 团队ID + 日期"，先全文搜，不用 trace 也能找到）：
```
/sls-log "498992109" --from "2026-07-15 17:30:00" --to "2026-07-15 17:40:00"
```
命中 `conv HandleSummaryProProcCall finish ... convId=498992109, orgId=396, begin=2026-07-15 17:36:29`，取该日志 `trace_id=NXYR4jgGnQHcKRY6Tz3CkH`。

**② 沿 trace 展开**（用 SDK，时间窗 18:03-18:06 之类，5-10 分钟）：
```
query='trace_id: NXYR4jgGnQHcKRY6Tz3CkH'
```
统计 appname 分布（mgvcore/agentworkflow/mgvllm），确认链路完整。

**③ 提取 LLM 输入**：
- `do achat params` → 请求参数（model/source/org/entity_id）
- `MgvSopSummaryArgs` → 完整问题定义（含 Enum）
- `get_conv_summary_result` → 每次调用的 questions 数
- `[DoConvInstructionSet] split` → 指令集数量（N 个提取 + M 个总结）

**④ 完整原文**：缓存命中时 mgvllm 不打 `data:{messages}`，需查 `gpt_record_{0,1,2}` 表（`entity_id=<会话ID> AND source='sop_conv_summary'`）。

## 参数映射表

| 用户输入 | FROM_TIME | TO_TIME | QUERY |
|---------|-----------|---------|-------|
| 无参/latest | `now - 1h` | `now` | `*` |
| latest --hours N | `now - Nh` | `now` | `*` |
| errors | `now - 1h` | `now` | `level: ERROR` |
| errors --hours N | `now - Nh` | `now` | `level: ERROR` |
| "关键词" | `now - 1h` (`--hours N`) | `now` | 关键词原文 |
| --from/--to | 用户指定值 | 用户指定值 | `*` 或 `level: ERROR` 或 关键词 |

> 时间格式统一为：`2026-07-10 15:30:00+8:00`
> 当前时间使用 `date` 命令获取，向前推算使用 `date -d` 计算。

## 核心查询命令（固定模板）

所有查询最终执行：

```bash
aliyunlog log get_log_all \
    --project="megaview-server" \
    --logstore="server" \
    --from_time="<FROM_TIME>" \
    --to_time="<TO_TIME>" \
    --query="<QUERY>" \
    --offset=0 \
    --reverse=true \
    --format-output=json,no_escape 2>/dev/null | json_lines_limit <LINES>
```

> **重要**：`get_log_all` 没有 `--size_lines` 参数，返回所有匹配结果。行数限制通过管道截断实现。
> 使用 `json,no_escape` 避免中文/特殊字符被转义，方便阅读。
> **CLI 支持人类可读时间别名**：`FROM_TIME`/`TO_TIME` 可直接写 `"1 hour ago"` / `"now"`，无需 `date` 命令计算。

## 执行逻辑

### Step A — 解析参数，确定 FROM_TIME / TO_TIME / QUERY / LINES

1. 从 $ARGUMENTS 中提取 `--lines` 值，默认 100
2. 从 $ARGUMENTS 中提取 `--hours` 值，默认 1
3. 检查是否有 `--from` 和 `--to`：
   - **有**：直接使用，去掉结尾的 `+8:00` 如果用户没写则补上
   - **没有**：计算当前时间和 N 小时前的时间
4. 确定 QUERY：
   - 第一个参数是 `errors` → `level: ERROR`
   - 第一个参数是 `latest` 或无参 → `*`
   - 第一个参数是其他字符串 → 该字符串原样作为查询词

### Step B — 确定时间（如果没有指定 --from/--to）

SLS CLI 支持人类可读时间别名，无需 `date` 命令转换：

```
--hours 1  →  from_time="1 hour ago"  to_time="now"
--hours 3  →  from_time="3 hours ago" to_time="now"
--hours 24 →  from_time="24 hours ago" to_time="now"
```

直接传入 CLI 即可。也支持精确时间格式 `"2026-07-10 15:30:00+8:00"`（用户指定 `--from/--to` 时使用）。

### Step C — 执行查询

将 Step A/B 得到的值填入模板，通过管道截断到指定行数。

**行数截断方式**：`get_log_all` 返回的是 JSON 数组，无法直接用 `head`（会截断 JSON 结构）。两种处理方式：

1. **直接执行不打截断**（推荐）：行数少时 SLS 返回可控，收到后 Claude 按需展示前 N 条
2. **jmes-filter 过滤**：`--jmes-filter="[0:<LINES>]"` 只取前 N 条（如果 CLI 版本支持）

实际上 `get_log_all` 会一次性返回所有日志到 stdout，数量很大时管道本身有自然缓冲。**建议执行时不截断，让 Claude 解析 JSON 后按 `--lines` 展示前 N 条**。

### Step D — 结果展示

接收 JSON 输出后，做以下处理：

1. **提取摘要**：总条数、时间范围、query 条件
2. **ERROR 统计**：如果有 `level: ERROR` 字段，统计数量
3. **异常归类**：按日志中的 source/level/消息关键词 做 Top 分布
4. **默认不输出原始 JSON**，用户明确要求时才输出

## Python SDK 直连方案（CLI 失灵时的首选）

当 `aliyunlog log get_log_all` 出现「关键词 0 条但 `*` 超时」的矛盾时，**不要再用 CLI 反复试**，直接切 Python SDK：

```python
# ⚠️ 示例代码不含真实凭据。实际运行时从 ~/.aliyunlogcli 读取 AK/SK（见"前置检查"），切勿硬编码。
# 读取方式参考：
#   import tomllib
#   with open('/Users/<user>/.aliyunlogcli','rb') as f: cfg = tomllib.load(f)
#   acc = cfg['main']; endpoint=acc['region-endpoint']; ak=acc['access-id']; sk=acc['access-key']
python3 << 'EOF'
import sys
sys.path.insert(0, '/Users/<user>/.local/pipx/venvs/aliyun-log-cli/lib/python3.14/site-packages')
from aliyun.log import LogClient
from aliyun.log import GetLogsRequest

# 从 ~/.aliyunlogcli 读配置，避免硬编码密钥
client = LogClient('<region-endpoint>', '<ACCESS_ID>', '<ACCESS_KEY>')  # 替换为真实值（从 ~/.aliyunlogcli 获取）
from_time = <epoch_秒>   # 用 python3 -c "from datetime import datetime,timezone,timedelta; tz=timezone(timedelta(hours=8)); print(int(datetime.strptime('2026-07-16 15:17:00','%Y-%m-%d %H:%M:%S').replace(tzinfo=tz).timestamp()))" 换算
to_time   = <epoch_秒>
req = GetLogsRequest('megaview-server', 'server', from_time, to_time, '', query='<QUERY>', line=500, offset=0, reverse=True)
res = client.get_logs(req)
for q in res.get_logs():
    d = dict(q.get_contents())
    print('['+str(d.get('time',''))+'] app='+str(d.get('appname',''))+' trace='+str(d.get('trace_id','')))
    print('  uri='+str(d.get('uri',''))+' msg:', str(d.get('message',''))[:500])
    print('---')
EOF
```

**关键点**：
- 时间用 epoch 秒（本地 +8 时区），SLS 的 `time` 字段是纳秒级 ISO，但查询参数用秒
- `query` 支持 `trace_id: xxx`、`appname: mgvllm and "data:{"` 等组合
- 返回的 log 是 `QueriedLog` 对象，用 `dict(q.get_contents())` 取字段
- `get_logs` 一次最多 500 条（`line`），数据多要缩小时间窗或加过滤

## trace_id 链路排查工作流（查具体会话/请求的标准方法）

> **核心方法论**：megaview 各服务间日志靠 `trace_id` 串联。查"某个会话跑批时的完整链路/LLM 输入"，标准流程是 **先定位 trace_id，再沿 trace_id 展开全部相关日志**。

### Step 1 — 用业务标识（会话ID/团队ID/日期）定位 trace_id

```bash
# 用最可信的业务信息做全文搜索（会话ID 没有独立索引字段，走全文）
# 时间窗取业务日期当天；如当天查不到，扩大前后 2-3 天
QUERY="<会话ID> and <关键词>"    # 关键词可选：HandleSummaryProProcCall / conv_summary / score_rule 等
```

通过命中日志里的 `trace_id` 字段拿到 trace。

**⚠️ ID 类型辨析（本环节最容易踩坑）**：
| 日志中的 ID | 含义 | 注意 |
|---|---|---|
| `conversation_id` / `conv_id` | **真实会话 ID** | 用户常给的"会话 ID"指这个 |
| `ai_process_id` | AI 处理任务 ID | **≠ 会话 ID**！同一条链路里两者不同 |
| `entity_id` | 实体 ID（mgvllm 侧） | 会话纪要场景 = conversation_id |
| `organization_id` / `org_id` | 团队 ID | 用于交叉验证归属 |

**排查时若搜到的日志里 `ai_process_id=<用户给的ID>`，不要直接认定这就是会话**——先看有没有 `conv_id`/`conversation_id`，用它核对团队 ID 和日期是否对得上。

### Step 2 — 沿 trace_id 展开全链路

```python
# 时间窗取 trace 命中时间的前后 5-10 分钟
req = GetLogsRequest('megaview-server', 'server', from_time, to_time, '',
                     query='trace_id: <TRACE_ID>', line=1000, offset=0, reverse=True)
```

先统计 appname 分布确认覆盖哪些服务，再按需过滤：
- `trace_id: xxx and appname: mgvcore` → 业务编排日志（`HandleSummaryProProcCall`、`MgvSopSummaryArgs`）
- `trace_id: xxx and appname: agentworkflow` → 算法服务（`do achat params`、`begin do request`、`get_conv_summary_result`）
- `trace_id: xxx and appname: mgvllm` → LLM 服务（`data:{messages}` 完整 prompt、`aget_gpt_record` 缓存查询）

### Step 3 — 提取 LLM 输入

- **请求参数**：agentworkflow 的 `do achat params={...}`（model/source/organization_id/entity_id/transaction_id）
- **问题定义**：mgvcore 的 `MgvSopSummaryArgs`（完整 `InstructionSetId/QuestionName/AnswerDescription/Enum`）
- **完整 prompt 原文**：
  - 非缓存命中：mgvllm 的 `data:[{'role':'system',...}]` 日志（`chat.py:80` 打印）
  - **缓存命中时**：`data:{messages}` 不打印，完整原文只在 **`gpt_record_{0,1,2}` 表**（mgvpub 库）的 `prompt` 字段，查询条件 `entity_id=<会话ID> AND source='sop_conv_summary' AND organization_id=<团队ID>`
- **指令集拆分**：`[DoConvInstructionSet] split ... len(infoExtractInstructionSets)=N,len(fullSummaryInstructionSets)=M` 确认一共几次调用

### Step 4 — 交叉验证

拿到的会话 ID / 团队 ID / 跑批时间，必须和用户给的信息核对一致，**不一致就是 trace 定位错了**，回到 Step 1。

## 注意事项

1. SLS 查询有延迟：写入后通常 1-3 秒可查
2. 时间格式支持两种：人类可读 `"1 hour ago"` / `"now"` 或精确格式 `"2026-07-10 15:30:00+8:00"`（精确格式必须带 `+8:00` 时区后缀）
3. `--format-output=json,no_escape` 保证输出可解析且中文不转义
4. `2>/dev/null` 过滤掉 progress bar 等干扰输出
5. `get_log_all` **没有** `--size_lines` 参数，返回全部匹配结果（通过 `--query` 精确化来减少数据量）
6. 如查询返回空，提示用户扩大时间范围（`--hours`）或调整关键词
7. 如 CLI 报错，检查 `~/.aliyunlogcli` 配置是否正确，或 AK 是否过期
8. **超大结果处理**：如果日志量巨大（>1MB），使用 `--query` 精确过滤（如 `level: ERROR`、`appname: mgvcore`）缩小范围
9. SLS 日志字段结构：`appname`, `level`, `time`, `message`, `host`, `request_id`, `trace_id`, `uri`, `method`, `spend_time` 等
10. **「关键词查不到 + 全量超时」= 工具 bug，不是数据不存在**，立即用 Python SDK 直连（见上文）
11. **一个会话纪要有多个指令集 = 多次 LLM 调用**：`[DoConvInstructionSet] split ... len(infoExtractInstructionSets)=N` 说明 N 个提取类指令集，每个指令集一次独立 LLM 调用（每次带该指令集的问题列表），不要只查一次调用
12. **索引字段有限**：`message` 是全文索引，`conv_id`/`ai_process_id`/`conversation_id` 都不是 key-value 索引字段，必须走全文搜索（`query="<ID>"`），不能写 `conv_id: 123`（会报 `not config as key value config`）
