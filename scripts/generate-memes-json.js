const fs = require('fs');
const path = require('path');

// 定义所有可能的表情包源目录
const memeSrcDirs = [
  path.resolve('meme-generator', 'memes'), // 假设主仓库的 memes 目录
  path.resolve('meme-generator', 'core', 'memes'), // 另一个可能的路径
  path.resolve('meme-generator-contrib', 'memes'),
  path.resolve('meme_emoji', 'emoji')
];

let infos = {};
let keyMap = {};

console.log('Starting meme data generation...');

memeSrcDirs.forEach(dir => {
  if (!fs.existsSync(dir)) {
    console.warn(`Directory not found, skipping: ${dir}`);
    return;
  }
  console.log(`Processing directory: ${dir}`);
  fs.readdirSync(dir).forEach(memeKey => {
    const memeDirPath = path.join(dir, memeKey);
    if (!fs.statSync(memeDirPath).isDirectory()) {
        return; // 跳过非目录文件
    }
    const infoPath = path.join(memeDirPath, 'info.json');
    if (fs.existsSync(infoPath)) {
      try {
        const infoContent = fs.readFileSync(infoPath, 'utf-8');
        const info = JSON.parse(infoContent);
        
        // 确保 key 存在
        if (!info.key) {
            info.key = memeKey;
        }

        infos[info.key] = info;
        if (info.keywords && Array.isArray(info.keywords)) {
            info.keywords.forEach(keyword => {
                keyMap[keyword] = info.key;
            });
        }
        console.log(`  - Processed: ${memeKey}`);
      } catch (e) {
        console.error(`Error parsing ${infoPath}:`, e);
      }
    }
  });
});

fs.writeFileSync('infos.json', JSON.stringify(infos, null, 2));
fs.writeFileSync('keyMap.json', JSON.stringify(keyMap, null, 2));

console.log('Successfully generated infos.json and keyMap.json');
console.log(`${Object.keys(infos).length} memes found.`);