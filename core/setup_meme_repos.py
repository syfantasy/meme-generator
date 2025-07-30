#!/usr/bin/env python3
"""
自动下载和更新额外的meme仓库
支持从GitHub下载meme-generator-contrib和meme_emoji仓库
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path
import zipfile
import requests
from typing import List, Dict

# 额外的meme仓库配置
MEME_REPOS = {
    "meme-generator-contrib": {
        "url": "https://github.com/MemeCrafters/meme-generator-contrib",
        "archive_url": "https://github.com/MemeCrafters/meme-generator-contrib/archive/refs/heads/main.zip",
        "local_path": "extra_memes/meme-generator-contrib",
        "meme_path": "memes"  # 仓库内meme文件夹的相对路径
    },
    "meme_emoji": {
        "url": "https://github.com/anyliew/meme_emoji",
        "archive_url": "https://github.com/anyliew/meme_emoji/archive/refs/heads/main.zip",
        "local_path": "extra_memes/meme_emoji",
        "meme_path": "memes"  # 仓库内meme文件夹的相对路径
    }
}

def download_and_extract_repo(repo_name: str, repo_config: Dict[str, str]) -> bool:
    """下载并解压仓库"""
    print(f"正在下载 {repo_name}...")
    
    try:
        # 创建目标目录
        local_path = Path(repo_config["local_path"])
        local_path.parent.mkdir(parents=True, exist_ok=True)
        
        # 下载zip文件
        response = requests.get(repo_config["archive_url"], stream=True)
        response.raise_for_status()
        
        zip_path = local_path.parent / f"{repo_name}.zip"
        with open(zip_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        # 解压文件
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(local_path.parent)
        
        # 重命名解压后的文件夹
        extracted_folder = local_path.parent / f"{repo_name}-main"
        if extracted_folder.exists():
            if local_path.exists():
                shutil.rmtree(local_path)
            extracted_folder.rename(local_path)
        
        # 清理zip文件
        zip_path.unlink()
        
        print(f"✅ {repo_name} 下载完成")
        return True
        
    except Exception as e:
        print(f"❌ 下载 {repo_name} 失败: {e}")
        return False

def setup_meme_directories() -> List[str]:
    """设置meme目录并返回meme路径列表"""
    meme_dirs = []
    
    # 创建extra_memes目录
    extra_memes_dir = Path("extra_memes")
    extra_memes_dir.mkdir(exist_ok=True)
    
    for repo_name, repo_config in MEME_REPOS.items():
        success = download_and_extract_repo(repo_name, repo_config)
        
        if success:
            # 构建meme目录路径
            repo_path = Path(repo_config["local_path"])
            meme_path = repo_path / repo_config["meme_path"]
            
            if meme_path.exists():
                meme_dirs.append(str(meme_path.absolute()))
                print(f"✅ 添加meme目录: {meme_path}")
            else:
                print(f"⚠️  警告: {repo_name} 中未找到meme目录: {meme_path}")
    
    return meme_dirs

def update_config_file(meme_dirs: List[str]):
    """更新配置文件中的meme目录"""
    config_file = Path("config.toml")
    
    if not config_file.exists():
        # 如果config.toml不存在，从示例文件复制
        example_config = Path("config.example.toml")
        if example_config.exists():
            shutil.copy(example_config, config_file)
            print("✅ 从示例文件创建config.toml")
        else:
            print("❌ 未找到配置文件模板")
            return
    
    # 读取配置文件
    try:
        import toml
        with open(config_file, 'r', encoding='utf-8') as f:
            config = toml.load(f)
        
        # 更新meme目录配置
        if 'meme' not in config:
            config['meme'] = {}
        
        config['meme']['meme_dirs'] = meme_dirs
        
        # 写回配置文件
        with open(config_file, 'w', encoding='utf-8') as f:
            toml.dump(config, f)
        
        print(f"✅ 已更新配置文件，添加了 {len(meme_dirs)} 个额外meme目录")
        
    except ImportError:
        print("❌ 需要安装toml库: pip install toml")
    except Exception as e:
        print(f"❌ 更新配置文件失败: {e}")

def check_git_status():
    """检查是否在git仓库中，并提供版本管理建议"""
    try:
        result = subprocess.run(['git', 'status'], capture_output=True, text=True)
        if result.returncode == 0:
            print("\n📝 Git仓库状态:")
            print("当前在git仓库中，建议将extra_memes目录添加到.gitignore")
            
            gitignore_path = Path(".gitignore")
            gitignore_content = ""
            if gitignore_path.exists():
                gitignore_content = gitignore_path.read_text(encoding='utf-8')
            
            if "extra_memes/" not in gitignore_content:
                with open(gitignore_path, 'a', encoding='utf-8') as f:
                    f.write("\n# 额外的meme仓库（自动下载）\nextra_memes/\n")
                print("✅ 已将extra_memes/添加到.gitignore")
            
    except FileNotFoundError:
        print("\n📝 未检测到git，跳过版本控制配置")

def main():
    """主函数"""
    print("=== meme-generator 额外仓库设置工具 ===\n")
    
    # 检查当前目录
    if not Path("meme_generator").exists():
        print("❌ 请在meme-generator项目根目录下运行此脚本")
        sys.exit(1)
    
    # 下载和设置meme仓库
    meme_dirs = setup_meme_directories()
    
    if meme_dirs:
        # 更新配置文件
        update_config_file(meme_dirs)
        
        # 检查git状态
        check_git_status()
        
        print(f"\n🎉 设置完成！")
        print(f"已添加 {len(meme_dirs)} 个额外meme目录:")
        for meme_dir in meme_dirs:
            print(f"  - {meme_dir}")
        
        print("\n💡 提示:")
        print("- 可以运行 'python setup_meme_repos.py' 来更新额外的meme仓库")
        print("- 配置文件已自动更新，无需手动修改")
        print("- 如需自定义配置，请编辑 config.toml 文件")
        
    else:
        print("❌ 未能成功设置任何额外的meme仓库")
        sys.exit(1)

if __name__ == "__main__":
    main()