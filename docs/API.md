# API 文档

Meme Generator Unified 提供了完整的 REST API 接口，用于生成各种表情包。

## 🚀 快速开始

### 基础信息

- **基础URL**: `http://localhost:2233`
- **API版本**: v1
- **内容类型**: `application/json`
- **文档地址**: `http://localhost:2233/docs`

### 认证

目前 API 不需要认证，但建议在生产环境中配置适当的访问控制。

## 📋 API 端点

### 1. 获取表情包列表

获取所有可用的表情包信息。

```http
GET /memes
```

**响应示例**:
```json
{
  "memes": [
    {
      "key": "petpet",
      "keywords": ["摸", "摸摸", "摸头", "rua"],
      "params": {
        "min_images": 1,
        "max_images": 1,
        "min_texts": 0,
        "max_texts": 0
      },
      "tags": ["动画"],
      "date_created": "2021-05-04",
      "date_modified": "2023-02-11"
    }
  ]
}
```

### 2. 获取特定表情包信息

获取指定表情包的详细信息。

```http
GET /memes/{meme_key}
```

**路径参数**:
- `meme_key` (string): 表情包的唯一标识符

**响应示例**:
```json
{
  "key": "petpet",
  "keywords": ["摸", "摸摸", "摸头", "rua"],
  "params": {
    "min_images": 1,
    "max_images": 1,
    "min_texts": 0,
    "max_texts": 0,
    "args": {
      "circle": {
        "type": "boolean",
        "default": false,
        "description": "是否将图片变为圆形"
      }
    }
  },
  "tags": ["动画"],
  "date_created": "2021-05-04",
  "date_modified": "2023-02-11"
}
```

### 3. 生成表情包

使用指定的表情包模板生成表情包。

```http
POST /memes/{meme_key}
```

**路径参数**:
- `meme_key` (string): 表情包的唯一标识符

**请求体** (multipart/form-data):
- `images` (file[]): 图片文件（可选，根据表情包要求）
- `texts` (string[]): 文本内容（可选，根据表情包要求）
- `args` (json): 额外参数（可选）

**请求示例**:
```bash
curl -X POST "http://localhost:2233/memes/petpet" \
  -F "images=@avatar.jpg" \
  -F "args={\"circle\": true}"
```

**响应**:
- 成功时返回生成的图片文件（image/gif 或 image/png）
- 失败时返回错误信息

### 4. 搜索表情包

根据关键词搜索表情包。

```http
GET /memes/search?q={keyword}
```

**查询参数**:
- `q` (string): 搜索关键词

**响应示例**:
```json
{
  "results": [
    {
      "key": "petpet",
      "keywords": ["摸", "摸摸", "摸头", "rua"],
      "relevance": 0.95
    }
  ]
}
```

### 5. 健康检查

检查服务状态。

```http
GET /health
```

**响应示例**:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime": 3600,
  "memes_loaded": 150
}
```

## 🎨 表情包分类

### 核心表情包 (Core)
来自 meme-generator 主仓库的表情包：
- `petpet` - 摸头
- `kiss` - 亲亲
- `hug` - 抱抱
- `slap` - 拍打
- 等等...

### 扩展表情包 (Contrib)
来自 meme-generator-contrib 的额外表情包：
- `behead` - 砍头
- `jerk_off` - 打胶
- `stretch` - 拉伸
- 等等...

### 热门表情包 (Emoji)
来自 meme_emoji 的热门表情包：
- `adoption` - 收养
- `ikun_head` - 坤头
- `kfc_thursday` - 疯狂星期四
- 等等...

## 🔧 参数说明

### 图片参数
- **格式支持**: JPG, PNG, GIF, WebP
- **最大尺寸**: 10MB
- **推荐尺寸**: 512x512 像素

### 文本参数
- **编码**: UTF-8
- **最大长度**: 100 字符（根据表情包而定）
- **支持换行**: 使用 `\n`

### 额外参数 (args)
每个表情包可能支持不同的额外参数：

```json
{
  "circle": true,          // 圆形裁剪
  "flip": false,          // 水平翻转
  "rotate": 0,            // 旋转角度
  "scale": 1.0,           // 缩放比例
  "quality": 95           // 图片质量 (1-100)
}
```

## 🌐 翻译功能

API 支持自动翻译功能，可以将中文表情包文本翻译为其他语言。

### 配置翻译服务

#### 百度翻译
```toml
[translate]
translator_type = "baidu"
baidu_trans_appid = "your_appid"
baidu_trans_apikey = "your_apikey"
```

#### OpenAI 翻译
```toml
[translate]
translator_type = "openai"
openai_api_base = "https://api.openai.com/v1"
openai_api_key = "your_api_key"
openai_model = "gpt-3.5-turbo"
```

### 使用翻译

在请求中添加 `translate` 参数：

```bash
curl -X POST "http://localhost:2233/memes/petpet" \
  -F "images=@avatar.jpg" \
  -F "texts=你好世界" \
  -F "args={\"translate\": \"en\"}"
```

支持的语言代码：
- `en` - 英语
- `ja` - 日语
- `ko` - 韩语
- `fr` - 法语
- `de` - 德语
- `es` - 西班牙语

## 📊 错误处理

### 错误响应格式

```json
{
  "error": {
    "code": "INVALID_IMAGE",
    "message": "图片格式不支持",
    "details": {
      "supported_formats": ["jpg", "png", "gif", "webp"]
    }
  }
}
```

### 常见错误代码

| 错误代码 | HTTP状态码 | 描述 |
|----------|------------|------|
| `MEME_NOT_FOUND` | 404 | 表情包不存在 |
| `INVALID_IMAGE` | 400 | 图片格式或大小不符合要求 |
| `INVALID_TEXT` | 400 | 文本内容不符合要求 |
| `MISSING_REQUIRED_PARAM` | 400 | 缺少必需参数 |
| `TEXT_TOO_LONG` | 400 | 文本过长 |
| `IMAGE_TOO_LARGE` | 413 | 图片文件过大 |
| `GENERATION_FAILED` | 500 | 表情包生成失败 |
| `TRANSLATION_FAILED` | 500 | 翻译服务失败 |

## 🔍 使用示例

### Python 示例

```python
import requests

# 获取表情包列表
response = requests.get("http://localhost:2233/memes")
memes = response.json()["memes"]

# 生成摸头表情包
with open("avatar.jpg", "rb") as f:
    files = {"images": f}
    data = {"args": '{"circle": true}'}
    
    response = requests.post(
        "http://localhost:2233/memes/petpet",
        files=files,
        data=data
    )
    
    if response.status_code == 200:
        with open("result.gif", "wb") as output:
            output.write(response.content)
```

### JavaScript 示例

```javascript
// 获取表情包列表
fetch('http://localhost:2233/memes')
  .then(response => response.json())
  .then(data => console.log(data.memes));

// 生成表情包
const formData = new FormData();
formData.append('images', fileInput.files[0]);
formData.append('args', JSON.stringify({circle: true}));

fetch('http://localhost:2233/memes/petpet', {
  method: 'POST',
  body: formData
})
.then(response => response.blob())
.then(blob => {
  const url = URL.createObjectURL(blob);
  document.getElementById('result').src = url;
});
```

### cURL 示例

```bash
# 获取表情包列表
curl "http://localhost:2233/memes"

# 生成表情包
curl -X POST "http://localhost:2233/memes/petpet" \
  -F "images=@avatar.jpg" \
  -F "args={\"circle\": true}" \
  --output result.gif
```

## 📈 性能优化

### 缓存
- 生成的表情包会被缓存 1 小时
- 相同参数的请求会直接返回缓存结果

### 限流
- 每个 IP 每分钟最多 60 次请求
- 超出限制会返回 429 状态码

### 并发
- 服务支持并发处理多个请求
- 建议客户端使用连接池

## 🔧 配置选项

### 服务器配置
```toml
[server]
host = "0.0.0.0"
port = 2233
workers = 4
max_request_size = 50  # MB
```

### 图片配置
```toml
[gif]
gif_max_size = 10.0    # MB
gif_max_frames = 100
```

### 资源配置
```toml
[resource]
resource_urls = [
  "https://cdn.example.com/meme-resources/"
]
```

## 📞 支持

如果在使用 API 时遇到问题：
1. 查看 `/docs` 页面的交互式文档
2. 检查错误响应中的详细信息
3. 在 GitHub 上创建 Issue
4. 加入 QQ 群：682145034