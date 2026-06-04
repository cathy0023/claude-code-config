---
allowed-tools: Bash(sshpass *), Bash(which sshpass)
description: 查看 ai-sop-api 测试服务器日志 — 支持查看最新日志、搜索错误、实时跟踪、自定义命令
argument-hint: [latest | errors | follow | <grep-pattern>] [--lines N]
---

# /tail-log — 测试服务器日志查看

> **项目限定**：此命令用于查看 ai-sop-api 测试服务器日志。通过 SSH 连接远程服务器执行命令。

用户参数：$ARGUMENTS

## 连接信息

```
主机: 39.103.221.243
用户: chenyan
日志路径: /data/logs/ai-sop-api/mgvsopapi.log
```

## 执行策略

根据 `$ARGUMENTS` 决定执行的操作（无参数时默认 `latest`）：

| 参数 | 说明 |
|------|------|
| `latest` | 查看最新 200 行日志 |
| `errors` | 搜索最近的 error/exception（最新 50 条） |
| `follow` | 实时跟踪日志（Ctrl+C 退出） |
| `<关键词>` | 自定义 grep 搜索（如 `tail-log "NullPointerException"`） |
| `--lines N` | 指定行数（默认 latest=200, errors=50） |

解析参数规则：
1. 第一个非 `--lines` 的参数作为操作类型或搜索关键词
2. `--lines N` 设置显示行数
3. 无参数 → `latest`

## SSH 命令模板

所有命令基于以下模板：

```bash
sshpass -p '2CZ1vDNfMQHQMX2n' ssh -o StrictHostKeyChecking=no chenyan@39.103.221.243 "<command>"
```

## 执行逻辑

### 1. 前置检查：确认 sshpass 已安装

```bash
which sshpass || echo "SSHPASS_NOT_FOUND"
```

如果输出 `SSHPASS_NOT_FOUND`，提示用户安装：
- Windows: `choco install sshpass` 或 `scoop install sshpass`
- macOS: `brew install hudochenkov/sshpass/sshpass`
- Linux: `sudo apt install sshpass`

### 2. 根据参数执行对应命令

**latest（默认）**：
```bash
sshpass -p '2CZ1vDNfMQHQMX2n' ssh -o StrictHostKeyChecking=no chenyan@39.103.221.243 "tail -${LINES:-200} /data/logs/ai-sop-api/mgvsopapi.log"
```

**errors**：
```bash
sshpass -p '2CZ1vDNfMQHQMX2n' ssh -o StrictHostKeyChecking=no chenyan@39.103.221.243 "grep -i 'error\|exception' /data/logs/ai-sop-api/mgvsopapi.log | tail -${LINES:-50}"
```

**follow**：
```bash
sshpass -p '2CZ1vDNfMQHQMX2n' ssh -o StrictHostKeyChecking=no chenyan@39.103.221.243 "tail -f /data/logs/ai-sop-api/mgvsopapi.log"
```

**自定义关键词搜索**（$KEYWORD 为用户输入的搜索词）：
```bash
sshpass -p '2CZ1vDNfMQHQMX2n' ssh -o StrictHostKeyChecking=no chenyan@39.103.221.243 "grep -i '${KEYWORD}' /data/logs/ai-sop-api/mgvsopapi.log | tail -${LINES:-50}"
```

## 使用示例

```
/tail-log                    → 查看最新 200 行
/tail-log latest             → 查看最新 200 行
/tail-log latest --lines 500 → 查看最新 500 行
/tail-log errors             → 搜索最近的 error/exception
/tail-log errors --lines 100 → 搜索最近 100 条错误
/tail-log follow             → 实时跟踪日志
/tail-log "timeout"          → 搜索包含 timeout 的日志
/tail-log "userId" --lines 30 → 搜索包含 userId 的最近 30 行
```

## 注意事项

1. **follow 模式**会持续运行，需要用户手动 Ctrl+C 终止
2. SSH 密码硬编码在命令中（测试服务器，非生产环境）
3. 如果日志文件为空或不存在，会提示用户检查服务状态
4. 搜索关键词区分大小写已关闭（使用 `-i` 参数）
