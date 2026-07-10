---
allowed-tools: Bash(python3 *), Bash(pip3 *), Bash(aliyunlog *), Bash(cat *), Bash(date *), Bash(which *)
description: 阿里云 SLS 生产日志查询 — 查 megaview-server/server (cn-zhangjiakou 生产环境)
argument-hint: [latest | errors | <搜索关键词>] [--hours N] [--lines N] [--from <time> --to <time>]
---

# /sls-log — 阿里云 SLS 生产日志查询

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
