# /sls-log — 阿里云 SLS 生产日志查询

## 目标

为 megaview-server 生产环境提供一个 `/sls-log` 自定义指令，通过阿里云 SLS CLI (`aliyunlog`) 直连日志服务，在 Claude Code 中一键查询生产日志，无需登录阿里云控制台。

## 范围

- **生产环境 (main profile)**：project=`megaview-server`, logstore=`server`, region=`cn-zhangjiakou`
- **暂不覆盖测试环境**：测试已有 `/tail-log`（SSH 到 39.103.221.243），不重复建设

## 指令接口

```
/sls-log                                        → 最近 1h, 最新 100 条
/sls-log latest --hours 3                       → 最近 3h, 100 条
/sls-log errors                                 → 最近 1h, level: ERROR, 100 条
/sls-log errors --hours 6                       → 最近 6h, level: ERROR, 100 条
/sls-log "timeout"                              → 最近 1h, 搜 timeout, 100 条
/sls-log "userId=12345" --hours 24 --lines 200  → 最近 24h, 200 条
/sls-log --from "2026-07-10 10:00:00" --to "2026-07-10 12:00:00"  → 精确时间范围
```

**默认值**：`--hours 1`, `--lines 100`, project=`megaview-server`, logstore=`server`

## 前置环境准备

### Step 1 — 检查 CLI 是否安装

```bash
aliyunlog --version 2>/dev/null || echo "NEED_INSTALL"
```

### Step 2 — 自动安装（如未安装）

```bash
pip3 install aliyun-log-python-sdk aliyun-log-cli -U --no-cache
```

### Step 3 — 检查配置文件

```bash
cat ~/.aliyunlogcli 2>/dev/null || echo "NEED_CONFIG"
```

### Step 4 — 自动生成配置

写入 `~/.aliyunlogcli`（AK 为只读权限，从 `D:\download\阿里云日志服务CLI.md` 中获取）：

```toml
[main]
access-id = <从阿里云日志服务CLI.md获取>
access-key = <从阿里云日志服务CLI.md获取>
region-endpoint = cn-zhangjiakou.log.aliyuncs.com
sts-token =
```

### Step 5 — 验证

```bash
aliyunlog --version
```

## 核心查询命令（固定模板）

```bash
aliyunlog log get_log_all \
    --project="megaview-server" \
    --logstore="server" \
    --from_time="${FROM_TIME}" \
    --to_time="${TO_TIME}" \
    --query="${QUERY}" \
    --offset=0 \
    --size_lines=${LINES} \
    --reverse=true \
    --format-output=json 2>/dev/null
```

## 参数映射

| 用户输入 | FROM_TIME | TO_TIME | QUERY |
|---------|-----------|---------|-------|
| 无参/latest | now - 1h | now | `*` |
| latest --hours N | now - Nh | now | `*` |
| errors | now - 1h | now | `level: ERROR` |
| errors --hours N | now - Nh | now | `level: ERROR` |
| "关键词" | now - 1h | now | 关键词 |
| --from/--to | 用户指定 | 用户指定 | 按上述规则 |

时间格式: `2026-07-10 15:30:00+8:00`

## 结果展示约定

Claude 收到 JSON 结果后：
1. 总结：条数、时间范围、ERROR 数量
2. 异常归类：按 source/level 做 Top 分布
3. 默认不输出原始 JSON（用户明确要求时除外）

## 文件位置

`C:\Users\chenyan\claude-code-config\core\commands\sls-log.md`

## 工具权限

```yaml
allowed-tools: Bash(python3 *), Bash(pip3 *), Bash(aliyunlog *), Bash(cat *), Bash(date *), Bash(which *)
```
