import os
from pathlib import Path
from typing import Optional, Union

import toml
from pydantic import BaseModel

from .compat import model_dump, type_validate_python
from .dirs import get_config_file

config_file_path = get_config_file("config.toml")


class MemeConfig(BaseModel):
    load_builtin_memes: bool = True
    meme_dirs: list[Path] = []
    meme_disabled_list: list[str] = []


class ResourceConfig(BaseModel):
    resource_url: Optional[str] = None
    resource_urls: list[str] = [
        "https://raw.githubusercontent.com/MemeCrafters/meme-generator/",
        "https://mirror.ghproxy.com/https://raw.githubusercontent.com/MemeCrafters/meme-generator/",
        "https://cdn.jsdelivr.net/gh/MemeCrafters/meme-generator@",
        "https://fastly.jsdelivr.net/gh/MemeCrafters/meme-generator@",
        "https://raw.gitmirror.com/MemeCrafters/meme-generator/",
    ]


class GifConfig(BaseModel):
    gif_max_size: float = 10
    gif_max_frames: int = 100


class TranslatorConfig(BaseModel):
    # 翻译服务类型: "baidu" 或 "openai"
    translator_type: str = "openai"
    
    # 百度翻译配置
    baidu_trans_appid: str = ""
    baidu_trans_apikey: str = ""
    
    # OpenAI格式翻译配置
    openai_api_base: str = ""
    openai_api_key: str = ""
    openai_model: str = "gpt-3.5-turbo"
    openai_timeout: int = 30


class ServerConfig(BaseModel):
    host: str = "127.0.0.1"
    port: int = 2233


class LogConfig(BaseModel):
    log_level: Union[int, str] = "INFO"


class Config(BaseModel):
    meme: MemeConfig = MemeConfig()
    resource: ResourceConfig = ResourceConfig()
    gif: GifConfig = GifConfig()
    translate: TranslatorConfig = TranslatorConfig()
    server: ServerConfig = ServerConfig()
    log: LogConfig = LogConfig()

    @classmethod
    def load(cls) -> "Config":
        # 首先从 TOML 文件加载配置
        if config_file_path.exists():
            config_data = toml.load(config_file_path)
        else:
            config_data = {}
        
        # 从环境变量覆盖配置
        cls._apply_env_overrides(config_data)
        
        return type_validate_python(cls, config_data)
    
    @classmethod
    def _apply_env_overrides(cls, config_data: dict):
        """从环境变量覆盖配置"""
        # 确保各个配置段存在
        if "translate" not in config_data:
            config_data["translate"] = {}
        if "server" not in config_data:
            config_data["server"] = {}
        if "log" not in config_data:
            config_data["log"] = {}
        if "meme" not in config_data:
            config_data["meme"] = {}
        if "gif" not in config_data:
            config_data["gif"] = {}
        
        # 翻译配置
        if translator_type := os.getenv("TRANSLATOR_TYPE"):
            config_data["translate"]["translator_type"] = translator_type
        if baidu_appid := os.getenv("BAIDU_TRANS_APPID"):
            config_data["translate"]["baidu_trans_appid"] = baidu_appid
        if baidu_apikey := os.getenv("BAIDU_TRANS_APIKEY"):
            config_data["translate"]["baidu_trans_apikey"] = baidu_apikey
        if openai_base := os.getenv("OPENAI_API_BASE"):
            config_data["translate"]["openai_api_base"] = openai_base
        if openai_key := os.getenv("OPENAI_API_KEY"):
            config_data["translate"]["openai_api_key"] = openai_key
        if openai_model := os.getenv("OPENAI_MODEL"):
            config_data["translate"]["openai_model"] = openai_model
        if openai_timeout := os.getenv("OPENAI_TIMEOUT"):
            try:
                config_data["translate"]["openai_timeout"] = int(openai_timeout)
            except ValueError:
                pass
        
        # 服务器配置
        if host := os.getenv("HOST"):
            config_data["server"]["host"] = host
        if port := os.getenv("PORT"):
            try:
                config_data["server"]["port"] = int(port)
            except ValueError:
                pass
        
        # 日志配置
        if log_level := os.getenv("LOG_LEVEL"):
            config_data["log"]["log_level"] = log_level
        
        # GIF 配置
        if gif_max_size := os.getenv("GIF_MAX_SIZE"):
            try:
                config_data["gif"]["gif_max_size"] = float(gif_max_size)
            except ValueError:
                pass
        if gif_max_frames := os.getenv("GIF_MAX_FRAMES"):
            try:
                config_data["gif"]["gif_max_frames"] = int(gif_max_frames)
            except ValueError:
                pass

    def dump(self):
        with open(config_file_path, "w", encoding="utf-8") as f:
            toml.dump(model_dump(self), f)


# 加载配置，支持环境变量覆盖
meme_config = Config.load()

# 如果配置文件不存在，创建一个空文件
if not config_file_path.exists():
    config_file_path.parent.mkdir(parents=True, exist_ok=True)
    config_file_path.write_text("", encoding="utf8")
