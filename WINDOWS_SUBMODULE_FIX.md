# Windows PowerShell 子模块修复指南

## 🚨 Windows PowerShell 修复步骤

### 步骤1: 清理现有状态
```powershell
# 清理子模块
git submodule deinit --all -f

# 删除.git/modules目录 (PowerShell语法)
if (Test-Path ".git/modules") {
    Remove-Item -Path ".git/modules" -Recurse -Force
}
```

### 步骤2: 重新添加子模块
```powershell
# 重新添加子模块
git submodule add https://github.com/MemeCrafters/meme-generator.git core
git submodule add https://github.com/MemeCrafters/meme-generator-contrib.git contrib
git submodule add https://github.com/anyliew/meme_emoji.git emoji
```

### 步骤3: 初始化子模块
```powershell
# 初始化子模块
git submodule update --init --recursive
```

### 步骤4: 验证修复
```powershell
# 检查子模块状态
git submodule status

# 应该看到类似这样的输出：
# +abc1234 core (heads/main)
# +def5678 contrib (heads/main)  
# +ghi9012 emoji (heads/main)
```

### 步骤5: 提交更改
```powershell
# 添加更改
git add .gitmodules core contrib emoji

# 提交
git commit -m "fix: properly initialize submodules as git submodules"

# 推送
git push
```

## 🔧 如果遇到错误

### 如果子模块添加失败
```powershell
# 先删除现有目录
Remove-Item -Path "core" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "contrib" -Recurse -Force -ErrorAction SilentlyContinue  
Remove-Item -Path "emoji" -Recurse -Force -ErrorAction SilentlyContinue

# 然后重新添加
git submodule add https://github.com/MemeCrafters/meme-generator.git core
git submodule add https://github.com/MemeCrafters/meme-generator-contrib.git contrib
git submodule add https://github.com/anyliew/meme_emoji.git emoji
```

### 完全重置方案（如果上述步骤失败）
```powershell
# 完全清理
git submodule deinit --all -f
Remove-Item -Path ".git/modules" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "core" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "contrib" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "emoji" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".gitmodules" -Force -ErrorAction SilentlyContinue

# 重新开始
git submodule add https://github.com/MemeCrafters/meme-generator.git core
git submodule add https://github.com/MemeCrafters/meme-generator-contrib.git contrib
git submodule add https://github.com/anyliew/meme_emoji.git emoji

git submodule update --init --recursive
git add .
git commit -m "fix: completely reinitialize submodules"
git push
```

## ✅ 成功标志

修复成功后，你应该看到：
- `git submodule status` 显示三个子模块
- 每个子模块前面有提交哈希
- 同步工作流能检测到上游更新

## 🚀 下一步

修复完成后：
1. 运行 "Sync Upstream Repositories" 工作流
2. 验证同步功能正常工作
3. 不再出现 "没有检测到更新" 的问题

---

**现在请使用PowerShell命令执行上述修复步骤！**