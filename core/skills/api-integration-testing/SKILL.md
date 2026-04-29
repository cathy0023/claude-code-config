---
name: api-integration-testing
description: Frontend-Backend API integration testing workflow. Parse API docs, perform integration tests by feature, run E2E tests, and generate comprehensive Feishu documentation.
origin: custom
version: 1.0.0
---

# API Integration Testing

前后端API联调测试完整工作流，从接口文档解析到E2E测试，最终生成飞书文档报告。

## 何时使用

- 后端提供了新的API接口文档
- 需要进行前端联调测试
- 按功能模块测试接口集成
- 执行端到端测试验证
- 生成测试报告和文档

## 工作流程

### 1. 接口文档解析
```
输入: API文档（Swagger/OpenAPI/Markdown）
输出: 结构化的接口清单
- 按功能模块分组
- 提取接口路径、方法、参数
- 识别依赖关系
```

### 2. 功能模块划分
```
根据业务功能将接口分组：
- 用户管理（登录、注册、个人信息）
- 数据管理（CRUD操作）
- 文件上传/下载
- 权限控制
- 等等...
```

### 3. 联调测试执行

#### 3.1 单接口测试
```typescript
// 测试单个接口
describe('POST /api/users/login', () => {
  test('成功登录', async () => {
    const response = await api.post('/api/users/login', {
      username: 'test@example.com',
      password: 'password123'
    })

    expect(response.status).toBe(200)
    expect(response.data).toHaveProperty('token')
    expect(response.data).toHaveProperty('user')
  })

  test('错误的密码', async () => {
    const response = await api.post('/api/users/login', {
      username: 'test@example.com',
      password: 'wrongpassword'
    })

    expect(response.status).toBe(401)
    expect(response.data.error).toBeDefined()
  })
})
```

#### 3.2 功能流程测试
```typescript
// 测试完整的业务流程
describe('用户注册登录流程', () => {
  test('完整流程', async () => {
    // 1. 注册新用户
    const registerRes = await api.post('/api/users/register', {
      username: 'newuser@example.com',
      password: 'password123'
    })
    expect(registerRes.status).toBe(201)

    // 2. 登录
    const loginRes = await api.post('/api/users/login', {
      username: 'newuser@example.com',
      password: 'password123'
    })
    expect(loginRes.status).toBe(200)
    const token = loginRes.data.token

    // 3. 获取用户信息
    const profileRes = await api.get('/api/users/profile', {
      headers: { Authorization: `Bearer ${token}` }
    })
    expect(profileRes.status).toBe(200)
    expect(profileRes.data.username).toBe('newuser@example.com')
  })
})
```

### 4. E2E测试

使用Playwright进行端到端测试：

```typescript
import { test, expect } from '@playwright/test'

test.describe('用户管理E2E测试', () => {
  test('用户注册登录完整流程', async ({ page }) => {
    // 1. 访问注册页面
    await page.goto('/register')

    // 2. 填写注册表单
    await page.fill('[data-testid="username"]', 'test@example.com')
    await page.fill('[data-testid="password"]', 'password123')
    await page.click('[data-testid="register-btn"]')

    // 3. 验证跳转到登录页
    await expect(page).toHaveURL('/login')

    // 4. 登录
    await page.fill('[data-testid="username"]', 'test@example.com')
    await page.fill('[data-testid="password"]', 'password123')
    await page.click('[data-testid="login-btn"]')

    // 5. 验证登录成功
    await expect(page).toHaveURL('/dashboard')
    await expect(page.locator('[data-testid="user-name"]')).toContainText('test@example.com')
  })
})
```

### 5. 测试报告生成

#### 5.1 测试结果收集
```typescript
interface TestResult {
  feature: string          // 功能模块
  apiEndpoint: string      // 接口路径
  method: string           // HTTP方法
  status: 'pass' | 'fail'  // 测试状态
  frontend: {
    status: 'pass' | 'fail'
    issues: string[]
    notes: string
  }
  backend: {
    status: 'pass' | 'fail'
    responseTime: number
    issues: string[]
    notes: string
  }
  e2eTest: {
    status: 'pass' | 'fail'
    screenshotPath?: string
    issues: string[]
  }
}
```

#### 5.2 飞书文档格式

```markdown
# API联调测试报告

**项目名称**: [项目名]
**测试日期**: YYYY-MM-DD
**测试人员**: [姓名]
**测试环境**: [开发/测试/预发布]

## 测试概览

| 指标 | 数值 |
|------|------|
| 总接口数 | XX |
| 测试通过 | XX |
| 测试失败 | XX |
| 通过率 | XX% |

## 功能模块测试详情

### 1. 用户管理

#### 1.1 用户注册 (POST /api/users/register)

**前端状态**: ✅ 通过
- UI交互正常
- 表单验证完整
- 错误提示清晰

**后端状态**: ✅ 通过
- 响应时间: 120ms
- 数据格式正确
- 错误处理完善

**E2E测试**: ✅ 通过
- 完整流程验证通过
- 截图: [链接]

**问题记录**: 无

---

#### 1.2 用户登录 (POST /api/users/login)

**前端状态**: ⚠️ 部分通过
- UI交互正常
- 表单验证完整
- 问题: 登录失败时错误提示不够明确

**后端状态**: ✅ 通过
- 响应时间: 95ms
- Token生成正常
- 错误处理完善

**E2E测试**: ✅ 通过
- 完整流程验证通过

**问题记录**:
1. 前端需要优化错误提示文案
2. 建议添加"记住我"功能

---

### 2. 数据管理

[继续其他功能模块...]

## 问题汇总

### 前端问题
1. [P1] 用户登录错误提示不明确
2. [P2] 列表页加载动画缺失

### 后端问题
1. [P1] 文件上传接口响应时间过长（>2s）
2. [P2] 分页参数验证不完整

### E2E测试问题
1. [P1] 文件上传流程测试失败

## 测试结论

✅ 核心功能测试通过
⚠️ 存在X个需要修复的问题
📋 建议在下次迭代中优化Y个体验问题

## 后续行动

1. 修复P1级别问题
2. 优化前端错误提示
3. 改进后端响应时间
4. 补充缺失的E2E测试用例
```

## 测试最佳实践

### 1. 测试数据准备
```typescript
// 使用工厂函数创建测试数据
const createTestUser = () => ({
  username: `test_${Date.now()}@example.com`,
  password: 'Test123!@#',
  name: 'Test User'
})

// 测试前清理数据
beforeEach(async () => {
  await cleanupTestData()
})

// 测试后清理数据
afterEach(async () => {
  await cleanupTestData()
})
```

### 2. 错误场景测试
```typescript
// 测试各种错误场景
test('处理网络错误', async () => {
  // 模拟网络错误
  mockNetworkError()

  const response = await api.post('/api/users/login', {
    username: 'test@example.com',
    password: 'password123'
  })

  expect(response.error).toBeDefined()
  expect(response.error.type).toBe('NetworkError')
})

test('处理超时', async () => {
  // 设置超时
  api.setTimeout(100)

  const response = await api.post('/api/slow-endpoint', {})

  expect(response.error).toBeDefined()
  expect(response.error.type).toBe('TimeoutError')
})
```

### 3. 性能测试
```typescript
test('接口响应时间', async () => {
  const startTime = Date.now()

  await api.get('/api/users/list')

  const duration = Date.now() - startTime
  expect(duration).toBeLessThan(500) // 响应时间应小于500ms
})
```

## 工具集成

### Claude Code集成
```bash
# 使用Claude Code生成测试用例
claude-code generate-tests --api-doc swagger.json --output tests/

# 执行测试
claude-code run-tests --feature user-management

# 生成报告
claude-code generate-report --format feishu --output report.md
```

### 飞书文档API
```typescript
// 自动上传测试报告到飞书
import { FeishuClient } from '@feishu/api'

const client = new FeishuClient({
  appId: process.env.FEISHU_APP_ID,
  appSecret: process.env.FEISHU_APP_SECRET
})

async function uploadReport(reportContent: string) {
  const doc = await client.docs.create({
    title: `API联调测试报告 - ${new Date().toLocaleDateString()}`,
    content: reportContent,
    folder_token: process.env.FEISHU_FOLDER_TOKEN
  })

  console.log(`报告已上传: ${doc.url}`)
  return doc.url
}
```

## 配置文件

### api-test.config.ts
```typescript
export default {
  // API基础URL
  baseURL: process.env.API_BASE_URL || 'http://localhost:3000',

  // 超时设置
  timeout: 5000,

  // 测试环境
  env: process.env.TEST_ENV || 'development',

  // 飞书配置
  feishu: {
    appId: process.env.FEISHU_APP_ID,
    appSecret: process.env.FEISHU_APP_SECRET,
    folderToken: process.env.FEISHU_FOLDER_TOKEN
  },

  // E2E测试配置
  e2e: {
    headless: true,
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  }
}
```

## 命令行工具

```bash
# 解析API文档
npm run test:parse-api-doc -- --input swagger.json

# 运行联调测试
npm run test:integration -- --feature user-management

# 运行E2E测试
npm run test:e2e -- --feature user-management

# 生成飞书报告
npm run test:report -- --format feishu --upload

# 完整流程
npm run test:full-flow
```

## 注意事项

1. **测试隔离**: 每个测试用例应该独立，不依赖其他测试
2. **数据清理**: 测试前后清理测试数据，避免污染
3. **环境变量**: 敏感信息使用环境变量，不要硬编码
4. **错误处理**: 充分测试各种错误场景
5. **性能监控**: 记录接口响应时间，发现性能问题
6. **文档同步**: 测试报告及时上传到飞书，保持团队同步

---

**记住**: 好的测试不仅验证功能正确性，还要确保用户体验和系统性能。
