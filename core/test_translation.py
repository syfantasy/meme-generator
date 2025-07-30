#!/usr/bin/env python3
"""
翻译功能测试脚本
用于测试百度翻译和OpenAI格式翻译功能
"""

import sys
import os
from pathlib import Path

# 添加项目路径到sys.path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from meme_generator.config import meme_config
from meme_generator.utils import translate, translate_with_baidu, translate_with_openai
from meme_generator.exception import MemeFeedback


def test_translation():
    """测试翻译功能"""
    test_text = "Hello, world!"
    
    print("=== meme-generator 翻译功能测试 ===\n")
    
    # 显示当前配置
    print(f"当前翻译服务类型: {meme_config.translate.translator_type}")
    print(f"百度翻译配置: appid={bool(meme_config.translate.baidu_trans_appid)}, "
          f"apikey={bool(meme_config.translate.baidu_trans_apikey)}")
    print(f"OpenAI翻译配置: api_base={meme_config.translate.openai_api_base}, "
          f"api_key={bool(meme_config.translate.openai_api_key)}, "
          f"model={meme_config.translate.openai_model}")
    print()
    
    # 测试当前配置的翻译服务
    print(f"测试文本: {test_text}")
    print("正在翻译...")
    
    try:
        result = translate(test_text, lang_from="en", lang_to="zh")
        print(f"翻译结果: {result}")
        print("✅ 翻译功能测试成功！")
    except MemeFeedback as e:
        print(f"❌ 翻译失败: {e}")
        print("请检查配置文件中的翻译服务配置")
    except Exception as e:
        print(f"❌ 翻译出错: {e}")
    
    print("\n=== 测试完成 ===")


def test_specific_translator(translator_type: str):
    """测试特定的翻译服务"""
    test_text = "Hello, world!"
    
    print(f"=== 测试 {translator_type} 翻译服务 ===\n")
    
    try:
        if translator_type == "baidu":
            result = translate_with_baidu(test_text, lang_from="en", lang_to="zh")
        elif translator_type == "openai":
            result = translate_with_openai(test_text, lang_from="en", lang_to="zh")
        else:
            print(f"❌ 不支持的翻译服务类型: {translator_type}")
            return
            
        print(f"测试文本: {test_text}")
        print(f"翻译结果: {result}")
        print(f"✅ {translator_type} 翻译服务测试成功！")
        
    except MemeFeedback as e:
        print(f"❌ {translator_type} 翻译失败: {e}")
    except Exception as e:
        print(f"❌ {translator_type} 翻译出错: {e}")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        # 测试特定翻译服务
        translator_type = sys.argv[1].lower()
        if translator_type in ["baidu", "openai"]:
            test_specific_translator(translator_type)
        else:
            print("用法: python test_translation.py [baidu|openai]")
            print("不指定参数时使用配置文件中的翻译服务")
    else:
        # 测试当前配置的翻译服务
        test_translation()