# API Integration Testing - 快速开始指南

## 概述

这个skill帮助你完成前后端API联调测试的完整流程，从接口文档解析到E2E测试，最终生成飞书文档报告。

## 已安装的文件

✅ **Skill主文件**: `~/.claude/skills/api-integration-testing/SKILL.md`
✅ **工作流命令**: `~/.claude/skills/api-integration-testing/commands/run-workflow.md`
✅ **OpenClaw集成指南**: `~/.claude/skills/api-integration-testing/OPENCLAW_INTEGRATION.md`

## 快速使用

### 方式1: 直接对话（最简单）

直接告诉我你的需求，例如：

```
我有一个用户管理模块的API文档，需要进行前后端联调测试，
文档路径是 /path/to/api-docs.json
```

我会自动：
1. 解析API文档
2. 按功能模块分组接口
3. 生成集成测试代码
4. 创建E2E测试
5. 执行测试
6. 生成飞书文档报告

### 方式2: 使用Agent

```javascript
// 调用agent执行完整工作流
Agent({
  subagent_type: "general-purpose",
  prompt: `
    参考 api-integration-testing skill，执行API联调测试：
    - API文档: /path/to/api-docs.json
    - 项目名称: 用户管理系统
    - 测试环境: http://localhost:3000
  `
})
```

### 方式3: 命令行（需要重启Claude Code）

```bash
# 重启Claude Code后可用
/api-test run-workflow --input api-docs.json --project "用户管理系统"
```

## 典型工作流

### 场景1: 新接口联调测试

```
1. 后端提供API文档（Swagger/OpenAPI/Markdown）
2. 告诉我："帮我测试这个API文档的接口"
3. 我会：
   - 解析文档，提取所有接口
   - 按功能模块分组
   - 生成测试代码
   - 执行测试
   - 生成报告
```

### 场景2: 特定功能模块测试

```
"只测试用户管理模块的接口，包括注册、登录、个人信息"

我会：
- 只针对指定模块生成测试
- 测试接口之间的依赖关系
- 验证完整的业务流程
```

### 场景3: E2E测试

```
"为用户注册登录流程创建E2E测试"

我会：
- 使用Playwright创建E2E测试
- 模拟真实用户操作
- 验证前后端交互
- 截图记录关键步骤
```

## 输出示例

### 测试报告结构

```markdown
# API联调测试报告

**项目**: 用户管理系统
**日期**: 2026-03-18
**测试人员**: [你的名字]

## 测试概览
- 总接口数: 15
- 测试通过: 13
- 测试失败: 2
- 通过率: 86.7%

## 功能模块详情

### 1. 用户管理

#### 1.1 用户注册 (POST /api/users/register)
**前端**: ✅ 通过
**后端**: ✅ 通过 (响应时间: 120ms)
**E2E**: ✅ 通过

#### 1.2 用户登录 (POST /api/users/login)
**前端**: ⚠️ 部分通过
- 问题: 错误提示不够明确
**后端**: ✅ 通过 (响应时间: 95ms)
**E2E**: ✅ 通过

### 2. 数据管理
[...]

## 问题汇总
1. [P1] 用户登录错误提示需要优化
2. [P2] 文件上传接口响应时间过长

## 飞书文档链接
https://example.feishu.cn/docs/xxx
```

## OpenClaw集成

### 在OpenClaw服务器上使用

#### 方案A: 直接在服务器安装Claude Code

```bash
# SSH到OpenClaw服务器
ssh -i ~/.ssh/aliyun_openclaw root@47.89.150.106

# 安装Node.js和Claude Code
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
npm install -g @anthropic-ai/claude-code

# 配置API密钥
mkdir -p ~/.claude
cat > ~/.claude/settings.json <<EOF
{
  "env": {
    "ANTHROPIC_API_KEY": "your-api-key",
    "ANTHROPIC_MODEL": "claude-sonnet-4-6"
  }
}
EOF

# 复制skill文件
scp -i ~/.ssh/aliyun_openclaw -r ~/.claude/skills/api-integration-testing root@47.89.150.106:~/.claude/skills/

# 测试
claude-code chat "测试API联调功能"
```

#### 方案B: OpenClaw通过API调用本地Claude Code

详见 `OPENCLAW_INTEGRATION.md` 文档。

## 配置飞书集成

### 1. 获取飞书应用凭证

```bash
# 访问飞书开放平台
https://open.feishu.cn/

# 创建企业自建应用
# 获取 App ID 和 App Secret
```

### 2. 配置环境变量

```bash
# 在 ~/.claude/settings.json 中添加
{
  "env": {
    "FEISHU_APP_ID": "your-app-id",
    "FEISHU_APP_SECRET": "your-app-secret",
    "FEISHU_FOLDER_TOKEN": "your-folder-token"
  }
}
```

### 3. 测试飞书集成

```typescript
// 测试创建文档
import { FeishuClient } from '@feishu/api'

const client = new FeishuClient({
  appId: process.env.FEISHU_APP_ID,
  appSecret: process.env.FEISHU_APP_SECRET
})

const doc = await client.docs.create({
  title: '测试文档',
  content: '# 测试内容'
})

console.log('文档链接:', doc.url)
```

## 常见问题

### Q: 如何处理需要认证的API？

A: 在测试代码中先调用登录接口获取token，然后在后续请求中使用：

```typescript
// 先登录
const loginRes = await api.post('/api/login', { username, password })
const token = loginRes.data.token

// 使用token
api.setToken(token)
const profileRes = await api.get('/api/profile')
```

### Q: 如何测试文件上传接口？

A: 使用FormData：

```typescript
const formData = new FormData()
formData.append('file', fs.createReadStream('test.jpg'))

const response = await api.post('/api/upload', formData, {
  headers: { 'Content-Type': 'multipart/form-data' }
})
```

### Q: E2E测试失败怎么办？

A: 检查以下几点：
1. 前端应用是否正常运行
2. API服务是否可访问
3. 测试数据是否正确
4. 选择器是否正确（data-testid）

### Q: 如何自定义报告格式？

A: 修改报告模板：

```typescript
// 在 tests/utils/report-generator.ts 中
export function generateReport(results: TestResult[]) {
  // 自定义报告格式
  return `
# 自定义报告

${results.map(r => formatResult(r)).join('\n')}
  `
}
```

## 下一步

1. **准备API文档** - 确保有完整的接口文档
2. **配置测试环境** - 设置API base URL
3. **开始测试** - 直接告诉我你的需求
4. **查看报告** - 获取飞书文档链接

## 示例命令

```bash
# 完整工作流
"帮我测试 /path/to/api-docs.json 的所有接口，生成飞书报告"

# 只测试特定模块
"只测试用户管理模块的接口"

# 只生成E2E测试
"为登录流程创建E2E测试"

# 只生成报告
"根据测试结果生成飞书文档"
```

## 需要帮助？

直接告诉我你的需求，我会引导你完成整个流程！

例如：
- "我有一个API文档需要测试"
- "帮我配置OpenClaw调用Claude Code"
- "如何生成飞书报告"
