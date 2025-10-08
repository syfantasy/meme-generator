# ---- Builder Stage ----
# 此阶段用于生成静态 JSON 文件
FROM node:18-slim as builder

WORKDIR /app

# 安装 git
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# 克隆所有仓库
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator.git meme-generator
RUN git clone --depth 1 https://github.com/MemeCrafters/meme-generator-contrib.git meme-generator-contrib
RUN git clone --depth 1 https://github.com/anyliew/meme_emoji.git meme_emoji

# 运行脚本以生成 infos.json 和 keyMap.json
RUN node -e "const fs = require('fs'); const path = require('path'); const memeSrcDirs = [path.join('meme-generator', 'src', 'memes'), path.join('meme-generator-contrib', 'memes'), path.join('meme_emoji', 'emoji')]; let infos = {}; let keyMap = {}; memeSrcDirs.forEach(dir => { if (!fs.existsSync(dir)) return; fs.readdirSync(dir).forEach(memeKey => { const infoPath = path.join(dir, memeKey, 'info.json'); if (fs.existsSync(infoPath)) { try { const info = JSON.parse(fs.readFileSync(infoPath, 'utf-8')); infos[info.key] = info; info.keywords.forEach(keyword => { keyMap[keyword] = info.key; }); } catch (e) { console.error(`Error parsing \${infoPath}:`, e); } } }); }); fs.writeFileSync('infos.json', JSON.stringify(infos, null, 2)); fs.writeFileSync('keyMap.json', JSON.stringify(keyMap, null, 2)); console.log('Successfully generated infos.json and keyMap.json');"

# ---- Final Stage ----
# 构建最终的 Python 镜像
FROM python:3.10-slim

WORKDIR /app

# 从 builder 阶段复制所有仓库代码
COPY --from=builder /app/meme-generator/ /app/
COPY --from=builder /app/meme-generator-contrib/ /app/contrib/
COPY --from=builder /app/meme_emoji/ /app/emoji/

# 从 builder 阶段复制生成的静态 JSON 文件到 meme.js 期望的位置
# 假设 meme.js 会在 /app/data/memes/ 目录下寻找这些文件
RUN mkdir -p /app/data/memes
COPY --from=builder /app/infos.json /app/data/memes/infos.json
COPY --from=builder /app/keyMap.json /app/data/memes/keyMap.json

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 设置容器启动命令
CMD [\"python\", \"core/app.py\"]
