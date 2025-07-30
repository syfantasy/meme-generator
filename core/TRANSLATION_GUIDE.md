# 翻译功能配置指南

meme-generator 现在支持两种翻译服务：百度翻译和OpenAI格式翻译。

## 配置方式

### 1. 配置文件方式

复制 `config.example.toml` 为 `config.toml`，然后修改翻译相关配置：

```toml
[translate]
# 翻译服务类型: "baidu" 或 "openai"
translator_type = "openai"

# 百度翻译配置（当translator_type为"baidu"时使用）
baidu_trans_appid = "your_baidu_appid"
baidu_trans_apikey = "your_baidu_apikey"

# OpenAI格式翻译配置（当translator_type为"openai"时使用）
openai_api_base = "https://api.openai.com"
openai_api_key = "your_openai_api_key"
openai_model = "gpt-3.5-turbo"
openai_timeout = 30
```

### 2. 环境变量方式

复制 `.env.example` 为 `.env`，然后设置相应的环境变量：

```bash
# 翻译服务类型
TRANSLATOR_TYPE=openai

# OpenAI配置
OPENAI_API_BASE=https://api.openai.com
OPENAI_API_KEY=your_openai_api_key
OPENAI_MODEL=gpt-3.5-turbo
OPENAI_TIMEOUT=30
```

## 支持的翻译服务

### 1. 百度翻译

- 需要在百度翻译开放平台申请API密钥
- 设置 `translator_type = "baidu"`
- 配置 `baidu_trans_appid` 和 `baidu_trans_apikey`

### 2. OpenAI格式翻译

支持以下服务：

#### OpenAI官方API
```toml
openai_api_base = "https://api.openai.com"
openai_api_key = "sk-xxxxxxxxxxxxxxxx"
openai_model = "gpt-3.5-turbo"
```

#### OneAPI（支持多种模型的统一API）
```toml
openai_api_base = "https://your-oneapi-domain.com"
openai_api_key = "sk-xxxxxxxxxxxxxxxx"
openai_model = "gpt-3.5-turbo"  # 或其他支持的模型
```

#### FastGPT
```toml
openai_api_base = "https://your-fastgpt-domain.com"
openai_api_key = "fastgpt-xxxxxxxxxxxxxxxx"
openai_model = "gpt-3.5-turbo"
```

#### 其他兼容OpenAI格式的API
只要API兼容OpenAI的 `/v1/chat/completions` 接口，都可以使用。

## 配置参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `translator_type` | 翻译服务类型，可选 "baidu" 或 "openai" | "baidu" |
| `baidu_trans_appid` | 百度翻译API ID | "" |
| `baidu_trans_apikey` | 百度翻译API密钥 | "" |
| `openai_api_base` | OpenAI格式API的基础URL | "" |
| `openai_api_key` | OpenAI格式API的密钥 | "" |
| `openai_model` | 使用的模型名称 | "gpt-3.5-turbo" |
| `openai_timeout` | 请求超时时间（秒） | 30 |

## 使用示例

### Docker环境变量配置

```bash
docker run -d \
  -e TRANSLATOR_TYPE=openai \
  -e OPENAI_API_BASE=https://api.openai.com \
  -e OPENAI_API_KEY=your_api_key \
  -e OPENAI_MODEL=gpt-3.5-turbo \
  -p 2233:2233 \
  meme-generator
```

### 本地开发配置

1. 复制配置文件：
```bash
cp config.example.toml config.toml
```

2. 编辑 `config.toml`，设置翻译配置

3. 运行程序：
```bash
python -m meme_generator
```

## 注意事项

1. **API密钥安全**：请妥善保管API密钥，不要提交到版本控制系统
2. **网络连接**：确保服务器能够访问相应的API端点
3. **费用控制**：使用OpenAI API时注意控制使用量，避免产生过高费用
4. **模型选择**：推荐使用 `gpt-3.5-turbo`，性价比较高且翻译质量良好
5. **超时设置**：根据网络情况适当调整 `openai_timeout` 参数

## 故障排除

### 常见错误

1. **配置未设置错误**
   - 错误信息：`"openai_api_base" 或 "openai_api_key" 未设置`
   - 解决方案：检查配置文件或环境变量是否正确设置

2. **API请求失败**
   - 错误信息：`OpenAI API 请求失败: 401`
   - 解决方案：检查API密钥是否正确

3. **网络超时**
   - 错误信息：`OpenAI API 请求超时`
   - 解决方案：检查网络连接或增加超时时间

4. **不支持的翻译类型**
   - 错误信息：`不支持的翻译服务类型`
   - 解决方案：确保 `translator_type` 设置为 "baidu" 或 "openai"