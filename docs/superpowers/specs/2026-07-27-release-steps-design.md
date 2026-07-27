# `/release-steps` 上线步骤生成器设计

> **创建日期**：2026-07-27
> **作者**：chenyan
> **状态**：Draft → 待用户 review

---

## 1. 背景与目标

### 1.1 痛点

当前仓库已有 `/ship`（验证+commit+push）和 `/sync-push`（合并到 test 分支），但都停在「代码推到远程」这一步。**真正的「上线」是代码合并 main 之后到生产环境验证通过的全过程**，目前没有标准化产物。

作者本人是前端开发，正在学后端，对后端上线的关键约束（如 SQL 变更顺序、ES reindex 时机、回滚锚点）理解还不够深。运维同事拿到的是飞书消息/口头交接，缺少一份确定性的「按这个步骤执行」清单。

### 1.2 目标

构建一个 Slash 命令 `/release-steps`，在需求开发完成、准备上线时调用，**动态生成两份 markdown 清单**：

- **自用详细版**（`*-self.md`）：每个阶段含「做什么 / 为什么这个顺序 / 怎么验证 / 常见坑」，是后端上线知识传递的载体
- **运维简洁版**（`*-ops.md`）：只含「执行动作 + 命令 + 失败处理」，运维可以直接照抄执行

### 1.3 非目标

- ❌ 不执行任何上线动作（纯文档生成）
- ❌ 不替代 CI/CD pipeline
- ❌ 不替代 `/ship`（commit/push）和 `/sync-push`（合 test）
- ❌ 不写死任何具体项目名（跨项目通用）

---

## 2. 核心设计：阶段流水线

### 2.1 七阶段拓扑

```
① 上线前自查
② 制品构建 + Tag 记录       ← 回滚锚点
③ 数据层变更【前置】         ← SQL add column / ES 新索引 / MQ 新 topic
④ 部署执行                  ← 代码上线到生产
⑤ 数据层变更【后置】         ← SQL drop old column / ES 删旧索引
⑥ 上线后验证
⑦ 回滚预案
```

### 2.2 顺序约束（为什么必须这个顺序）

| 阶段顺序 | 顺序原因 | 颠倒后果 |
|---------|---------|---------|
| ② → ③ | 先有制品 tag 才能回滚到具体版本 | 回滚时找不到锚点 |
| ③ → ④（前置变更先于部署） | 旧代码 + 新数据 = 仍可运行；新代码 + 新数据 = 可运行 | 新代码上线后才发现字段没建出来 → 生产报错 |
| ④ → ⑤（清理变更后于部署） | 必须确认新代码全部生效、旧代码全部下线后才能删旧 | 旧代码还在读到「已删除」字段 → 生产报错 |
| ④ → ⑥ | 部署后才能验证生产实际行为 | 验证的是非生产状态，没意义 |
| ⑥ → ⑤ | 验证通过才能清理；验证失败 → 走 ⑦ 回滚，**绝不进入 ⑤** | 错误的清理让回滚也无法恢复 |

### 2.3 数据层变更的核心模式：Expand-and-Contract

数据层变更（SQL/ES/MQ/Redis/Nacos）走 **expand-and-contract 模式**，分两次执行：

- **Expand（③ 前置）**：只做"加"动作 — `ADD column`、新建 ES index v2、新建 MQ topic、新增 Nacos key。**旧代码依然能跑，新代码也能用。**
- **Contract（⑤ 后置）**：才做"删"动作 — `DROP old column`、删 ES index v1、删旧 MQ topic。**等到确认没有旧代码读旧结构后再清理。**

**特殊情况**：含 `DROP`/`RENAME`/类型变更的 SQL，**必须分两次上线**（本次只 expand，下次上线再 contract），不能在一次上线里完成。

---

## 3. 双版本差异

### 3.1 自用版结构（每个阶段固定 5 小节）

```markdown
## 阶段 X：xxx

### 这个阶段在做什么
（一句话目标）

### 为什么必须放在这个顺序
（后端知识 — 如"SQL 必须在代码部署前，否则新代码读不到字段"）

### 检查项（Checklist）
- [ ] xxx
- [ ] xxx

### 怎么验证这一步通过了
（具体命令/SQL/查询）

### 常见坑（事故案例）
（容易翻车的地方）
```

**自用版额外加一节**：「数据层变更决策树」（见 §3.3）

### 3.2 运维版结构（每阶段 ≤ 5 行）

```markdown
## ③ 数据层变更【前置】
执行顺序：SQL → ES → MQ，必须全部成功才进入 ④

1. 执行 SQL（按文件顺序）：
   mysql -h xxx < migrations/2026-07-27-add-column.sql
   ✅ 验证：SELECT COUNT(*) FROM information_schema.columns WHERE ...

2. ES 创建新索引 v2 + reindex：
   curl -X PUT ...
   ✅ 验证：GET _cat/indices?v

❌ 任一步失败 → 立即停止 → 通知开发，按 ⑦ 回滚预案处理
```

**铁律**：运维版**不含「为什么」**，只含「做什么 + 命令 + 失败处理」。运维要的是确定性，不是教学。

### 3.3 数据层变更决策树（自用版独有）

```
本次需求涉及数据层吗？
├─ 否 → 跳过 ③⑤
├─ 仅 SQL（向前兼容的 ADD COLUMN）→ ③ 前置执行
├─ SQL 含 DROP / RENAME / 类型变更 → 必须分两次上线（本次 ③，下次 ⑤）
├─ ES mapping 变更 → reindex 策略（新建 v2 索引 → reindex → 切别名 → 删 v1）
├─ Redis key 结构变更 → 双写过渡期 + 旧 key 设 TTL 自动失效
├─ MQ topic 变更 → 新 topic 双写 + 消费者切换 + 旧 topic 待无消息后删
├─ Nacos / Apollo 配置变更 → 区分"动态生效"vs"需重启"
├─ 定时任务（XXL-Job 等）→ 上线前先停调度 → 上线后启动
└─ CDN / 静态资源 → 版本号指纹 + 缓存预热
```

---

## 4. 命令规格

### 4.1 Frontmatter

```yaml
---
allowed-tools: Bash(git *), Bash(grep *), Bash(find *), Bash(cat *), Bash(ls *), AskUserQuestion, Write, Read, Glob, Grep
description: 生成本次上线的双版本步骤清单 — 自用详细版（含为什么）+ 运维执行版（仅命令）
argument-hint: [需求简述，可选 — 不填则从 git context 自动推断]
---
```

### 4.2 执行流程

```
1. 探测项目类型
   ├─ pom.xml / build.gradle → Java 后端
   ├─ package.json + src/server → Node 后端
   ├─ package.json + src/ 无 server → 前端
   ├─ Dockerfile / docker-compose.yml → 容器化
   └─ 多个并存 → 让用户选

2. 自动收集 context
   ├─ 当前分支名（git branch --show-current）
   ├─ 与 main/master 的 commits 列表（git log main..HEAD）
   ├─ diff 中的文件类型分布（git diff main...HEAD --name-only）
   ├─ 扫描数据层变更痕迹：
   │   - *.sql / migrations/ / flyway / liquibase
   │   - es-mapping / index-template
   │   - redis key 前缀定义
   │   - nacos/apollo config diff
   └─ 最近一次生产 tag（git describe --tags --abbrev=0）

3. AskUserQuestion 交互（3 个关键问题）
   ├─ Q1：本次有没有 SQL/ES/MQ/Redis/Nacos 变更？（自动检测结果 + 用户确认）
   ├─ Q2：上线方式？（全量 / 灰度 / 蓝绿 / 分批）
   └─ Q3：特殊回滚点？（如必须保留某个 commit、DB 备份策略）

4. 生成双版本 markdown
   ├─ docs/releases/YYYY-MM-DD-{slug}-self.md
   └─ docs/releases/YYYY-MM-DD-{slug}-ops.md

5. 输出汇总
   ├─ 两份文件路径
   ├─ 一句话总结本次上线的关键风险点
   └─ 提示用户：「运维版可直接复制到飞书/钉钉交接」
```

### 4.3 输出文件命名

```
docs/releases/
├── 2026-07-27-user-export-feature-self.md   ← 自用详细版
├── 2026-07-27-user-export-feature-ops.md    ← 运维版
└── ...
```

**slug 规则**：从用户参数或最近 commit message 提取，转 kebab-case，限 30 字符。

---

## 5. 七阶段详细内容规格

> 下面是模板生成时的「种子内容」。命令执行时根据项目类型、用户回答动态填充。

### 阶段 ① 上线前自查

**自用版要解释**：这一步把"应该想到的"全部前置，避免上线到一半发现依赖没准备。
**Checklist**：
- [ ] 本次上线的需求 PRD / RFC 链接已附在文档头
- [ ] 与 main/master 的 diff 已 review，无 debug 代码、无 console.log、无 TODO
- [ ] 依赖的下游服务版本已对齐（如调用的下游 API 已上线）
- [ ] 灰度/全量策略已确认
- [ ] 上线窗口已和运维对齐（避开业务高峰）
- [ ] 回滚预案 §⑦ 已填写完整

**运维版**：跳过此阶段（这是开发责任，不交接给运维）。

### 阶段 ② 制品构建 + Tag 记录

**自用版要解释**：tag 是回滚的锚点。没有 tag，回滚时不知道回到哪。
**Checklist**：
- [ ] CI/CD 已触发，构建成功
- [ ] 制品版本号已记录（jar 版本 / Docker image tag / 制品库 URL）
- [ ] git tag 已打并推送：`git tag -a vYYYYMMDD-N -m "release: <slug>"`
- [ ] 旧制品版本号已记录（用于回滚）

**运维版**：仅记录两条 — 本次制品 tag、上一版本 tag。

### 阶段 ③ 数据层变更【前置】

**自用版要解释**：见 §2.3 expand-and-contract。
**Checklist（按数据层类型动态展开）**：
- [ ] SQL：DDL 已在测试库执行并验证；DML 已准备（数据回填脚本）
- [ ] ES：新索引 mapping 已在测试环境创建并 reindex 验证
- [ ] Redis：双写策略已确认；旧 key TTL 已设
- [ ] MQ：新 topic 已创建；消费者订阅已切换
- [ ] Nacos/Apollo：新 key 已下发；动态 vs 重启生效已区分

**运维版**：按数据层类型给出具体命令 + 验证 SQL/curl。

### 阶段 ④ 部署执行

**自用版要解释**：部署顺序决定爆炸半径。通常「无状态服务先、有状态服务后；边缘服务先、核心服务后」。
**Checklist**：
- [ ] 部署顺序已确认（如：gateway → service-a → service-b → consumer）
- [ ] 每个服务部署后立即健康检查（健康检查脚本/端点）
- [ ] 灰度策略（如 10% → 50% → 100%）执行中
- [ ] 部署过程中监控告警 dashboard 已打开

**运维版**：列出每个服务的部署命令 + 健康检查命令 + 失败处理（重启回滚）。

### 阶段 ⑤ 数据层变更【后置】

**自用版要解释**：见 §2.3 contract 阶段。**只在 §⑥ 验证全部通过后才执行**。
**Checklist**：
- [ ] 确认无任何旧代码在访问待清理对象（APM/日志/调用统计）
- [ ] 备份待删除对象（旧索引快照、旧表导出）
- [ ] 执行删除（DROP column / 删 ES index v1 / 删旧 MQ topic）
- [ ] 验证清理后系统正常

**运维版**：仅含「删除命令 + 验证命令」。

### 阶段 ⑥ 上线后验证

**自用版要解释**：分「技术验证」和「业务验证」。技术 OK 不代表业务 OK。
**Checklist**：
- [ ] 技术验证：健康检查、错误率、延迟、资源占用
- [ ] 业务验证：核心 happy path 走通（提供具体测试用例）
- [ ] 日志验证：`/sls-log` 查关键路径无 ERROR
- [ ] 监控验证：核心指标符合预期（QPS、成功率、业务漏斗）

**运维版**：列出具体监控 dashboard URL + 健康检查 endpoint + 报警阈值。

### 阶段 ⑦ 回滚预案

**自用版要解释**：回滚不是"上线失败的退路"，是"上线计划的一部分"。上线前必须填好。
**Checklist**：
- [ ] 触发回滚的条件（错误率 > X%、核心功能不可用、数据异常）
- [ ] 决策人（谁能拍板回滚）
- [ ] 回滚动作：制品切回 §② 记录的旧版本 + DB 用 §③ 备份恢复
- [ ] 回滚验证：与 §⑥ 同等验证

**运维版**：仅含「触发条件 + 回滚命令 + 验证命令」。

---

## 6. 边界情况与失败处理

| 场景 | 处理 |
|------|------|
| 项目类型探测失败 | AskUserQuestion 让用户选 |
| `docs/releases/` 目录不存在 | 自动创建 |
| 同一天同一 slug 已有文件 | 文件名加序号后缀 `-2`、`-3` |
| 用户跳过 AskUserQuestion | 用全部默认值生成（标注"未确认"） |
| 检测到 SQL 含 DROP 但用户选了"全量一次上线" | 自用版**红色警告**，强制提示分两次 |

---

## 7. 与现有命令的关系

| 命令 | 职责 | 关系 |
|------|------|------|
| `/sync-push` | 提交+推送+合 test 分支 | 上线**前**的测试环境部署 |
| `/ship` | 全量验证+commit+push（当前分支） | 上线**前**的代码层动作 |
| **`/release-steps`**（新） | 生成上线步骤双版本清单 | 上线**时**的执行手册 |
| `/test-log` | 测试服务器日志 | 上线后 §⑥ 验证可用 |
| `/sls-log` | 生产 SLS 日志 | 上线后 §⑥ 验证必用 |

**完整时间线**：
```
开发完 → /ship（commit+push）→ /sync-push（合 test）→ 测试验证 →
合并 main → /release-steps（生成清单）→ 按清单执行上线 → /sls-log 验证
```

---

## 8. 验证标准

- ✅ 命令文件创建：`core/commands/release-steps.md`
- ✅ 调用 `/release-steps "测试需求"` 在 `docs/releases/` 生成两份 markdown
- ✅ 自用版含七阶段 + 数据层决策树 + 每阶段 5 小节
- ✅ 运维版含执行命令 + 验证命令 + 失败处理，不含「为什么」
- ✅ 同步到 `~/.claude/commands/release-steps.md` 后可被 Claude Code 识别

---

## 9. 后续迭代（YAGNI 砍掉，留作 backlog）

- 多项目联合上线（一次生成多份）
- 从 GitLab MR 自动拉取变更列表填入
- 与 Prometheus / Grafana API 集成，自动填监控 URL
- 上线后实际回填执行结果（变成上线记录而非清单）
