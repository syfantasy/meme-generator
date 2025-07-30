#!/usr/bin/env python3
"""
测试 OpenAI API URL 构建逻辑
"""

def test_url_construction():
    """测试不同 API base 配置下的 URL 构建"""
    
    test_cases = [
        # (api_base, expected_url)
        ("https://api.openai.com", "https://api.openai.com/v1/chat/completions"),
        ("https://api.openai.com/", "https://api.openai.com/v1/chat/completions"),
        ("https://api.openai.com/v1", "https://api.openai.com/v1/chat/completions"),
        ("https://api.openai.com/v1/", "https://api.openai.com/v1/chat/completions"),
        ("https://your-proxy.com/openai", "https://your-proxy.com/openai/v1/chat/completions"),
        ("https://your-proxy.com/openai/", "https://your-proxy.com/openai/v1/chat/completions"),
        ("https://your-proxy.com/openai/v1", "https://your-proxy.com/openai/v1/chat/completions"),
        ("https://your-proxy.com/openai/v1/", "https://your-proxy.com/openai/v1/chat/completions"),
    ]
    
    print("=== 测试 OpenAI API URL 构建逻辑 ===\n")
    
    for api_base, expected_url in test_cases:
        # 模拟原始的 URL 构建逻辑
        if api_base.endswith("/v1") or api_base.endswith("/v1/"):
            # 如果已经包含 /v1，直接添加端点
            base_url = api_base.rstrip("/")
            url = f"{base_url}/chat/completions"
        elif api_base.endswith("/"):
            # 如果以 / 结尾但没有 v1，添加 v1/chat/completions
            url = f"{api_base}v1/chat/completions"
        else:
            # 如果没有以 / 结尾，添加 /v1/chat/completions
            url = f"{api_base}/v1/chat/completions"
        
        status = "✅" if url == expected_url else "❌"
        print(f"{status} API Base: {api_base}")
        print(f"   构建的URL: {url}")
        print(f"   期望的URL: {expected_url}")
        if url != expected_url:
            print(f"   ❌ URL 构建错误！")
        print()
    
    print("URL 构建逻辑测试完成！")

if __name__ == "__main__":
    test_url_construction()