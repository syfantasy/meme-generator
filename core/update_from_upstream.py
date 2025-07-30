#!/usr/bin/env python3
"""
从上游仓库更新代码的脚本
保持翻译功能修改的同时，同步上游更新
"""

import os
import sys
import subprocess
import shutil
import tempfile
from pathlib import Path
import json
from typing import Dict, List

# 上游仓库配置
UPSTREAM_REPO = "https://github.com/MemeCrafters/meme-generator.git"
UPSTREAM_BRANCH = "main"

# 需要保护的文件（包含我们的修改）
PROTECTED_FILES = [
    "meme_generator/config.py",
    "meme_generator/utils.py",
    "docker/config.toml.template",
    "config.example.toml",
    ".env.example",
    "TRANSLATION_GUIDE.md",
    "test_translation.py",
    "setup_meme_repos.py",
    "app.py",
    "requirements.txt",
    "update_from_upstream.py"
]

def run_command(cmd: List[str], cwd: str = None) -> tuple[bool, str]:
    """运行命令并返回结果"""
    try:
        result = subprocess.run(
            cmd, 
            cwd=cwd, 
            capture_output=True, 
            text=True, 
            check=True
        )
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr

def backup_protected_files(backup_dir: Path) -> Dict[str, str]:
    """备份受保护的文件"""
    backup_map = {}
    
    print("📦 备份受保护的文件...")
    for file_path in PROTECTED_FILES:
        src_path = Path(file_path)
        if src_path.exists():
            backup_path = backup_dir / file_path
            backup_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_path, backup_path)
            backup_map[file_path] = str(backup_path)
            print(f"  ✅ 备份: {file_path}")
        else:
            print(f"  ⚠️  文件不存在: {file_path}")
    
    return backup_map

def restore_protected_files(backup_map: Dict[str, str]):
    """恢复受保护的文件"""
    print("🔄 恢复受保护的文件...")
    for file_path, backup_path in backup_map.items():
        if Path(backup_path).exists():
            dest_path = Path(file_path)
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(backup_path, dest_path)
            print(f"  ✅ 恢复: {file_path}")
        else:
            print(f"  ❌ 备份文件不存在: {backup_path}")

def get_current_commit_hash() -> str:
    """获取当前提交哈希"""
    success, output = run_command(["git", "rev-parse", "HEAD"])
    if success:
        return output.strip()
    return ""

def update_from_upstream() -> bool:
    """从上游仓库更新代码"""
    print("🚀 开始从上游仓库更新...")
    
    # 检查是否在git仓库中
    if not Path(".git").exists():
        print("❌ 当前目录不是git仓库")
        return False
    
    # 获取当前提交哈希
    current_commit = get_current_commit_hash()
    print(f"📍 当前提交: {current_commit[:8]}")
    
    # 创建临时备份目录
    with tempfile.TemporaryDirectory() as temp_dir:
        backup_dir = Path(temp_dir) / "backup"
        backup_dir.mkdir()
        
        # 备份受保护的文件
        backup_map = backup_protected_files(backup_dir)
        
        try:
            # 添加上游远程仓库（如果不存在）
            print("🔗 配置上游仓库...")
            run_command(["git", "remote", "remove", "upstream"])  # 删除可能存在的upstream
            success, _ = run_command(["git", "remote", "add", "upstream", UPSTREAM_REPO])
            if not success:
                print("❌ 添加上游仓库失败")
                return False
            
            # 获取上游更新
            print("📥 获取上游更新...")
            success, _ = run_command(["git", "fetch", "upstream", UPSTREAM_BRANCH])
            if not success:
                print("❌ 获取上游更新失败")
                return False
            
            # 合并上游更新
            print("🔀 合并上游更新...")
            success, output = run_command(["git", "merge", f"upstream/{UPSTREAM_BRANCH}", "--no-edit"])
            if not success:
                print(f"❌ 合并失败: {output}")
                # 尝试中止合并
                run_command(["git", "merge", "--abort"])
                return False
            
            # 恢复受保护的文件
            restore_protected_files(backup_map)
            
            # 提交恢复的文件
            print("💾 提交恢复的文件...")
            run_command(["git", "add", "."])
            run_command(["git", "commit", "-m", "chore: restore protected files after upstream merge"])
            
            print("✅ 上游更新完成！")
            return True
            
        except Exception as e:
            print(f"❌ 更新过程中出错: {e}")
            # 恢复受保护的文件
            restore_protected_files(backup_map)
            return False

def check_for_updates() -> bool:
    """检查是否有上游更新"""
    print("🔍 检查上游更新...")
    
    # 获取上游最新提交
    success, _ = run_command(["git", "fetch", "upstream", UPSTREAM_BRANCH])
    if not success:
        print("❌ 无法获取上游信息")
        return False
    
    # 比较本地和上游提交
    success, local_commit = run_command(["git", "rev-parse", "HEAD"])
    if not success:
        return False
    
    success, upstream_commit = run_command(["git", "rev-parse", f"upstream/{UPSTREAM_BRANCH}"])
    if not success:
        return False
    
    local_commit = local_commit.strip()
    upstream_commit = upstream_commit.strip()
    
    if local_commit != upstream_commit:
        print(f"📈 发现上游更新:")
        print(f"  本地: {local_commit[:8]}")
        print(f"  上游: {upstream_commit[:8]}")
        return True
    else:
        print("✅ 已是最新版本")
        return False

def create_update_info():
    """创建更新信息文件"""
    update_info = {
        "last_update": "",
        "protected_files": PROTECTED_FILES,
        "upstream_repo": UPSTREAM_REPO,
        "upstream_branch": UPSTREAM_BRANCH
    }
    
    with open("update_info.json", "w", encoding="utf-8") as f:
        json.dump(update_info, f, indent=2, ensure_ascii=False)
    
    print("📄 已创建更新信息文件: update_info.json")

def main():
    """主函数"""
    print("=== meme-generator 上游更新工具 ===\n")
    
    if len(sys.argv) > 1:
        command = sys.argv[1].lower()
        
        if command == "check":
            # 只检查更新
            has_updates = check_for_updates()
            sys.exit(0 if not has_updates else 1)
            
        elif command == "force":
            # 强制更新
            success = update_from_upstream()
            sys.exit(0 if success else 1)
            
        elif command == "info":
            # 创建更新信息文件
            create_update_info()
            sys.exit(0)
            
        else:
            print("用法:")
            print("  python update_from_upstream.py          # 检查并更新")
            print("  python update_from_upstream.py check    # 只检查更新")
            print("  python update_from_upstream.py force    # 强制更新")
            print("  python update_from_upstream.py info     # 创建更新信息")
            sys.exit(1)
    
    else:
        # 默认行为：检查并更新
        has_updates = check_for_updates()
        if has_updates:
            print("\n🤔 是否要更新？(y/N): ", end="")
            response = input().strip().lower()
            if response in ['y', 'yes']:
                success = update_from_upstream()
                sys.exit(0 if success else 1)
            else:
                print("❌ 取消更新")
                sys.exit(0)
        else:
            sys.exit(0)

if __name__ == "__main__":
    main()