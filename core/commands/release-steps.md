---
allowed-tools: Bash(git *), Bash(grep *), Bash(find *), Bash(cat *), Bash(ls *), Bash(wc *), Bash(mkdir *), Bash(date *), AskUserQuestion, Write, Read, Glob, Grep
description: 生成本次上线的双版本步骤清单 — 自用详细版（含为什么）+ 运维执行版（仅命令）。需求开发完成、准备上线时调用
argument-hint: [需求简述，可选 — 不填则从 git context 自动推断]
---

# /release-steps — 上线步骤生成器

> **用途**：需求开发完成、代码合并 main 后调用。生成两份**精简**的 markdown 清单：
> - `*-self.md` 自用版：每阶段「做什么 + 顺序 + 验证 + 坑」四要素，单行优先
> - `*-ops.md` 运维版：纯命令 + 验证 + 失败处理，**零废话**
>
> **SQL 要求**：检测到的 .sql 文件，**用 `cat` 读出内容内联到文档**，不引用文件路径。

用户参数：$ARGUMENTS

---

## 阶段 0：Context 自动探测

### 0.1 项目类型探测（按优先级）

```bash
# Java 后端
find . -maxdepth 3 \( -name "pom.xml" -o -name "build.gradle*" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -1

# Node 后端
find . -maxdepth 2 -name "package.json" -not -path "*/node_modules/*" -exec grep -l '"main"\|"engines"\|express\|koa\|nest\|fastify' {} \; 2>/dev/null | head -1

# 前端
find . -maxdepth 2 -name "package.json" -not -path "*/node_modules/*" -exec grep -l '"vite\|"webpack\|"next\|"vue\|"react' {} \; 2>/dev/null | head -1

# Docker
find . -maxdepth 2 \( -name "Dockerfile" -o -name "docker-compose.yml" \) 2>/dev/null | head -1
```

探测失败 → AskUserQuestion 让用户选。

### 0.2 Git Context

```bash
CURRENT_BRANCH=$(git branch --show-current)
MAIN_BRANCH=$(git rev-parse --verify origin/main >/dev/null 2>&1 && echo main || echo master)
git log $MAIN_BRANCH..HEAD --oneline --no-decorate 2>/dev/null | head -20
git diff $MAIN_BRANCH...HEAD --name-only 2>/dev/null
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null) || echo "无"
HEAD_HASH=$(git rev-parse --short HEAD)
```

### 0.3 数据层变更扫描 — **读出实际内容**

> 关键：扫描到的文件**用 cat 读内容**，后续阶段内联到文档里（不引用路径）。

```bash
# 收集所有变更的 .sql 文件路径
SQL_FILES=$(git diff $MAIN_BRANCH...HEAD --name-only 2>/dev/null | grep -iE '\.(sql)$|migration/|flyway/|liquibase/')

# 逐个读出内容（生成文档时内联）
for f in $SQL_FILES; do
  echo "=== $f ==="
  cat "$f"
done

# ES mapping 文件
ES_FILES=$(git diff $MAIN_BRANCH...HEAD --name-only 2>/dev/null | grep -iE 'es-mapping|index-template|elastic')

# MQ / Redis / Nacos（这些通常是配置，扫描即可，内容可选）
git diff $MAIN_BRANCH...HEAD --name-only 2>/dev/null | grep -iE 'mq|kafka|rabbit|topic|consumer|redis|cache|nacos|apollo'
```

将扫描结果汇总为 `DETECTED_LAYERS`。

---

## 阶段 1：AskUserQuestion（最多 2 个问题）

### Q1：数据层变更确认

> 展示 `DETECTED_LAYERS`，问：「本次涉及哪些数据层变更？」
> 选项：SQL / ES / Redis / MQ / Nacos / 无（多选，检测结果默认勾选）

### Q2：上线方式

> 「本次采用哪种上线方式？」
> 选项：全量 / 灰度 / 蓝绿 / 分批

> ~~Q3~~（取消特殊回滚点问题 — 默认回滚到 ② 阶段记录的 LAST_TAG，不再问）

---

## 阶段 2：Slug 与文件名

```bash
USER_INPUT="$ARGUMENTS"
[ -z "$USER_INPUT" ] && USER_INPUT=$(git log $MAIN_BRANCH..HEAD --pretty=format:"%s" | head -1 | sed 's/^[a-z]*: *//')

SLUG=$(echo "$USER_INPUT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9一-龥]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//' | head -c 30)
DATE=$(date +%Y-%m-%d)
SELF_FILE="docs/releases/${DATE}-${SLUG}-self.md"
OPS_FILE="docs/releases/${DATE}-${SLUG}-ops.md"

i=2
while [ -f "$SELF_FILE" ]; do
  SELF_FILE="docs/releases/${DATE}-${SLUG}-${i}-self.md"
  OPS_FILE="docs/releases/${DATE}-${SLUG}-${i}-ops.md"
  i=$((i+1))
done

mkdir -p docs/releases
```

---

## 阶段 3：生成自用版（精简模板）

> **铁律**：每阶段固定 4 小节，**单行优先**，砍所有冗余解释。最长 ~150 行。

### 文档头（紧凑）

```markdown
# 上线 · {DATE} · {SLUG}

> 项目: {PROJECT_TYPE} ｜ 分支: {CURRENT_BRANCH} (HEAD {HEAD_HASH}) ｜ 上线: {DEPLOY_STRATEGY} ｜ 回滚锚点: {LAST_TAG}
>
> **顺序**：① 自查 → ② 制品 → ③ 数据前置(expand) → ④ 部署 → ⑤ 数据后置(contract) → ⑥ 验证 → ⑦ 回滚
>
> **核心约束**：数据层走 expand-and-contract。③ 只"加"，⑤ 才"删"。颠倒=生产炸。
```

### 阶段模板（4 小节 × 单行）

```markdown
## ① 上线前自查
**做什么**：把外部依赖一次性盘点。
**Checklist**：
- [ ] diff 已 review，无 TODO/debug
- [ ] 下游服务版本已对齐
- [ ] 上线窗口已和运维对齐
- [ ] ⑦ 回滚预案已填
**坑**：Nacos 配置没下发 → 服务启动失败；下游 API 没上线 → 404。

## ② 制品 + Tag
**做什么**：CI/CD 出 jar/image，打 git tag 作回滚锚点。
**执行**：`git tag -a v{DATE}-1 -m "release: {SLUG}"; git push origin v{DATE}-1`
**验证**：`git ls-remote --tags origin v{DATE}-1` 有结果。
**坑**：tag 没推 → 回滚找不到锚点；image 用 latest → 回滚到不知道哪版。

## ③ 数据层【前置】（Expand — 只"加"）
**做什么**：执行 SQL DDL/DML、ES 新索引+reindex、MQ 新 topic、Redis 双写（代码层）。

### SQL（{N} 个文件 — 内容内联）
{对每个 .sql 文件，cat 出内容，按下面格式嵌入}

**`{文件路径}`**：
```sql
{cat 出的 SQL 全文}
```

**验证**：
```sql
SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='{DB}' AND column_name='{NEW_COL}';
-- 期望 1
```

### ES（如检测到 mapping 文件）
**`{文件路径}`** 内容：{cat mapping 文件}
```bash
curl -X PUT "{ES}/{IDX}_v2" -d '@{文件}'
curl -X POST "{ES}/_reindex?wait_for_completion=false" -d '{"source":{"index":"{IDX}_v1"},"dest":{"index":"{IDX}_v2"}}'
```
**验证**：`GET {ES}/_cat/indices/{IDX}_v2?v` 文档数与 v1 一致。

### MQ / Redis（如检测到）
按配置变更点列出，无文件则用一行说明。

**坑**：reindex 没等完就切 alias → 丢数据；SQL ADD COLUMN 没 DEFAULT → 老数据 NPE。

## ④ 部署
**做什么**：把 ② 制品推到生产。顺序：无状态→有状态→核心→边缘。
**执行**：
```bash
kubectl set image deployment/{SVC} {SVC}=registry.../{SVC}:v{DATE}-1
kubectl rollout status deployment/{SVC} --timeout=300s
```
**验证**：`curl -f http://{HOST}:{PORT}/actuator/health` 返回 UP。
**坑**：Bean 启动失败（Nacos 没下发）；端口冲突；先起 consumer 后起 producer。

## ⑤ 数据层【后置】（Contract — 只"删"，⑥ 通过后才执行）
**做什么**：DROP 旧 column、删 ES v1、删旧 MQ topic。
**SQL**（如有 DROP 文件，内联）：
```sql
{cat 出的 DROP SQL}
```
**坑**：alias 没切就删 v1 → 业务读 v1 报错；topic 还有积压就删 → 丢数据。

## ⑥ 验证
**做什么**：技术 + 业务双重。
**Checklist**：
- [ ] 健康检查全 UP
- [ ] 错误率 < 0.1%（/sls-log 查 ERROR）
- [ ] 核心 happy path 走通
- [ ] 业务漏斗与上线前持平
**坑**：技术 OK 但业务掉 50%（expand 漏字段）；没等观察期就 ⑤。

## ⑦ 回滚预案
**触发**：错误率>1%（5min）/ 核心功能 DOWN / 漏斗跌>30% / 投诉>10/min。
**决策人**：{开发} / {运维}，5min 内拍板。
**代码回滚**：
```bash
kubectl set image deployment/{SVC} {SVC}=registry.../{SVC}:{LAST_TAG}
```
**数据层**：③ expand 的结构保留不删（不影响旧代码）。⚠️ 已执行 ⑤ → 数据不可逆，联系 DBA 用备份恢复。
```

---

## 阶段 4：生成运维版（极简，零废话）

> **铁律**：**没有任何「为什么」「坑」「做什么」解释**。只有：命令 + 验证 + 失败处理。最长 ~80 行。

### 模板

```markdown
# 上线 · {DATE} · {SLUG}

> 制品: `v{DATE}-1` ｜ 回滚: `{LAST_TAG}` ｜ 方式: {DEPLOY_STRATEGY}
>
> 任一步失败 → 立即停 → 通知开发 → 走 §⑦

## ② 制品
```bash
git tag -a v{DATE}-1 -m "release: {SLUG}" && git push origin v{DATE}-1
```

## ③ 数据前置（SQL→ES→MQ，全部成功才进 ④）

### SQL
```sql
{cat 出的 SQL 内容，直接内联，运维可直接复制执行}
```
✅ `SELECT COUNT(*) FROM information_schema.columns WHERE ...` → 期望 1

### ES
```bash
curl -X PUT "{ES}/{IDX}_v2" -d '@{文件}'
curl -X POST "{ES}/_reindex?wait_for_completion=false" -d '{...}'
# 等 reindex 完成后切 alias
curl -X POST "{ES}/_aliases" -d '{"actions":[{"remove":{"index":"{IDX}_v1","alias":"{IDX}"}},{"add":{"index":"{IDX}_v2","alias":"{IDX}"}}]}'
```
✅ `GET {ES}/_cat/indices/{IDX}_v2?v`

## ④ 部署
```bash
kubectl set image deployment/{SVC} {SVC}=registry.../{SVC}:v{DATE}-1
kubectl rollout status deployment/{SVC}
curl -f http://{HOST}:{PORT}/actuator/health
```
❌ DOWN → 切 {LAST_TAG} → 通知开发

## ⑤ 数据后置（⑥ 通过后）

### SQL DROP
```sql
{cat 出的 DROP SQL}
```

### ES / MQ
```bash
curl -X DELETE "{ES}/{IDX}_v1"
kafka-topics.sh --delete --topic {TOPIC}_v1
```

## ⑥ 验证
- `/sls-log "ERROR"` 查生产
- 核心 happy path：登录 → 创建 → 评分 → 导出
- 监控：错误率、P99、漏斗

## ⑦ 回滚
**触发**：错误率>1% / 核心DOWN / 漏斗跌>30%
```bash
kubectl set image deployment/{SVC} {SVC}=registry.../{SVC}:{LAST_TAG}
```
数据层 expand 结构保留不删。已执行 ⑤ → 联系 DBA。
```

---

## 阶段 5：边界处理

| 场景 | 处理 |
|------|------|
| 项目类型探测失败 | AskUserQuestion 让用户选 |
| `docs/releases/` 不存在 | `mkdir -p` 自动建 |
| 同日重名 | 文件名加 `-2` `-3` |
| SQL 含 DROP + 全量上线 | 自用版头部红色警告 |
| SQL 文件扫到 → **必读内容** | `cat` 内联到文档，不引用路径 |
| ES mapping 文件 | 同样 cat 内容内联 |
| 扫到但用户在 Q1 取消勾选 | 不内联，标注「检测到但跳过」 |

---

## 阶段 6：输出

```
✅ 生成完成：
  自用版：docs/releases/{DATE}-{SLUG}-self.md ({X} 行)
  运维版：docs/releases/{DATE}-{SLUG}-ops.md ({Y} 行)

📌 风险：
  - ⚠️ xxx

💡 下一步：
  1. review ⑦ 回滚预案
  2. 运维版复制到飞书交接
  3. 上线后 /sls-log 验证
```

---

## 注意事项

1. **不执行任何上线动作** — 只生成 markdown
2. **SQL/ES 内容必须内联** — `cat` 出来嵌入，不引用文件路径
3. **精简优先** — 自用 ≤150 行，运维 ≤80 行；单行优先于段落
4. **运维版零解释** — 只有命令+验证+失败处理
5. **顺序约束固定** — 自用版顶部必含「顺序」和「核心约束」两行
