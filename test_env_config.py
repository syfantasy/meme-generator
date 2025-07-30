#!/usr/bin/env python3
"""
测试环境变量配置功能
"""
import os
import sys
from pathlib import Path

# 添加核心模块到路径
sys.path.insert(0, str(Path(__file__).parent / "core"))

def test_env_config():
    """测试环境变量配置"""
    print("=== 测试环境变量配置功能 ===\n")
    
    # 设置测试环境变量
    test_env = {
        "TRANSLATOR_TYPE": "openai",
        "OPENAI_API_BASE": "https://api.openai.com/v1",
        "OPENAI_API_KEY": "test_key_123",
        "OPENAI_MODEL": "gpt-4",
        "HOST": "0.0.0.0",
        "PORT": "8080",
        "LOG_LEVEL": "DEBUG"
    }
    
    print("设置测试环境变量:")
    for key, value in test_env.items():
        os.environ[key] = value
        print(f"  {key}={value}")
    print()
    
    # 重新导入配置模块以应用环境变量
    if "meme_generator.config" in sys.modules:
        del sys.modules["meme_generator.config"]
    
    try:
        from meme_generator.config import meme_config
        
        print("加载的配置:")
        print(f"  翻译器类型: {meme_config.translate.translator_type}")
        print(f"  OpenAI API Base: {meme_config.translate.openai_api_base}")
        print(f"  OpenAI API Key: {meme_config.translate.openai_api_key}")
        print(f"  OpenAI Model: {meme_config.translate.openai_model}")
        print(f"  服务器主机: {meme_config.server.host}")
        print(f"  服务器端口: {meme_config.server.port}")
        print(f"  日志级别: {meme_config.log.log_level}")
        print()
        
        # 验证配置是否正确
        success = True
        if meme_config.translate.translator_type != "openai":
            print("❌ 翻译器类型配置错误")
            success = False
        if meme_config.translate.openai_api_base != "https://api.openai.com/v1":
            print("❌ OpenAI API Base 配置错误")
            success = False
        if meme_config.translate.openai_api_key != "test_key_123":
            print("❌ OpenAI API Key 配置错误")
            success = False
        if meme_config.server.host != "0.0.0.0":
            print("❌ 服务器主机配置错误")
            success = False
        if meme_config.server.port != 8080:
            print("❌ 服务器端口配置错误")
            success = False
        
        if success:
            print("✅ 环境变量配置功能测试通过！")
        else:
            print("❌ 环境变量配置功能测试失败！")
            
    except Exception as e:
        print(f"❌ 配置加载失败: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        # 清理测试环境变量
        for key in test_env:
            if key in os.environ:
                del os.environ[key]

if __name__ == "__main__":
    test_env_config()