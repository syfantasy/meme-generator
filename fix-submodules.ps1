# 子模块修复脚本 - PowerShell版本
# 解决GitHub无法检测到更新的问题

Write-Host "🔧 开始修复子模块问题..." -ForegroundColor Green

# 检查是否在正确的目录
if (-not (Test-Path ".git")) {
    Write-Host "❌ 错误：请在Git仓库根目录运行此脚本" -ForegroundColor Red
    exit 1
}

Write-Host "📋 当前目录: $(Get-Location)" -ForegroundColor Blue

# 步骤1: 显示当前状态
Write-Host "`n=== 当前子模块状态 ===" -ForegroundColor Yellow
git submodule status
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 子模块状态检查完成" -ForegroundColor Green
} else {
    Write-Host "⚠️ 子模块状态异常，继续修复..." -ForegroundColor Yellow
}

# 步骤2: 清理现有子模块
Write-Host "`n=== 清理现有子模块 ===" -ForegroundColor Yellow
Write-Host "清理子模块配置..."
git submodule deinit --all -f 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 子模块配置清理完成" -ForegroundColor Green
} else {
    Write-Host "⚠️ 子模块配置清理失败，继续..." -ForegroundColor Yellow
}

# 删除.git/modules目录
Write-Host "删除.git/modules目录..."
if (Test-Path ".git/modules") {
    Remove-Item -Path ".git/modules" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ .git/modules目录已删除" -ForegroundColor Green
} else {
    Write-Host "ℹ️ .git/modules目录不存在" -ForegroundColor Blue
}

# 步骤3: 重新添加子模块
Write-Host "`n=== 重新添加子模块 ===" -ForegroundColor Yellow

$submodules = @(
    @{name="core"; url="https://github.com/MemeCrafters/meme-generator.git"},
    @{name="contrib"; url="https://github.com/MemeCrafters/meme-generator-contrib.git"},
    @{name="emoji"; url="https://github.com/anyliew/meme_emoji.git"}
)

foreach ($submodule in $submodules) {
    Write-Host "添加子模块: $($submodule.name) -> $($submodule.url)"
    
    # 如果目录存在但不是子模块，先删除
    if (Test-Path $submodule.name) {
        Write-Host "  删除现有目录: $($submodule.name)"
        Remove-Item -Path $submodule.name -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # 添加子模块
    git submodule add $submodule.url $submodule.name
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ $($submodule.name) 添加成功" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($submodule.name) 添加失败" -ForegroundColor Red
    }
}

# 步骤4: 初始化子模块
Write-Host "`n=== 初始化子模块 ===" -ForegroundColor Yellow
git submodule update --init --recursive
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 子模块初始化完成" -ForegroundColor Green
} else {
    Write-Host "❌ 子模块初始化失败" -ForegroundColor Red
}

# 步骤5: 验证修复结果
Write-Host "`n=== 验证修复结果 ===" -ForegroundColor Yellow
Write-Host "子模块状态:"
git submodule status

Write-Host "`n目录验证:"
foreach ($submodule in $submodules) {
    if (Test-Path $submodule.name) {
        $fileCount = (Get-ChildItem $submodule.name -Recurse -File | Measure-Object).Count
        Write-Host "✅ $($submodule.name) 存在，包含 $fileCount 个文件" -ForegroundColor Green
    } else {
        Write-Host "❌ $($submodule.name) 不存在" -ForegroundColor Red
    }
}

# 步骤6: 提交更改
Write-Host "`n=== 提交更改 ===" -ForegroundColor Yellow
git add .gitmodules core contrib emoji 2>$null

# 检查是否有更改需要提交
$status = git status --porcelain
if ($status) {
    Write-Host "发现更改，准备提交..."
    git commit -m "fix: properly initialize submodules as git submodules"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 更改已提交" -ForegroundColor Green
        
        # 询问是否推送
        $push = Read-Host "是否推送到远程仓库? (y/N)"
        if ($push -eq 'y' -or $push -eq 'Y') {
            git push
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ 更改已推送到远程仓库" -ForegroundColor Green
            } else {
                Write-Host "❌ 推送失败" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "❌ 提交失败" -ForegroundColor Red
    }
} else {
    Write-Host "ℹ️ 没有更改需要提交" -ForegroundColor Blue
}

# 最终状态
Write-Host "`n🎉 修复完成！" -ForegroundColor Green
Write-Host "现在可以运行同步工作流来测试是否能检测到上游更新。" -ForegroundColor Blue

Write-Host "`n最终子模块状态:" -ForegroundColor Yellow
git submodule status