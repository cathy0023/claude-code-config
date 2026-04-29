# Claude Code Config — Design Spec

> 将当前电脑上的 Claude Code 全局配置（rules、agents、commands、skills、hooks、scripts）打包为可分享的 GitHub 仓库，方便其他电脑或其他人一键安装。

## 1. 目标

- 把 `~/.claude/` 下的通用配置资产提取为独立 GitHub 仓库
- 提供一键安装脚本，支持模块化选装
- 不包含任何个人化内容（凭据、memory、服务器配置）
- 安装时不覆盖用户已有文件

## 2. 仓库结构

```
claude-code-config/
├── install.sh                    # 主安装脚本
├── uninstall.sh                  # 卸载脚本
├── README.md                     # 使用说明
├── core/                         # 核心模块（必装）
│   ├── rules/
│   │   └── common/               # 10 个通用规则
│   │       ├── agents.md
│   │       ├── coding-style.md
│   │       ├── core-principles.md
│   │       ├── development-workflow.md
│   │       ├── git-workflow.md
│   │       ├── hooks.md
│   │       ├── patterns.md
│   │       ├── performance.md
│   │       ├── security.md
│   │       └── testing.md
│   ├── agents/                   # 24 个通用 agent 定义
│   ├── commands/                 # 60 个通用命令定义
│   ├── skills/                   # 通用 skill（tdd、verify、review 等）
│   ├── scripts/                  # hook 脚本 + lib
│   │   ├── hooks/                # 25 个 hook 脚本
│   │   └── lib/
│   │       └── utils.js
│   └── hooks.json                # 通用 hooks 配置
├── lang/                         # 语言模块（按需选装）
│   ├── typescript/
│   │   ├── rules/                # 5 个 TS 规则
│   │   └── skills/               # TS 相关 skills
│   ├── python/
│   │   ├── rules/
│   │   └── skills/
│   ├── golang/
│   │   ├── rules/
│   │   └── skills/
│   ├── cpp/
│   │   ├── rules/
│   │   └── skills/
│   ├── kotlin/
│   │   ├── rules/
│   │   └── skills/
│   ├── rust/
│   │   └── skills/
│   ├── php/
│   │   ├── rules/
│   │   └── skills/
│   ├── perl/
│   │   ├── rules/
│   │   └── skills/
│   └── swift/
│       └── rules/
└── plugins/                      # 插件安装指引（不含源码）
    └── README.md
```

## 3. 资产清单

### 3.1 core 模块

| 类型 | 数量 | 来源路径 |
|------|------|----------|
| rules (common) | 10 个 .md | `~/.claude/rules/common/` |
| agents | 24 个 .md | `~/.claude/agents/` （排除 openclaw-ops.md） |
| commands | ~60 个 .md | `~/.claude/commands/` （排除 ECC 专属命令） |
| skills | ~50 个目录 | `~/.claude/skills/` （排除个人化 skill） |
| scripts | 25 个 .js/.py/.sh | `~/.claude/scripts/` （排除 insaits-security-monitor.py） |
| hooks | hooks.json | 合并式安装，不直接覆盖 |

### 3.2 lang 模块

每个语言包包含：
- `rules/`：5 个 .md（coding-style、hooks、patterns、security、testing）
- `skills/`：该语言特定的 skill 目录（如有）

可用语言包：typescript、python、golang、cpp、kotlin、rust、php、perl、swift

### 3.3 排除清单

以下内容**不进入仓库**：

- `rules/backup/mgv-conventions.md` — 个人项目命名规范
- `skills/openclaw-ops/` — 特定服务器运维
- `skills/api-integration-testing/OPENCLAW_INTEGRATION.md` — 特定项目集成
- `skills/learned/` — 个人学习模式
- `skills/configure-ecc/` — ECC 插件专属安装引导
- `scripts/hooks/insaits-security-monitor.py` — 特定安全工具
- `agents/openclaw-ops.md` — 特定服务器运维 agent
- `settings.json` 中的凭据字段（ANTHROPIC_AUTH_TOKEN、LITELLM_API_KEY、ANTHROPIC_BASE_URL）
- `hooks.json` 中引用 `${CLAUDE_PLUGIN_ROOT}` 的条目（属于 ECC 插件）
- `commands/` 中 ECC 专属命令：claw.md、checkpoint.md、evolve.md、instinct-export.md、instinct-import.md、instinct-status.md、learn.md、learn-eval.md、loop-start.md、loop-status.md、model-route.md、projects.md、promote.md、prompt-optimize.md、setup-pm.md

## 4. 安装脚本设计

### 4.1 命令格式

```bash
./install.sh                          # 只装 core
./install.sh core python golang       # 装 core + python + golang
./install.sh all                      # 装全部（core + 所有 lang）
```

### 4.2 安装流程

1. 检测 `~/.claude/` 是否存在，不存在则创建
2. 解析参数，确定要安装的模块列表
3. 对每个模块，遍历其文件，复制到 `~/.claude/` 对应目录
4. 遇到同名文件跳过，打印 `SKIP: <path> (already exists)`
5. hooks.json 特殊处理：合并而非覆盖，按 matcher + description 去重
6. 安装完成后打印摘要

### 4.3 安装摘要输出

```
=== Claude Code Config Installed ===

Modules: core, python, golang
Files installed: 87
Files skipped: 3

Skipped files:
  SKIP: ~/.claude/rules/common/coding-style.md (already exists)
  SKIP: ~/.claude/agents/architect.md (already exists)
  SKIP: ~/.claude/rules/python/coding-style.md (already exists)

Next steps:
  1. Review ~/.claude/hooks/hooks.json for merged hooks
  2. See plugins/README.md for recommended plugins
  3. Restart Claude Code to apply changes
```

### 4.4 hooks.json 合并逻辑

1. 读取用户现有的 `~/.claude/hooks/hooks.json`（不存在则创建空结构）
2. 读取本项目的 `core/hooks.json`
3. 对每个 hook 类型（PreToolUse、PostToolUse、Stop 等），逐条检查项目 hook 是否已存在于用户 hook 中
4. 判重依据：matcher 相同 + description 相同 → 视为重复，跳过
5. 不重复的 hook 追加到用户对应类型数组末尾
6. 写回用户 hooks.json

### 4.5 卸载脚本

- 维护一个安装文件清单（install.sh 安装时写入 `~/.claude/.installed-manifest`）
- uninstall.sh 读取清单，逐个删除文件
- 只删清单中确认属于本项目的文件，不删用户自建文件
- 删除空目录（向上递归，直到遇到非空目录或 `~/.claude/` 本身）

### 4.6 Windows 兼容

- install.sh 用 bash 编写
- Windows 用户通过 Git Bash 或 WSL 运行
- 不提供 .ps1 版本

## 5. 更新机制

```bash
cd claude-code-config
git pull
./install.sh core python   # 重新安装，已有文件跳过
```

如需强制更新某个文件：手动删除该文件后重新运行 install.sh。

## 6. README 结构

1. **一句话介绍**：Claude Code 全局配置工具包 — rules、agents、commands、skills、hooks 一键部署
2. **功能概览**：列出 agents、commands、skills、rules 数量，附分类说明
3. **快速开始**：`git clone` + `./install.sh` 两步搞定
4. **模块说明**：core 包含什么、各 lang 包含什么
5. **插件推荐**：superpowers、pua、codex 的安装方式
6. **自定义**：如何修改 rules、如何添加自己的 lang 包
7. **卸载**：`./uninstall.sh`

## 7. 不做什么

- 不包含 settings.json 配置（凭据、permissions、env 涉及个人化，只提供 settings.example.json 参考）
- 不包含 MCP 服务器配置（mcp-servers.json 含服务端地址和凭据）
- 不包含 memory 文件（个人会话记忆）
- 不包含插件源码（插件有自己的 marketplace 分发机制）
- 不提供交互式安装（命令行参数式，适合手动和自动化）
- 不提供 Windows PowerShell 安装脚本

## 8. 验收标准

- [ ] 仓库包含 core + 9 个 lang 模块，文件数量与实际资产一致（排除清单中的文件不在仓库中）
- [ ] `./install.sh` 在空白 `~/.claude/` 上能正确安装所有 core 文件
- [ ] `./install.sh core python` 只装 core + python，不装其他 lang
- [ ] 已有同名文件时跳过不覆盖，打印 SKIP 信息
- [ ] hooks.json 合并正确：新增 hook 追加、重复 hook 跳过
- [ ] `./uninstall.sh` 能干净卸载所有本项目安装的文件
- [ ] README 内容完整，新用户能看懂并完成安装
- [ ] 仓库中无凭据、无个人化内容
