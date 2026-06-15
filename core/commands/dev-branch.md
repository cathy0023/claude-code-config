---
description: 拉取最新主分支代码后创建需求分支，分支名 = 类型/核心意思-当前日期
allowed-tools: Bash
argument-hint: <自然语言描述>
# examples:
#   - /dev-branch 共享屏幕演讲融合到陪练项目
#   - /dev-branch 修复登录页面崩溃问题
#   - /dev-branch 重构认证模块
---

# dev-branch

拉取最新主分支代码，然后基于最新主分支创建新分支。分支名采用「核心意思 + 当前日期」方式。

## 分支命名规范

格式：`(feat|fix|refactor|docs|test|perf|ci|chore|hotfix|release|main)/<简短英文描述>-<YYYYMMDD>`

合法示例：`feat/shared-screen-speaking-20250523`、`fix/login-crash-20250523`

## 执行逻辑

### 第一步：判断分支类型

根据描述语义判断类型：

| 关键词 | 类型 |
|--------|------|
| 新需求、新功能、新增、feature、feat | feat |
| Bug 修复、fix、bug、崩溃、异常、报错 | fix |
| 紧急、hotfix、线上故障 | hotfix |
| 重构、refactor、优化结构 | refactor |
| 性能、perf、优化性能、加速 | perf |
| 文档、docs | docs |
| 测试、test、补测试 | test |
| CI/CD、流水线、构建脚本、ci | ci |
| 配置、依赖、杂项、chore | chore |
| 发布、release、版本切版 | release |

无法判断时默认使用 `feat`。

### 第二步：生成简短英文描述

将中文描述转为简短英文 slug：
- 提取核心语义，忽略"新需求:"、"新增"等前缀
- 全部小写，单词间用 `-` 连接
- 控制在 2~4 个单词，保持可读性

示例：`共享屏幕演讲融合到陪练项目` → `shared-screen-speaking`

### 第三步：获取当前日期

使用 `date +%Y%m%d` 获取当前日期（YYYYMMDD 格式），作为分支名后缀。

### 第四步：构造并确认分支名

组合为：`<type>/<slug>-<YYYYMMDD>`，**展示给用户确认后再执行**：

```
将创建分支：feat/shared-screen-speaking-20250523
基于：main（将先拉取最新代码）

确认？[Y/n]
```

用户输入 `Y`、`y` 或直接回车则继续；输入 `n` 则取消。

### 第五步：确定基础分支

优先 `main`，其次 `master`，两者都不存在则报错退出。

### 第六步：检查是否有未提交的变更

如果有未暂存或已暂存的变更，提示用户：

```
警告：工作区有未提交的变更。建议先提交或暂存（stash）后再操作。
```

询问是否继续。

### 第七步：拉取最新主分支代码

切换到基础分支并拉取最新代码：

```bash
git switch <base-branch>
git pull origin <base-branch>
```

如果 pull 失败（如网络问题或冲突），报错退出，不要继续创建分支。

### 第八步：检查分支是否已存在

若已存在：
```
错误：分支 feat/shared-screen-speaking-20250523 已存在。
```

### 第九步：创建并切换分支

```bash
git switch -c <branch-name> <base-branch>
```

### 第十步：输出结果

```
✓ 已拉取最新 main 代码
✓ 已从 main 创建并切换到：feat/shared-screen-speaking-20250523
```
