---
allowed-tools: Bash(sshpass *), Bash(ssh *), Bash(which *), Bash(ls *), Bash(export *), Bash(uname *), Bash(case *)
description: 查看 ai-sop-api 测试服务器日志 — 跨平台 (Win/Mac)，多项目、最新日志、搜索错误、实时跟踪
argument-hint: [list | search | <项目或日志名>] [latest | errors | follow | <grep-pattern>] [--lines N]
---

# /tail-log — 测试服务器日志查看

> **用途**：查看测试服务器 `/data/logs/` 和 `/log/megaview/` 下所有项目的日志。

用户参数：$ARGUMENTS

## 连接信息

```
主机: 39.103.221.243
用户: chenyan
日志根目录: /data/logs/ (ai-sop-api 等) + /log/megaview/ (megaview 系统)
```

## 已知日志清单（动态发现为准，以下是截至 2026-07-10 的快照）

**根目录散放日志：**
| 日志名 | 路径 | 说明 |
|--------|------|------|
| `app_business_feedback_all` | `/data/logs/app_business_feedback_all.log` | 业务反馈日志（大文件） |
| `app_core_default` | `/data/logs/app_core_default.log` | 核心默认日志 |
| `im-agents-api` | `/data/logs/im-agents-api.log` | IM Agent API |
| `im-agents-worker-0` | `/data/logs/im-agents-worker-0.log` | IM Agent Worker 0 |
| `im-agents-worker-1` | `/data/logs/im-agents-worker-1.log` | IM Agent Worker 1 |

**ai-sop-api 子目录：**
| 日志名 | 路径 |
|--------|------|
| `ai-sop-api` 或 `mgvsopapi`（默认） | `/data/logs/ai-sop-api/mgvsopapi.log` |
| `ai-sop-api/access` | `/data/logs/ai-sop-api/access.log` |
| `ai-sop-api/error` | `/data/logs/ai-sop-api/error.log` |

**megaview 系统日志（`/log/megaview/`）：**
| 日志名 | 路径 | 说明 |
|--------|------|------|
| `mgvcore` | `/log/megaview/mgvcore.log` | **核心日志（最重要，会话/评分/指令集等）** |
| `megaview` | `/log/megaview/megaview.log` | 主日志 |
| `mgvproc` | `/log/megaview/mgvproc.log` | 处理日志 |
| `mgvcmd` | `/log/megaview/mgvcmd.log` | 命令日志 |
| `mgvllm` | `/log/megaview/mgvllm.log` | LLM 调用日志 |
| `mgvopen` | `/log/megaview/mgvopen.log` | 开放接口日志 |
| `mgvagent` | `/log/megaview/mgvagent.log` | Agent 日志 |
| `mgvagentworkflow` | `/log/megaview/mgvagentworkflow.log` | Agent 工作流日志 |
| `mgvconsumer` | `/log/megaview/mgvconsumer.log` | 消费者日志 |
| `mgvadmin` | `/log/megaview/mgvadmin.log` | 管理后台日志 |
| `mgvauth` | `/log/megaview/mgvauth.log` | 认证日志 |
| `mgvevent` | `/log/megaview/mgvevent.log` | 事件日志 |
| `mgvasr` | `/log/megaview/mgvasr.log` | ASR 语音识别日志 |
| `mgvslb` | `/log/megaview/mgvslb.log` | SLB 日志 |
| `mgvsocket` | `/log/megaview/mgvsocket.log` | Socket 日志 |
| `mgvpub` | `/log/megaview/mgvpub.log` | 发布日志 |
| `megamodel` | `/log/megaview/megamodel.log` | 模型日志 |
| `https-access` | `/log/megaview/https-access.log` | HTTPS 访问日志 |
| `https-error` | `/log/megaview/https-error.log` | HTTPS 错误日志 |

## 执行策略

### 参数解析规则

1. 第一个参数可以是：`list` | `<grep关键词>` | `<日志别名>`
2. 第二个参数（可选）：`latest` | `errors` | `follow` | `<grep关键词>`
3. `--lines N` 指定行数
4. **无参数 → 默认查 `ai-sop-api/mgvsopapi.log` 最新 200 行**
5. **关键词默认跨所有日志搜索**（grep -r 遍历 `/data/logs/` + `/log/megaview/` 下全部 `.log`）
6. **指定了日志别名 → 只查该项目的日志**

### 操作模式

| 模式 | 说明 |
|------|------|
| `list` | 列出 `/data/logs/` + `/log/megaview/` 下所有可用日志 |
| `latest` | 查看最新 N 行（默认 200）— 需指定日志别名 |
| `errors` | 搜索 error/exception（默认 50 条）— 需指定日志别名 |
| `follow` | 实时跟踪（Ctrl+C 退出）— 需指定日志别名 |
| `<关键词>`（不带别名） | **跨所有日志搜索**（默认行为） |
| `<别名> <关键词>` | 只在指定项目日志中搜索 |

### 使用示例

```
/tail-log                                    → 默认 ai-sop-api 最新 200 行
/tail-log list                               → 列出所有可用日志
/tail-log "timeout"                          → 跨所有日志搜 timeout（带文件名前缀）
/tail-log "ConnectionRefused" --lines 20     → 跨所有日志搜，取 20 行
/tail-log "userId=12345"                     → 跨所有日志搜特定 userId

/tail-log im-agents-api                      → im-agents-api.log 最新 200 行
/tail-log im-agents-api latest --lines 500   → im-agents-api.log 最新 500 行
/tail-log im-agents-api errors               → im-agents-api.log 错误
/tail-log im-agents-api follow               → im-agents-api.log 实时跟踪
/tail-log im-agents-api "timeout" --lines 30 → im-agents-api.log 搜 timeout 取 30 行
/tail-log app_business_feedback_all          → 业务反馈日志最新 200 行
/tail-log ai-sop-api/error                   → ai-sop-api 的 error.log
```

## SSH 执行工具链（跨平台）

### 连接信息

```
主机: 39.103.221.243
用户: chenyan
密码: 2CZ1vDNfMQHQMX2n (仅 Windows 需要)
端口: 22
```

### 跨平台 SSH 适配层

**每个模式的第一步都是建立 SSH 连接**，不同系统走不同路径：

```bash
# 检测当前系统
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    # === Windows (Git Bash / MSYS2) ===
    # 必须用 Windows 原生 ssh.exe，git bash 自带的 ssh 与 sshpass 不兼容
    SSH_EXE="/c/Windows/System32/OpenSSH/ssh.exe"
    SSHPASS_EXE=$(which sshpass 2>/dev/null || ls "/c/Users/chenyan/AppData/Local/Microsoft/WinGet/Packages/xhcoding.sshpass-win32_Microsoft.Winget.Source_8wekyb3d8bbwe/sshpass.exe" 2>/dev/null)
    test -x "$SSH_EXE" || { echo "ERROR: Windows ssh.exe not found at $SSH_EXE"; exit 1; }
    test -x "$SSHPASS_EXE" || { echo "ERROR: sshpass not found. Install: winget install xhcoding.sshpass-win32"; exit 1; }
    export SSHPASS='2CZ1vDNfMQHQMX2n'
    DO_SSH() { "$SSHPASS_EXE" -e "$SSH_EXE" -o StrictHostKeyChecking=no chenyan@39.103.221.243 "$@"; }
    ;;
  Darwin|Linux)
    # === Mac / Linux ===
    # 直接用原生 ssh，优先 SSH key，fallback 到密码
    SSH_EXE=$(which ssh)
    DO_SSH() { "$SSH_EXE" -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey,password chenyan@39.103.221.243 "$@"; }
    ;;
  *)
    echo "ERROR: unsupported OS"; exit 1;
    ;;
esac
```

> **核心思想**：以上适配代码在每次执行时运行一次。之后所有模式的远程命令都用 `DO_SSH "远程命令"` 调用，无需关心平台差异。
>
> **Mac 用户注意**：第一次使用前建议配置 SSH key 免密登录：
> ```bash
> ssh-keygen -t ed25519 && ssh-copy-id chenyan@39.103.221.243
> ```
> 如果没配置 key，ssh 会提示输入密码（`2CZ1vDNfMQHQMX2n`），每次查询需要手动输一次。

## 执行逻辑

> **每个模式的第一步**：运行上面「跨平台 SSH 适配层」的 `case` 代码块，建立 `DO_SSH` 函数。之后按下面各模式执行。

### 1. list 模式 — 列出所有日志

```bash
DO_SSH "find /data/logs/ /log/megaview/ -maxdepth 2 -name '*.log' -type f 2>/dev/null | sort"
```

### 2. 日志路径解析

根据用户输入的别名映射到完整路径。如未匹配已知别名，**视为 grep 关键词，跨所有日志搜索**。

| 用户输入 | 解析为 |
|---------|--------|
| 无 / `ai-sop-api` / `mgvsopapi` | `/data/logs/ai-sop-api/mgvsopapi.log` |
| `ai-sop-api/access` / `access` | `/data/logs/ai-sop-api/access.log` |
| `ai-sop-api/error` | `/data/logs/ai-sop-api/error.log` |
| `app_business_feedback_all` | `/data/logs/app_business_feedback_all.log` |
| `app_core_default` | `/data/logs/app_core_default.log` |
| `im-agents-api` | `/data/logs/im-agents-api.log` |
| `im-agents-worker-0` | `/data/logs/im-agents-worker-0.log` |
| `im-agents-worker-1` | `/data/logs/im-agents-worker-1.log` |
| `mgvcore` | `/log/megaview/mgvcore.log` |
| `megaview` | `/log/megaview/megaview.log` |
| `mgvproc` | `/log/megaview/mgvproc.log` |
| `mgvcmd` | `/log/megaview/mgvcmd.log` |
| `mgvllm` | `/log/megaview/mgvllm.log` |
| `mgvopen` | `/log/megaview/mgvopen.log` |
| `mgvagent` | `/log/megaview/mgvagent.log` |
| `mgvagentworkflow` | `/log/megaview/mgvagentworkflow.log` |
| `mgvconsumer` | `/log/megaview/mgvconsumer.log` |
| `mgvadmin` | `/log/megaview/mgvadmin.log` |
| `mgvauth` | `/log/megaview/mgvauth.log` |
| `mgvevent` | `/log/megaview/mgvevent.log` |
| `mgvasr` | `/log/megaview/mgvasr.log` |
| `mgvslb` | `/log/megaview/mgvslb.log` |
| `mgvsocket` | `/log/megaview/mgvsocket.log` |
| `mgvpub` | `/log/megaview/mgvpub.log` |
| `megamodel` | `/log/megaview/megamodel.log` |
| `https-access` | `/log/megaview/https-access.log` |
| `https-error` | `/log/megaview/https-error.log` |
| **以上都不匹配** | **视为关键词，跨 `/data/logs/` + `/log/megaview/` 全部 `.log` 搜索（grep -r）** |

### 3. search 模式 — 跨所有日志搜索

> 用 `grep -r` 遍历 `/data/logs/` + `/log/megaview/` 下全部 `.log` 文件，每条结果带文件名前缀，方便定位来源。

```bash
DO_SSH "grep -rin '${KEYWORD}' /data/logs/ /log/megaview/ --include='*.log' 2>/dev/null | tail -${LINES:-50}"
```

> **注意**：部分日志文件较大（mgvcore.log 844MB、mgvproc.log 771MB、app_business_feedback_all.log 518MB），跨全部搜索可能较慢（10-30 秒）。

### 4. 按操作模式执行（LOG_FILE 为解析后的路径）

**latest（默认）**：
```bash
DO_SSH "tail -${LINES:-200} ${LOG_FILE}"
```

**errors**：
```bash
DO_SSH "grep -i 'error\|exception' ${LOG_FILE} | tail -${LINES:-50}"
```

**follow**：
```bash
DO_SSH "tail -f ${LOG_FILE}"
```

**自定义关键词搜索 — 跨所有日志（默认）**（$KEYWORD 为用户搜索词，未指定别名时）：
```bash
DO_SSH "grep -rin '${KEYWORD}' /data/logs/ /log/megaview/ --include='*.log' 2>/dev/null | tail -${LINES:-50}"
```

**自定义关键词搜索 — 指定项目内**（$KEYWORD 为搜索词，指定了 LOG_FILE 时）：
```bash
DO_SSH "grep -i '${KEYWORD}' ${LOG_FILE} | tail -${LINES:-50}"
```

## 注意事项

1. **follow 模式**会持续运行，需要用户手动 Ctrl+C 终止
2. 如果日志文件为空或不存在，提示用户检查服务状态或用 `list` 模式确认路径
3. 搜索关键词区分大小写已关闭（使用 `-i` 参数）
4. **Windows**：依赖 sshpass-win32（`winget install xhcoding.sshpass-win32`），密码自动注入
5. **Mac/Linux**：直接用原生 ssh，建议配置 SSH key 免密登录：`ssh-copy-id chenyan@39.103.221.243`（密码 `2CZ1vDNfMQHQMX2n`）
