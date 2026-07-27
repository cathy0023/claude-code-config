# 自定义指令与 Skill 手册

> 本手册只收录**我自己沉淀**的指令/skill，不含 ECC、Superpowers、PUA 等第三方插件内容。
> 最后更新：2026-07-27

---

## 总览

| 类型 | 数量 | 范围 |
|------|------|------|
| **Commands（/指令）** | 9 个 | 开发流程 / 上线发布 / Git 操作 / 日志观测 / 知识传承 |
| **Skills（技能）** | 8 个 | 开发编排 / GitLab 集成 / RFC 流水线 / 复盘 |

---

## 一、开发流程类（Development Workflow）

### Commands

#### `/dev-branch <自然语言描述>`
**能力**：拉取最新主分支代码后，创建规范命名的需求分支。
- 分支名格式：`<类型>/<核心意思>-<当前日期>`（如 `feat/screen-share-20260523`）
- 自动识别 `feat` / `fix` / `refactor` 等类型
- 确保起点是基于最新 main/master

**示例**：
```
/dev-branch 共享屏幕演讲融合到陪练项目
/dev-branch 修复登录页面崩溃问题
```

---

#### `/dev-start [--install-only | --env-only | --start-only | --full]`
**能力**：一键启动 `ai-sop-api` 本地开发环境。
- **项目限定**：仅在 `ai-sop-api` 目录下可用，其他项目会拒绝执行
- 自动安装依赖（uv venv + uv pip）
- 设置环境变量
- 启动 uvicorn 服务

**模式**：
- `--install-only` — 仅装依赖
- `--env-only` — 仅配环境变量
- `--start-only` — 仅启动服务
- `--full` — 完整流程（默认）

---

#### `/update-from-main [--rebase] [--no-fetch] [--push]`
**能力**：把当前分支与最新的 main/master 合并，减少上线冲突。
- 自动检测主分支（优先 `main`，回退 `master`）
- fetch → 展示 commit 预览 → Y/N 确认 → 合并
- **冲突安全中止**：检测到冲突立即 `git merge --abort`，恢复到合并前状态，让用户手动处理
- 默认 merge，`--rebase` 切换为 rebase 模式（会警告改写历史风险）
- 默认不 push，`--push` 自动推

---

#### `/sync-push [目标分支名] [--commit-only]`
**能力**：提交当前分支代码 → 推送 → 合并到目标分支（默认 `test`）→ 推送目标分支。
- 一键完成 commit + push + merge + push 闭环
- `--commit-only` 只 commit + push，不合并到 test
- 默认目标分支 `test`，可指定 `dev` / `staging` 等

**示例**：
```
/sync-push              # commit → push → merge to test → push test
/sync-push dev          # 合并到 dev 而非 test
/sync-push --commit-only # 只 commit + push 当前分支
```

---

### Skills

#### `dev-lite` — 轻量开发工作流编排器
**能力**：9 阶段闭环开发编排，适用于 bugfix、小功能、重构等常规需求。
- **流程**：BRAINSTORM → BRANCH → RESEARCH → PLAN → EXECUTE → REVIEW → FIX → SHIP → DEPLOY
- 调用现有 skill/command 组合实现（superpowers:brainstorming、/dev-branch、superpowers:writing-plans、subagent-driven-development、/ship、/sync-push）
- **保留**：调研 + 多专家评审 panel + TDD 核心抓手
- **砍掉**：worktree 隔离、RFC 文档生命周期、MR 自动化等重型环节
- SHIP 只到 push 为止；DEPLOY 生成本次上线步骤并询问是否合 test 做人工验证

**触发词**：`dev-lite`、`轻量开发`、`小需求`、`bugfix 流程`

---

## 二、上线发布类（Release & Deploy）

### Commands

#### `/release-steps [需求简述]`
**能力**：需求开发完成、代码合并 main 后调用，生成双版本上线清单。
- **自用版** `*-self.md`：每阶段「做什么 + 顺序 + 验证 + 坑」四要素，单行优先
- **运维版** `*-ops.md`：纯命令 + 验证 + 失败处理，**零废话**
- **SQL 内联**：检测到的 `.sql` 文件用 `cat` 读出内容**内联到文档**，不引用文件路径（避免运维找不到）
- 不填需求简述时，从 git context（最近 commit + diff）自动推断

**输出位置**：`docs/releases/YYYY-MM-DD-<需求>-self.md` + `docs/releases/YYYY-MM-DD-<需求>-ops.md`

---

## 三、GitLab 集成类（GitLab Integration）

### Commands

#### `/review-fix <MR-URL>`
**能力**：从 GitLab MR 拉取 reviewer 评论 → 对每个 P0 三问鉴定 → 确认真问题才修复 → 提交。
- **核心原则**：不盲目信任 reviewer
- **三问鉴定**：
  1. 事实核查 — 问题真实存在吗？
  2. 判断准确性 — reviewer 看对了吗？
  3. 政治判断 — 即使技术 OK，会阻塞合入吗？
- 分类输出：✅确认真问题 / ⚠️需要澄清 / ❌假阳性误判
- 5 种常见假阳性识别（diff 上下文误读、风格偏好冒充功能缺陷等）
- 修复完不自动 push

**前置依赖**：`GITLAB_TOKEN` 环境变量（未设置则降级为手动粘贴评论）

---

### Skills

#### `glab-mr` — GitLab MR 创建器
**能力**：封装 GitLab MR 创建/更新流程，**只使用 `glab` CLI**（不是 `gh`），适配自建 GitLab `git.mgvai.cn`。
- 自动检测 source/target 分支
- MR 查重：先 `glab mr list` 再决定创建/更新
- 从 commit 历史生成 conventional commits 标题
- 从 diff stat + commit 列表生成结构化描述（背景 / 改动范围 / Commit 列表 / 测试 / 关联）
- **核心坑点**：`--source-branch` 必须显式指定（否则交互式卡死）；描述用 `"$(cat file)"` 保留换行
- 默认 target `main`（不是 develop）
- 8 项常见错误排查表 + 跨仓姊妹 MR 联动流程

**触发词**：`glab-mr`、`创建 MR`、`create merge request`、`提 MR`、`glab mr`

---

## 四、RFC 文档流水线（RFC Pipeline）

### 5 件套关系图

```
rfc-init          初始化目录结构（项目级一次性）
   ↓
rfc-brainstorm    前置讨论，厘清需求边界（一次一个问题）
   ↓
rfc-author        把 inbox 文档转成规范 RFC（draft）
   ↓
mgv-rfc-approve   5 维度完整性检查 + 审批（Draft → Approved）
   ↓
rfc-driven-dev    全流程编排：从原始文档到交付的 11 阶段流水线
```

### Skills 详解

#### `rfc-init` — RFC 目录初始化器
**能力**：在项目中创建 `docs/rfcs/` 目录结构和 README.md 索引文件。
- 一次性项目级初始化
- 创建 `inbox/`、`draft/`、`approved/`、`archived/` 子目录

---

#### `rfc-brainstorm` — RFC 前置需求讨论器
**能力**：在写 inbox 文档**之前**使用，通过**一次一个问题**的方式厘清需求边界、探索备选方案。
- 产出结构化的 inbox 文档
- 职责单一：不进入执行流水线
- 用 `AskUserQuestion` 工具驱动交互式对话

---

#### `rfc-author` — RFC 生成器
**能力**：从 `docs/rfcs/inbox/` 的原始文档生成规范 RFC 到 `docs/rfcs/draft/`。
- 模板定义、命名规范、序号管理
- 把零散的想法整理成结构化 RFC（背景 / 目标 / 方案 / 验收标准 / 风险）

---

#### `mgv-rfc-approve` — RFC 审批器
**能力**：5 维度完整性检查 + 状态流转（Draft → Approved）。
- 5 维度审查（如目标清晰度、方案可行性、风险覆盖、验收标准、影响范围）
- 审批通过后自动 `git mv` 到 `approved/` 目录
- 自动更新 README.md 索引

---

#### `rfc-driven-dev` — RFC 驱动开发全流程编排器
**能力**：11 阶段完整流水线，从原始 RFC 文档到最终交付。
- **流程**：调研 → RFC 生成 → 评审 → 审批 → Plan → 实现 → Review → 修复 → 归档 → 交付
- 适用于处理 `docs/rfcs/inbox` 或 `docs/rfcs/draft` 中的文档
- 支持 worktree 隔离 + 跨会话 beacon（最近修复）

---

## 五、日志观测类（Logging & Observability）

### Commands

#### `/test-log [list | search | <项目或日志名>] [latest | errors | follow | <grep-pattern>] [--lines N]`
**能力**：查看测试服务器 `/data/logs/` 和 `/log/megaview/` 下所有项目的日志。
- **跨平台**：Win/Mac 自适应（Windows 用 sshpass-win32 + Windows OpenSSH，Mac 用原生 ssh）
- 已知日志别名映射（mgvcore / megaview / mgvproc / ai-sop-api 等 30+ 日志）
- **关键词默认跨所有日志搜索**（`grep -r`）
- 支持 list / latest / errors / follow / 关键词搜索 5 种模式
- 无参数默认查 `ai-sop-api/mgvsopapi.log` 最新 200 行

**连接信息**：`39.103.221.243` / 用户 `chenyan`

**示例**：
```
/test-log                                    # 默认 ai-sop-api 最新 200 行
/test-log list                               # 列出所有可用日志
/test-log "timeout"                          # 跨所有日志搜 timeout
/test-log mgvcore errors                     # 查 mgvcore 错误
/test-log ai-sop-api follow                  # 实时跟踪
```

---

#### `/sls-log [latest | errors | <关键词>] [--hours N] [--lines N] [--from <time> --to <time>]`
**能力**：阿里云 SLS 生产日志查询。
- 通过阿里云 SLS CLI 直连日志服务
- 查询 `megaview-server` 生产环境的 `server` logstore（cn-zhangjiakou）
- 支持时间范围、关键词、错误过滤
- 依赖：`aliyunlog` CLI + 环境变量配置

---

## 六、知识沉淀与传承（Knowledge & Retrospective）

### Commands

#### `/teach`
**能力**：以前端视角深入浅出讲解后端概念、流程、术语。
- 像一个**懂前端的后端导师**
- 不只讲 What，更讲 Why
- 帮助前端开发者理解后端世界（数据库、并发、缓存、消息队列、API 设计等）

---

### Skills

#### `case-study` — 事故深度复盘
**能力**：针对**反复修复多次才解决**的事故，进行系统性证据收集、根因分析和文档化沉淀。
- **4 阶段流水线**：
  1. **COLLECT** — 自动从 git 历史定位多轮修复 commit + 构建时间线
  2. **ANALYZE** — 逐轮对比分析（Round 1 → Round N）+ 跨轮归纳 + 5 Whys 追问
  3. **DRAFT** — 按标准模板生成 `docs/case-studies/YYYYMMDD-{slug}.md`
  4. **DELIVER** — 输出摘要，不自动 commit/PR
- **核心差异化价值**：聚焦"为什么前几次没修对"
- **Gate 控制**：只有 2 轮以上修复才进入流程（否则不是 case-study 场景）
- 5 Whys 至少追到第 4 层，跨轮归纳必须有实质内容（非"下次注意"空话）

**触发词**：`case-study`、`事故复盘`、`深度复盘`、`postmortem`、`bug 复盘`、`故障复盘`

---

## 附录：按使用频率推荐

| 场景 | 推荐使用 |
|------|---------|
| 开始一个新需求 | `/dev-branch` → 写代码 → `/sync-push` |
| 修 bug（轻量） | `dev-lite` skill |
| 大需求需要 RFC | `rfc-brainstorm` → `rfc-author` → `mgv-rfc-approve` → `rfc-driven-dev` |
| 当前分支落后主分支 | `/update-from-main` |
| 合并 main 后准备上线 | `/release-steps` |
| 排查测试环境问题 | `/test-log` |
| 排查生产问题 | `/sls-log` |
| 处理 MR 评审 P0 | `/review-fix` |
| 创建 GitLab MR | `glab-mr` skill |
| 事故复盘 | `case-study` skill |
| 学习后端概念 | `/teach` |

---

## 附录：文件位置

| 类型 | 项目源 | 本机目标 |
|------|--------|---------|
| Commands | `core/commands/*.md` | `~/.claude/commands/*.md` |
| Skills | `core/skills/<name>/SKILL.md` | `~/.claude/skills/<name>/SKILL.md` |

同步方式：
```bash
cd ~/Documents/project_code/claude-code-config
git pull
./install.sh   # 或手动 cp 到 ~/.claude/
```
