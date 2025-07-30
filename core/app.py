#!/usr/bin/env python3
"""
Hugging Face Spaces 部署入口文件
基于Gradio的meme-generator Web界面
"""

import gradio as gr
import os
import sys
from pathlib import Path
from io import BytesIO
from PIL import Image
import subprocess

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent))

# 在导入meme_generator之前设置额外的meme仓库
def setup_environment():
    """设置环境和下载额外的meme仓库"""
    print("🚀 正在初始化meme-generator环境...")
    
    # 运行setup_meme_repos.py来下载额外的meme仓库
    try:
        result = subprocess.run([sys.executable, "setup_meme_repos.py"], 
                              capture_output=True, text=True, timeout=300)
        if result.returncode == 0:
            print("✅ 额外meme仓库设置完成")
        else:
            print(f"⚠️ 额外meme仓库设置警告: {result.stderr}")
    except subprocess.TimeoutExpired:
        print("⚠️ 额外meme仓库下载超时，使用基础meme")
    except Exception as e:
        print(f"⚠️ 额外meme仓库设置失败: {e}")

# 设置环境
setup_environment()

# 导入meme_generator
try:
    from meme_generator import get_meme, get_meme_keys, MemeArgsModel
    from meme_generator.exception import MemeFeedback
    print("✅ meme-generator 导入成功")
except ImportError as e:
    print(f"❌ meme-generator 导入失败: {e}")
    sys.exit(1)

def get_available_memes():
    """获取可用的meme列表"""
    try:
        meme_keys = get_meme_keys()
        return sorted(meme_keys)
    except Exception as e:
        print(f"获取meme列表失败: {e}")
        return []

def generate_meme(meme_key: str, texts: str, images: list, **kwargs):
    """生成meme"""
    try:
        # 获取meme对象
        meme = get_meme(meme_key)
        if not meme:
            return None, f"未找到meme: {meme_key}"
        
        # 处理文本参数
        text_list = []
        if texts:
            text_list = [t.strip() for t in texts.split('\n') if t.strip()]
        
        # 处理图片参数
        image_list = []
        if images:
            for img in images:
                if img is not None:
                    if isinstance(img, str):
                        # 如果是文件路径
                        image_list.append(open(img, 'rb').read())
                    else:
                        # 如果是PIL Image对象
                        img_bytes = BytesIO()
                        img.save(img_bytes, format='PNG')
                        image_list.append(img_bytes.getvalue())
        
        # 生成meme
        result = meme(images=image_list, texts=text_list, args=MemeArgsModel())
        
        # 转换结果为PIL Image
        if result:
            result_image = Image.open(BytesIO(result.getvalue()))
            return result_image, "生成成功！"
        else:
            return None, "生成失败"
            
    except MemeFeedback as e:
        return None, f"Meme反馈: {str(e)}"
    except Exception as e:
        return None, f"生成错误: {str(e)}"

def create_gradio_interface():
    """创建Gradio界面"""
    
    # 获取可用的meme列表
    available_memes = get_available_memes()
    
    with gr.Blocks(title="Meme Generator", theme=gr.themes.Soft()) as demo:
        gr.Markdown("""
        # 🎭 Meme Generator
        
        基于meme-generator的表情包生成器，支持多种表情包模板。
        
        **特性:**
        - ✅ 支持OpenAI格式翻译
        - ✅ 包含额外meme仓库 (meme-generator-contrib, meme_emoji)
        - ✅ 自动更新meme模板
        """)
        
        with gr.Row():
            with gr.Column(scale=1):
                meme_dropdown = gr.Dropdown(
                    choices=available_memes,
                    label="选择Meme模板",
                    value=available_memes[0] if available_memes else None,
                    interactive=True
                )
                
                texts_input = gr.Textbox(
                    label="文本内容 (每行一个文本)",
                    placeholder="在这里输入文本，每行一个",
                    lines=5
                )
                
                images_input = gr.File(
                    label="上传图片",
                    file_count="multiple",
                    file_types=["image"]
                )
                
                generate_btn = gr.Button("生成Meme", variant="primary")
                
            with gr.Column(scale=1):
                output_image = gr.Image(label="生成结果", type="pil")
                output_message = gr.Textbox(label="状态信息", interactive=False)
        
        # 绑定生成事件
        generate_btn.click(
            fn=generate_meme,
            inputs=[meme_dropdown, texts_input, images_input],
            outputs=[output_image, output_message]
        )
        
        # 添加示例
        gr.Markdown("### 📝 使用说明")
        gr.Markdown("""
        1. **选择模板**: 从下拉菜单中选择一个meme模板
        2. **输入文本**: 在文本框中输入内容，每行一个文本
        3. **上传图片**: 根据模板需要上传相应数量的图片
        4. **生成**: 点击"生成Meme"按钮
        
        **提示**: 不同的meme模板需要不同数量的文本和图片，请根据模板要求提供相应内容。
        """)
        
        # 添加统计信息
        gr.Markdown(f"**当前可用模板数量**: {len(available_memes)}")
    
    return demo

def main():
    """主函数"""
    print("🎭 启动 Meme Generator...")
    
    # 创建Gradio界面
    demo = create_gradio_interface()
    
    # 启动应用
    demo.launch(
        server_name="0.0.0.0",
        server_port=7860,
        share=False,
        show_error=True
    )

if __name__ == "__main__":
    main()