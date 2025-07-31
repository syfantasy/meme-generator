# 同步问题故障排除指南

## 问题描述

GitHub Actions自动同步工作流出现以下错误：
- `meme-generator-contrib` 同步失败，退出码128
- 其他仓库同步被取消
- 构建测试失败，退出码1

## 根本原因分析

1. **策略配置问题**: GitHub Actions矩阵策略默认`fail-fast: true`，导致一个任务失败时其他任务被取消
2. **网络连接问题**: 可能存在间歇性的网络连接问题导致Git操作失败
3. **分支状态问题**: 子模块可能处于detached HEAD状态
4. **权限和访问问题**: 对上游仓库的访问可能不稳定

## 解决方案

### 1. 修复GitHub Actions工作流

已修复 `.github/workflows/sync-upstream.yml` 文件：

- ✅ 添加 `fail-fast: false` 允许其他任务继续执行
- ✅ 增加重试机制和错误处理
- ✅ 改进分支检测和推送逻辑
- ✅ 优化远程仓库设置

### 2. 改进手动同步脚本

已更新 `scripts/sync-repos.sh` 脚本：

- ✅ 添加上游仓库URL参数
- ✅ 增加网络重试机制
- ✅ 改进分支状态检测
- ✅ 优化错误处理和用户交互

### 3. 创建故障排除工具

新增故障排除脚本：

- ✅ `scripts/troubleshoot.sh` (Linux/macOS)
- ✅ `scripts/troubleshoot.ps1` (Windows PowerShell)

## 验证步骤

### 检查远程仓库访问
```bash
# 测试所有上游仓库的连接
git ls-remote https://github.com/MemeCrafters/meme-generator.git HEAD
git ls-remote https://github.com/MemeCrafters/meme-generator-contrib.git HEAD  
git ls-remote https://github.com/anyliew/meme_emoji.git HEAD
```

### 手动同步测试
```bash
# 运行改进的同步脚本
bash scripts/sync-repos.sh

# 或使用故障排除工具
bash scripts/troubleshoot.sh --check-all
```

### Windows用户
```powershell
# 使用PowerShell版本
powershell -ExecutionPolicy Bypass -File scripts/troubleshoot.ps1 -CheckAll
```

## 预防措施

### 1. 定期监控
- 设置GitHub Actions通知
- 定期检查同步状态
- 监控上游仓库更新

### 2. 备用同步方案
- 使用手动同步脚本作为备用
- 设置本地定时任务
- 建立多重同步策略

### 3. 网络优化
- 配置Git代理（如需要）
- 使用镜像仓库（如需要）
- 增加超时时间设置

### 4. 权限管理
- 确保GitHub Token权限充足
- 定期更新访问令牌
- 检查仓库访问权限

## 常见问题解决

### Q: 子模块初始化失败
```bash
# 强制重新初始化子模块
git submodule deinit --all -f
git submodule update --init --recursive --force
```

### Q: 网络连接超时
```bash
# 增加Git超时设置
git config --global http.timeout 300
git config --global http.postBuffer 524288000
```

### Q: 权限被拒绝
```bash
# 检查SSH密钥或使用HTTPS
git config --global url."https://github.com/".insteadOf git@github.com:
```

### Q: 分支状态异常
```bash
# 检查并修复分支状态
git submodule foreach 'git checkout main || git checkout master'
```

## 监控和维护

### 日常检查清单
- [ ] 检查GitHub Actions运行状态
- [ ] 验证子模块同步状态
- [ ] 测试构建和部署流程
- [ ] 检查依赖项更新

### 故障响应流程
1. 查看GitHub Actions日志
2. 运行故障排除脚本
3. 手动执行同步操作
4. 检查网络和权限问题
5. 必要时联系仓库维护者

## 联系支持

如果问题持续存在，请：
1. 收集错误日志和环境信息
2. 在项目仓库创建Issue
3. 提供详细的错误描述和重现步骤

---

*最后更新: 2025-07-31*
*版本: 1.0*