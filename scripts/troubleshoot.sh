#!/bin/bash

# 故障排除脚本 - 诊断和修复常见的同步问题
# Troubleshooting script for common sync issues

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印带颜色的消息
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# 检查Git配置
check_git_config() {
    print_header "检查Git配置"
    
    if ! command -v git &> /dev/null; then
        print_error "Git未安装或不在PATH中"
        return 1
    fi
    
    print_success "Git已安装: $(git --version)"
    
    # 检查用户配置
    if git config --global user.name &> /dev/null && git config --global user.email &> /dev/null; then
        print_success "Git用户配置正常:"
        echo "  Name: $(git config --global user.name)"
        echo "  Email: $(git config --global user.email)"
    else
        print_warning "Git用户配置缺失，建议设置:"
        echo "  git config --global user.name \"Your Name\""
        echo "  git config --global user.email \"your.email@example.com\""
    fi
}

# 检查网络连接
check_network() {
    print_header "检查网络连接"
    
    repos=(
        "github.com"
        "api.github.com"
    )
    
    for repo in "${repos[@]}"; do
        if ping -c 1 "$repo" &> /dev/null; then
            print_success "可以访问 $repo"
        else
            print_warning "无法访问 $repo - 可能存在网络问题"
        fi
    done
    
    # 检查GitHub API访问
    if curl -s https://api.github.com/rate_limit &> /dev/null; then
        print_success "GitHub API访问正常"
    else
        print_warning "GitHub API访问异常"
    fi
}

# 检查子模块状态
check_submodules() {
    print_header "检查子模块状态"
    
    if [ ! -f ".gitmodules" ]; then
        print_error ".gitmodules文件不存在"
        return 1
    fi
    
    print_status "子模块配置:"
    cat .gitmodules
    
    echo ""
    print_status "子模块状态:"
    git submodule status || print_warning "子模块状态检查失败"
    
    # 检查各个子模块目录
    submodules=("core" "contrib" "emoji")
    for submodule in "${submodules[@]}"; do
        if [ -d "$submodule" ]; then
            if [ -d "$submodule/.git" ] || [ -f "$submodule/.git" ]; then
                print_success "子模块 $submodule 存在且已初始化"
            else
                print_warning "子模块 $submodule 存在但未初始化"
            fi
        else
            print_error "子模块 $submodule 目录不存在"
        fi
    done
}

# 检查远程仓库访问
check_remote_access() {
    print_header "检查远程仓库访问"
    
    repos=(
        "https://github.com/MemeCrafters/meme-generator.git"
        "https://github.com/MemeCrafters/meme-generator-contrib.git"
        "https://github.com/anyliew/meme_emoji.git"
    )
    
    for repo in "${repos[@]}"; do
        print_status "检查仓库: $repo"
        if git ls-remote "$repo" HEAD &> /dev/null; then
            print_success "可以访问 $repo"
        else
            print_error "无法访问 $repo"
        fi
    done
}

# 修复子模块问题
fix_submodules() {
    print_header "修复子模块问题"
    
    print_status "重新初始化子模块..."
    git submodule deinit --all -f || true
    git submodule init
    git submodule update --init --recursive
    
    print_success "子模块重新初始化完成"
}

# 清理和重置
clean_and_reset() {
    print_header "清理和重置"
    
    read -p "这将清理所有未提交的更改，确定继续吗? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "取消清理操作"
        return 0
    fi
    
    print_status "清理工作目录..."
    git clean -fd
    git reset --hard HEAD
    
    print_status "清理子模块..."
    git submodule foreach --recursive git clean -fd
    git submodule foreach --recursive git reset --hard HEAD
    
    print_success "清理完成"
}

# 测试同步功能
test_sync() {
    print_header "测试同步功能"
    
    if [ -f "scripts/sync-repos.sh" ]; then
        print_status "运行同步脚本测试..."
        bash scripts/sync-repos.sh --help
        print_success "同步脚本可以正常运行"
    else
        print_error "同步脚本不存在"
    fi
}

# 主菜单
show_menu() {
    echo ""
    echo "=== 故障排除菜单 ==="
    echo "1. 检查Git配置"
    echo "2. 检查网络连接"
    echo "3. 检查子模块状态"
    echo "4. 检查远程仓库访问"
    echo "5. 修复子模块问题"
    echo "6. 清理和重置"
    echo "7. 测试同步功能"
    echo "8. 运行所有检查"
    echo "9. 退出"
    echo ""
}

# 运行所有检查
run_all_checks() {
    print_header "运行所有检查"
    check_git_config
    check_network
    check_submodules
    check_remote_access
    test_sync
    print_success "所有检查完成"
}

# 主函数
main() {
    echo "🔧 表情包生成器故障排除工具"
    echo "================================"
    
    # 检查是否在正确的目录
    if [ ! -f "README.md" ] || [ ! -d ".git" ]; then
        print_error "请在项目根目录运行此脚本"
        exit 1
    fi
    
    if [ $# -eq 0 ]; then
        # 交互模式
        while true; do
            show_menu
            read -p "请选择操作 (1-9): " choice
            case $choice in
                1) check_git_config ;;
                2) check_network ;;
                3) check_submodules ;;
                4) check_remote_access ;;
                5) fix_submodules ;;
                6) clean_and_reset ;;
                7) test_sync ;;
                8) run_all_checks ;;
                9) print_status "退出"; exit 0 ;;
                *) print_error "无效选择，请输入1-9" ;;
            esac
        done
    else
        # 命令行模式
        case $1 in
            --check-all) run_all_checks ;;
            --fix-submodules) fix_submodules ;;
            --clean) clean_and_reset ;;
            --help)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --check-all      运行所有检查"
                echo "  --fix-submodules 修复子模块问题"
                echo "  --clean          清理和重置"
                echo "  --help           显示帮助信息"
                echo ""
                echo "不带参数运行将进入交互模式"
                ;;
            *) print_error "未知选项: $1"; echo "使用 --help 查看帮助"; exit 1 ;;
        esac
    fi
}

# 运行主函数
main "$@"