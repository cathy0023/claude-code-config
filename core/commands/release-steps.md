---
allowed-tools: Bash(git *), Bash(grep *), Bash(find *), Bash(cat *), Bash(ls *), Bash(wc *), Bash(mkdir *), Bash(date *), AskUserQuestion, Write, Read, Glob, Grep
description: 生成本次上线的双版本步骤清单 — 自用详细版（含为什么）+ 运维执行版（仅命令）。需求开发完成、准备上线时调用
argument-hint: [需求简述，可选 — 不填则从 git context 自动推断]
---

# /release-steps — 上线步骤生成器

> **用途**：在需求开发完成、代码合并 main 后、生产部署前调用。生成两份 markdown 清单：
> - `*-self.md` 自用详细版：每阶段含「做什么 / 为什么这个顺序 / 怎么验证 / 常见坑」
> - `*-ops.md` 运维简洁版：仅含「执行命令 + 验证 + 失败处理」
>
> **完整时间线**：开发完 → `/ship` → `/sync-push`（合 test）→ 测试 → 合 main → **`/release-steps`** → 按清单执行上线 → `/sls-log` 验证

用户参数：$ARGUMENTS

---

## 阶段 0：Context 自动探测（不询问用户）

### 0.1 项目类型探测

按优先级检测：

```bash
# Java 后端
find . -maxdepth 3 \( -name "pom.xml" -o -name "build.gradle" -o -name "build.gradle.kts" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -3

# Node 后端
find . -maxdepth 2 -name "package.json" -not -path "*/node_modules/*" -exec grep -l '"main"\|"engines"\|express\|koa\|nest\|fastify' {} \; 2>/dev/null | head -3

# 前端
find . -maxdepth 2 -name "package.json" -not -path "*/node_modules/*" -exec grep -l '"vite\|"webpack\|"next\|"vue\|"react' {} \; 2>/dev/null | head -3

# Docker
find . -maxdepth 2 \( -name "Dockerfile" -o -name "docker-compose.yml" -o -name "docker-compose.yaml" \) 2>/dev/null | head -3
```

**探测结果分类**：

| 信号 | 项目类型 | 影响 |
|------|---------|------|
| pom.xml / build.gradle | Java 后端 | 制品 = jar/Docker image |
| package.json + server signals | Node 后端 | 制品 = npm tarball/Docker image |
| package.json + frontend signals | 前端 | 制品 = 静态资源/CDN |
| Dockerfile / docker-compose | 容器化 | 制品 = Docker image |

**多个并存 → AskUserQuestion 让用户选当前要上线的项目**。

### 0.2 Git Context 收集

```bash
# 当前分支
CURRENT_BRANCH=$(git branch --show-current)

# 主分支（自动检测）
MAIN_BRANCH=$(git rev-parse --verify origin/main >/dev/null 2>&1 && echo "main" || echo "master")

# 与 main 的 commits
git log $MAIN_BRANCH..HEAD --oneline --no-decorate 2>/dev/null | head -20

# diff 文件类型分布
git diff $MAIN_BRANCH...HEAD --name-only 2>/dev/null | sed 's|\.||g' | awk -F. '{print $NF}' | sort | uniq -c | sort -rn

# 最近生产 tag（回滚锚点候选）
git describe --tags --abbrev=0 2>/dev/null

# 当前 HEAD commit
git rev-parse --short HEAD
```

### 0.3 数据层变更痕迹扫描

```bash
# SQL 变更
git diff $MAIN_BRANCH...HEAD --name-only 2>/dev/null | grep -iE '\.(sql)$|migration|flyway|liquibase'

# ES mapping 变更
git diff $MAIN_BRANCH...HEAD --name-only 2>/dev/null | grep -iE 'es-mapping|index-template|elastic'

# Redis key 定义
git diff $MAIN_BRANCH...HEAD --name-only 2>/dev/null | grep -iE 'redis|cache.*key|cache.*config'

# MQ topic 定义
git diff $MAIN_BRANCH...HEAD --name-only 2>/dev/null | grep -iE 'mq|kafka|rabbitmq|topic|consumer'

# 配置中心
git diff $MAIN_BRANCH...HEAD --name-only 2>/dev/null | grep -iE 'nacos|apollo|application.*\.ya?ml|application.*\.properties'
```

将扫描结果汇总为 `DETECTED_LAYERS`，后续阶段 1 跟用户确认。

---

## 阶段 1：AskUserQuestion（3 个关键问题，缺一不可）

基于阶段 0 探测结果，依次问：

### Q1：数据层变更确认

> 展示 `DETECTED_LAYERS` 检测结果，问用户：「本次上线涉及以下哪些数据层变更？」
>
> - SQL（DDL/DML）
> - ES（mapping/reindex）
> - Redis（key 结构变更）
> - MQ（topic/queue）
> - Nacos/Apollo（配置变更）
> - 无数据层变更
>
> 多选。检测结果默认勾选，但允许用户增删。

### Q2：上线方式

> 「本次上线采用哪种方式？」
>
> - 全量（一次性切流）
> - 灰度（按百分比逐步放）
> - 蓝绿（双环境切换）
> - 分批（按用户/租户分批）

### Q3：特殊回滚点

> 「有没有特殊回滚约束？」
>
> - 无（用默认：回滚到上一个 tag）
> - 必须保留某个 commit（请说明）
> - DB 数据需要单独备份（用上次备份策略）
> - 其它（请描述）

---

## 阶段 2：Slug 与文件名生成

```bash
# 用户参数 → slug；无参数 → 从最近 commit message 提取
USER_INPUT="$ARGUMENTS"
if [ -z "$USER_INPUT" ]; then
  USER_INPUT=$(git log $MAIN_BRANCH..HEAD --pretty=format:"%s" | head -1 | sed 's/^[a-z]*: *//')
fi

# 转 kebab-case，限 30 字符
SLUG=$(echo "$USER_INPUT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9一-龥]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//' | head -c 30)

# 日期
DATE=$(date +%Y-%m-%d)

# 文件名（处理重名）
SELF_FILE="docs/releases/${DATE}-${SLUG}-self.md"
OPS_FILE="docs/releases/${DATE}-${SLUG}-ops.md"

# 重名加序号
i=2
while [ -f "$SELF_FILE" ]; do
  SELF_FILE="docs/releases/${DATE}-${SLUG}-${i}-self.md"
  OPS_FILE="docs/releases/${DATE}-${SLUG}-${i}-ops.md"
  i=$((i+1))
done

# 创建目录
mkdir -p docs/releases
```

---

## 阶段 3：生成自用详细版（`*-self.md`）

按以下模板生成（`{占位符}` 来自阶段 0/1 的探测和用户回答）。

### 模板头

```markdown
# 上线步骤 · {DATE} · {SLUG}

> **自用版**（详细，含「为什么」）
>
> **生成时间**：{DATE}
> **当前分支**：{CURRENT_BRANCH}
> **主分支**：{MAIN_BRANCH}
> **本次 HEAD**：{HEAD_HASH}
> **回滚锚点（上一稳定版）**：{LAST_TAG}
> **项目类型**：{PROJECT_TYPE}
> **上线方式**：{DEPLOY_STRATEGY}
> **数据层变更**：{DETECTED_LAYERS_TEXT}

---

## 完整时间线（一句话）

代码已合并 {MAIN_BRANCH} → 现在执行 ② 制品构建 → ③ 数据层前置 → ④ 部署 → ⑤ 数据层后置 → ⑥ 验证 → ⑦ 回滚预案（备用）

---

## 顺序约束速查表

| 顺序 | 原因 | 颠倒后果 |
|------|------|---------|
| ② 制品 → ③ 数据前置 | 先有制品 tag 才能回滚 | 回滚无锚点 |
| ③ → ④（数据前置先于部署） | 旧代码 + 新数据 = 仍可跑；新代码 + 新数据 = 可跑 | 新代码读不到字段 → 生产报错 |
| ④ → ⑤（数据后置后于部署） | 必须确认旧代码全部下线才删 | 旧代码读到「已删除」字段 → 生产报错 |
| ④ → ⑥（验证后于部署） | 验证生产实际行为 | 验证无意义 |
| ⑥ → ⑤（验证通过才清理） | 验证失败 → 走 ⑦ 回滚，绝不进入 ⑤ | 错误的清理让回滚也无法恢复 |

---

## 数据层变更决策树

本次需求涉及数据层吗？根据阶段 1 的回答走对应分支：

- **无数据层变更** → 跳过 ③⑤
- **仅 SQL（向前兼容的 ADD COLUMN / CREATE TABLE）** → ③ 前置执行
- **SQL 含 DROP / RENAME / 类型变更** → **必须分两次上线**：本次 ③（expand），下次上线 ⑤（contract）
- **ES mapping 变更** → reindex 策略：新建 v2 索引 → reindex → 切别名 → ⑤ 删 v1
- **Redis key 结构变更** → 双写过渡期 + 旧 key 设 TTL 自动失效
- **MQ topic 变更** → 新 topic 双写 + 消费者切换 + 旧 topic 待无消息后 ⑤ 删
- **Nacos / Apollo 配置变更** → 区分"动态生效"vs"需重启"，前者 ③ 前置下发，后者 ④ 部署时加载
- **定时任务（XXL-Job 等）** → ④ 部署前先停调度 → 部署后启动

> **核心模式（必懂）**：Expand-and-Contract
> 数据层变更是「非代码制品」，有严格的顺序约束。Expand 阶段（③）只做"加"，Contract 阶段（⑤）才做"删"。
> 中间夹着 ④ 代码部署 — 让新代码上线、旧代码下线。
> 颠倒顺序 = 生产炸。
```

### 每个阶段的 5 小节模板

对 7 个阶段（① ~ ⑦）依次生成，每阶段含：

```markdown
## 阶段 X：{阶段名}

### 这个阶段在做什么
（一句话目标）

### 为什么必须放在这个顺序
（后端知识 — 解释顺序约束）

### 检查项（Checklist）
- [ ] xxx
- [ ] xxx

### 怎么验证这一步通过了
（具体命令/SQL/查询）

### 常见坑（事故案例）
（容易翻车的地方）
```

**七阶段固定内容**（按下表填充到模板）：

| 阶段 | 名 | 一句话目标 | 顺序原因 |
|------|---|----------|---------|
| ① | 上线前自查 | 把应该想到的全部前置 | 避免上线到一半发现依赖没准备 |
| ② | 制品构建 + Tag | 出可部署的制品并打 tag | tag = 回滚锚点，没有就无法回滚 |
| ③ | 数据层变更【前置】 | 执行 expand 部分（ADD/CREATE/新增） | 旧代码 + 新数据 仍可跑；新代码 + 新数据 也可跑 |
| ④ | 部署执行 | 把新代码推到生产 | 数据已 expand 完，代码部署即可读新结构 |
| ⑤ | 数据层变更【后置】 | 执行 contract 部分（DROP/DELETE） | 等到无旧代码读旧结构才能删 |
| ⑥ | 上线后验证 | 技术 + 业务双重验证 | 部署后才知生产实际行为 |
| ⑦ | 回滚预案 | 上线计划的一部分，非退路 | 上线前必须填好 |

### 自用版尾部：本次上线的核心风险点（3 行内）

> 根据阶段 0/1 的 context，自动生成 1-3 条风险点，例如：
> - ⚠️ 本次含 SQL DROP，但用户选了"全量上线" — 建议分两次（**红色警告**）
> - ⚠️ 检测到 Nacos 配置变更 — 需要确认动态生效 vs 需重启
> - ⚠️ 当前分支与 main 差距 > 20 commits — 确认无遗漏 review

---

## 阶段 4：生成运维简洁版（`*-ops.md`）

从自用版抽取，**只保留执行动作 + 命令 + 失败处理**，删除所有「为什么」段落。

### 模板头

```markdown
# 上线步骤 · {DATE} · {SLUG}

> **运维版**（仅含执行动作，不含「为什么」）
>
> **本次制品**：{NEW_TAG}  ｜  **回滚版本**：{LAST_TAG}
> **上线方式**：{DEPLOY_STRATEGY}
> **执行顺序**：① 自查（开发负责） → ② 制品 → ③ 数据前置 → ④ 部署 → ⑤ 数据后置 → ⑥ 验证
>
> ⚠️ **铁律**：任一阶段失败 → 立即停止 → 通知开发 → 按 §⑦ 回滚预案处理

---

## ② 制品构建

1. 确认 CI/CD 构建成功（{CI_URL_PLACEHOLDER}）
2. 记录本次制品 tag：`{NEW_TAG}`
3. 记录回滚版本 tag：`{LAST_TAG}`

## ③ 数据层变更【前置】

执行顺序：SQL → ES → MQ，**全部成功才进入 ④**

{根据阶段 1 用户选择的数据层，动态展开以下小节}

### SQL
\`\`\`bash
mysql -h {DB_HOST} -u {DB_USER} -p < migrations/{DATE}-*.sql
\`\`\`
✅ 验证：
\`\`\`sql
SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='{DB_NAME}' AND column_name='{NEW_COLUMN}';
\`\`\`

### ES
\`\`\`bash
curl -X PUT "{ES_HOST}/{INDEX_NAME}_v2" -H 'Content-Type: application/json' -d '@mappings/{INDEX_NAME}.json'
curl -X POST "{ES_HOST}/_reindex" -H 'Content-Type: application/json' -d '{"source":{"index":"{INDEX_NAME}_v1"},"dest":{"index":"{INDEX_NAME}_v2"}}'
\`\`\`
✅ 验证：`GET {ES_HOST}/_cat/indices/{INDEX_NAME}_v2?v`

❌ 任一步失败 → 立即停止 → 通知开发

## ④ 部署执行

部署顺序：{DEPLOY_ORDER}

每个服务部署后立即健康检查：
\`\`\`bash
curl -f http://{SERVICE_HOST}:{PORT}/actuator/health || curl -f http://{SERVICE_HOST}:{PORT}/health
\`\`\`

❌ 健康检查失败 → 切回 {LAST_TAG} → 通知开发

## ⑤ 数据层变更【后置】

> ⚠️ **仅在 ⑥ 验证全部通过后才执行**

{从 ③ 对应的 contract 操作}

❌ 失败 → 通知开发，不回滚（数据已不可逆时回滚更危险）

## ⑥ 上线后验证

- 技术：`/sls-log` 查 ERROR / 监控告警 dashboard
- 业务：核心 happy path（{BUSINESS_TEST_CASES}）

## ⑦ 回滚预案

触发条件：
- 错误率 > {THRESHOLD}
- 核心功能不可用
- 数据异常

回滚动作：
\`\`\`bash
# 制品切回
kubectl set image deployment/{SERVICE} {SERVICE}={REGISTRY}/{SERVICE}:{LAST_TAG}
# 或
ssh {PROD_HOST} "cd /opt/{SERVICE} && ln -sfn {LAST_TAG} current && systemctl restart {SERVICE}"
\`\`\`

回滚验证：同 ⑥
```

---

## 阶段 5：边界情况处理

| 场景 | 处理 |
|------|------|
| 项目类型探测失败（找不到任何已知特征） | AskUserQuestion 让用户选：「Java 后端 / Node 后端 / 前端 / 容器化」 |
| `docs/releases/` 目录不存在 | `mkdir -p docs/releases` 自动创建 |
| 同一天同一 slug 已有文件 | 阶段 2 的 while 循环自动加序号后缀 `-2`、`-3` |
| 用户回答「SQL 含 DROP」+「全量一次上线」 | 自用版顶部生成 **红色警告**，建议分两次上线 |
| 用户跳过 AskUserQuestion（直接回车） | 用全部默认值生成，每处标 `[未确认]` |
| 阶段 0 拉不到 `git diff main...HEAD`（无 main 分支） | 改用 `origin/master`，再不行用 `HEAD~10..HEAD` 兜底 |

---

## 阶段 6：输出与同步

### 6.1 最终输出（终端展示）

```
✅ 已生成上线步骤双版本清单：

  自用详细版：docs/releases/{DATE}-{SLUG}-self.md
  运维简洁版：docs/releases/{DATE}-{SLUG}-ops.md

📌 本次上线核心风险：
  - ⚠️ xxx
  - ⚠️ xxx

💡 下一步：
  1. review 自用版，确认 ⑦ 回滚预案填写完整
  2. 把运维版复制到飞书/钉钉交接给运维
  3. 上线执行时按清单逐项打勾
  4. 上线后用 /sls-log 查生产日志验证
```

### 6.2 同步到 ~/.claude/commands/

> install.sh 是 SKIP 策略，不会自动覆盖。命令文件首次创建后，**手动复制到本地生效目录**：

```bash
cp core/commands/release-steps.md ~/.claude/commands/release-steps.md
```

执行此命令前**等用户确认**。

---

## 注意事项

1. **不执行任何上线动作**：本命令只生成 markdown 清单，不调用 mysql/curl/kubectl 等真实部署命令
2. **跨项目通用**：阶段 0 的探测决定模板走向，不写死任何项目名
3. **双版本同源**：运维版从自用版抽取，保证两版一致，避免漂移
4. **顺序约束是核心**：自用版顶部「顺序约束速查表」+「数据层决策树」必须出现在生成的文档里，不能省略
5. **运维版铁律**：不含「为什么」，只含「做什么 + 命令 + 失败处理」
