# 故障排除脚本 - 诊断和修复常见的同步问题 (PowerShell版本)
# Troubleshooting script for common sync issues (PowerShell version)

param(
    [switch]$CheckAll,
    [switch]$FixSubmodules,
    [switch]$Clean,
    [switch]$Help
)

# 颜色函数
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Header {
    param([string]$Title)
    Write-Host "`n=== $Title ===" -ForegroundColor Blue
}

# 检查Git配置
function Test-GitConfig {
    Write-Header "检查Git配置"
    
    try {
        $gitVersion = git --version
        Write-Success "Git已安装: $gitVersion"
    }
    catch {
        Write-Error "Git未安装或不在PATH中"
        return $false
    }
    
    # 检查用户配置
    try {
        $userName = git config --global user.name 2>$null
        $userEmail = git config --global user.email 2>$null
        
        if ($userName -and $userEmail) {
            Write-Success "Git用户配置正常:"
            Write-Host "  Name: $userName"
            Write-Host "  Email: $userEmail"
        }
        else {
            Write-Warning "Git用户配置缺失，建议设置:"
            Write-Host "  git config --global user.name `"Your Name`""
            Write-Host "  git config --global user.email `"your.email@example.com`""
        }
    }
    catch {
        Write-Warning "无法检查Git用户配置"
    }
    
    return $true
}

# 检查网络连接
function Test-Network {
    Write-Header "检查网络连接"
    
    $hosts = @("github.com", "api.github.com")
    
    foreach ($host in $hosts) {
        try {
            $result = Test-NetConnection -ComputerName $host -Port 443 -InformationLevel Quiet
            if ($result) {
                Write-Success "可以访问 $host"
            }
            else {
                Write-Warning "无法访问 $host - 可能存在网络问题"
            }
        }
        catch {
            Write-Warning "无法测试 $host 的连接"
        }
    }
    
    # 检查GitHub API访问
    try {
        $response = Invoke-WebRequest -Uri "https://api.github.com/rate_limit" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Success "GitHub API访问正常"
        }
        else {
            Write-Warning "GitHub API访问异常"
        }
    }
    catch {
        Write-Warning "GitHub API访问测试失败: $($_.Exception.Message)"
    }
}

# 检查子模块状态
function Test-Submodules {
    Write-Header "检查子模块状态"
    
    if (-not (Test-Path ".gitmodules")) {
        Write-Error ".gitmodules文件不存在"
        return $false
    }
    
    Write-Status "子模块配置:"
    Get-Content ".gitmodules"
    
    Write-Host ""
    Write-Status "子模块状态:"
    try {
        git submodule status
    }
    catch {
        Write-Warning "子模块状态检查失败"
    }
    
    # 检查各个子模块目录
    $submodules = @("core", "contrib", "emoji")
    foreach ($submodule in $submodules) {
        if (Test-Path $submodule) {
            if ((Test-Path "$submodule\.git") -or (Test-Path "$submodule\.git" -PathType Leaf)) {
                Write-Success "子模块 $submodule 存在且已初始化"
            }
            else {
                Write-Warning "子模块 $submodule 存在但未初始化"
            }
        }
        else {
            Write-Error "子模块 $submodule 目录不存在"
        }
    }
    
    return $true
}

# 检查远程仓库访问
function Test-RemoteAccess {
    Write-Header "检查远程仓库访问"
    
    $repos = @(
        "https://github.com/MemeCrafters/meme-generator.git",
        "https://github.com/MemeCrafters/meme-generator-contrib.git",
        "https://github.com/anyliew/meme_emoji.git"
    )
    
    foreach ($repo in $repos) {
        Write-Status "检查仓库: $repo"
        try {
            $result = git ls-remote $repo HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "可以访问 $repo"
            }
            else {
                Write-Error "无法访问 $repo"
            }
        }
        catch {
            Write-Error "无法访问 $repo"
        }
    }
}

# 修复子模块问题
function Repair-Submodules {
    Write-Header "修复子模块问题"
    
    Write-Status "重新初始化子模块..."
    try {
        git submodule deinit --all -f 2>$null
        git submodule init
        git submodule update --init --recursive
        Write-Success "子模块重新初始化完成"
    }
    catch {
        Write-Error "子模块修复失败: $($_.Exception.Message)"
        return $false
    }
    
    return $true
}

# 清理和重置
function Reset-Repository {
    Write-Header "清理和重置"
    
    $confirmation = Read-Host "这将清理所有未提交的更改，确定继续吗? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Status "取消清理操作"
        return
    }
    
    Write-Status "清理工作目录..."
    try {
        git clean -fd
        git reset --hard HEAD
        
        Write-Status "清理子模块..."
        git submodule foreach --recursive git clean -fd
        git submodule foreach --recursive git reset --hard HEAD
        
        Write-Success "清理完成"
    }
    catch {
        Write-Error "清理失败: $($_.Exception.Message)"
    }
}

# 测试同步功能
function Test-SyncFunction {
    Write-Header "测试同步功能"
    
    if (Test-Path "scripts\sync-repos.sh") {
        Write-Status "找到bash同步脚本"
        Write-Success "同步脚本存在"
    }
    else {
        Write-Error "同步脚本不存在"
    }
}

# 运行所有检查
function Invoke-AllChecks {
    Write-Header "运行所有检查"
    Test-GitConfig
    Test-Network
    Test-Submodules
    Test-RemoteAccess
    Test-SyncFunction
    Write-Success "所有检查完成"
}

# 显示菜单
function Show-Menu {
    Write-Host ""
    Write-Host "=== 故障排除菜单 ==="
    Write-Host "1. 检查Git配置"
    Write-Host "2. 检查网络连接"
    Write-Host "3. 检查子模块状态"
    Write-Host "4. 检查远程仓库访问"
    Write-Host "5. 修复子模块问题"
    Write-Host "6. 清理和重置"
    Write-Host "7. 测试同步功能"
    Write-Host "8. 运行所有检查"
    Write-Host "9. 退出"
    Write-Host ""
}

# 显示帮助
function Show-Help {
    Write-Host "用法: .\troubleshoot.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -CheckAll        运行所有检查"
    Write-Host "  -FixSubmodules   修复子模块问题"
    Write-Host "  -Clean           清理和重置"
    Write-Host "  -Help            显示帮助信息"
    Write-Host ""
    Write-Host "不带参数运行将进入交互模式"
}

# 主函数
function Main {
    Write-Host "🔧 表情包生成器故障排除工具 (PowerShell版本)" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    
    # 检查是否在正确的目录
    if (-not (Test-Path "README.md") -or -not (Test-Path ".git")) {
        Write-Error "请在项目根目录运行此脚本"
        exit 1
    }
    
    # 处理命令行参数
    if ($Help) {
        Show-Help
        return
    }
    
    if ($CheckAll) {
        Invoke-AllChecks
        return
    }
    
    if ($FixSubmodules) {
        Repair-Submodules
        return
    }
    
    if ($Clean) {
        Reset-Repository
        return
    }
    
    # 交互模式
    while ($true) {
        Show-Menu
        $choice = Read-Host "请选择操作 (1-9)"
        
        switch ($choice) {
            "1" { Test-GitConfig }
            "2" { Test-Network }
            "3" { Test-Submodules }
            "4" { Test-RemoteAccess }
            "5" { Repair-Submodules }
            "6" { Reset-Repository }
            "7" { Test-SyncFunction }
            "8" { Invoke-AllChecks }
            "9" { Write-Status "Exit"; exit 0 }
            default { Write-Error "Invalid choice, please enter 1-9" }
        }
    }
}

# 运行主函数
Main