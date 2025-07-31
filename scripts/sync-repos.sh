#!/bin/bash

# Manual sync script for updating submodules
# 手动同步脚本，用于更新子模块

set -e

echo "🔄 Syncing upstream repositories..."

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

# 函数：同步单个子模块
sync_submodule() {
    local submodule_path=$1
    local submodule_name=$2
    local upstream_url=$3
    
    print_status "Syncing $submodule_name..."
    
    if [ ! -d "$submodule_path" ]; then
        print_error "Submodule $submodule_name not found at $submodule_path"
        return 1
    fi
    
    cd "$submodule_path"
    
    # 获取当前分支，如果在detached HEAD状态则切换到main分支
    current_branch=$(git branch --show-current)
    if [ -z "$current_branch" ]; then
        print_warning "In detached HEAD state, switching to main branch"
        git checkout -b main 2>/dev/null || git checkout main 2>/dev/null || git checkout master 2>/dev/null
        current_branch=$(git branch --show-current)
    fi
    print_status "Current branch: $current_branch"
    
    # 设置上游远程仓库
    if git remote | grep -q "^upstream$"; then
        git remote remove upstream
    fi
    git remote add upstream "$upstream_url"
    
    # 获取远程更新（带重试机制）
    print_status "Fetching updates from upstream..."
    retry_count=0
    max_retries=3
    while [ $retry_count -lt $max_retries ]; do
        if git fetch upstream; then
            print_success "Successfully fetched from upstream"
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                print_warning "Fetch failed, retrying in 5 seconds... (attempt $retry_count/$max_retries)"
                sleep 5
            else
                print_error "Failed to fetch from upstream after $max_retries attempts"
                cd - > /dev/null
                return 1
            fi
        fi
    done
    
    # 检查是否有更新
    local_commit=$(git rev-parse HEAD)
    upstream_commit=$(git rev-parse upstream/main 2>/dev/null || git rev-parse upstream/master 2>/dev/null)
    
    if [ "$local_commit" = "$upstream_commit" ]; then
        print_success "$submodule_name is already up to date"
    else
        print_status "Updates found for $submodule_name"
        print_status "Local:    $local_commit"
        print_status "Upstream: $upstream_commit"
        
        # 尝试自动合并
        upstream_branch="main"
        if ! git rev-parse upstream/main >/dev/null 2>&1; then
            upstream_branch="master"
        fi
        
        if git merge upstream/$upstream_branch --no-edit; then
            print_success "Successfully merged updates for $submodule_name"
        else
            print_warning "Automatic merge failed for $submodule_name"
            print_warning "Manual intervention may be required"
            git merge --abort
            
            # 询问是否强制更新
            if [ "$FORCE_UPDATE" = "true" ]; then
                git reset --hard upstream/$upstream_branch
                print_success "Force reset $submodule_name to upstream HEAD"
            else
                read -p "Do you want to reset to upstream HEAD? This will lose local changes. (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    git reset --hard upstream/$upstream_branch
                    print_success "Reset $submodule_name to upstream HEAD"
                else
                    print_warning "Skipping $submodule_name update"
                fi
            fi
        fi
    fi
    
    cd - > /dev/null
}

# 主同步逻辑
main() {
    # 检查是否在正确的目录
    if [ ! -f "README.md" ] || [ ! -d ".git" ]; then
        print_error "Please run this script from the project root directory"
        exit 1
    fi
    
    print_status "Starting repository sync..."
    
    # 同步各个子模块
    sync_submodule "core" "meme-generator" "https://github.com/MemeCrafters/meme-generator.git"
    sync_submodule "contrib" "meme-generator-contrib" "https://github.com/MemeCrafters/meme-generator-contrib.git"
    sync_submodule "emoji" "meme_emoji" "https://github.com/anyliew/meme_emoji.git"
    
    # 更新主仓库的子模块引用
    print_status "Updating submodule references in main repository..."
    
    if git diff --quiet --cached; then
        if git add core contrib emoji && git diff --cached --quiet; then
            print_success "No submodule reference updates needed"
        else
            print_status "Submodule references updated, creating commit..."
            git commit -m "chore: update submodule references

- Updated core (meme-generator)
- Updated contrib (meme-generator-contrib)  
- Updated emoji (meme_emoji)

Auto-generated by sync script"
            print_success "Committed submodule reference updates"
        fi
    else
        print_warning "Working directory has uncommitted changes"
        print_warning "Please commit or stash changes before syncing"
    fi
    
    print_success "Repository sync completed!"
    
    # 显示当前状态
    echo ""
    print_status "Current submodule status:"
    git submodule status
    
    echo ""
    print_status "To push updates to remote, run:"
    echo "git push origin main"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --help, -h     Show this help message"
            echo "  --force        Force update all submodules (reset to remote HEAD)"
            echo ""
            echo "This script syncs all submodules with their upstream repositories."
            exit 0
            ;;
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# 运行主函数
main