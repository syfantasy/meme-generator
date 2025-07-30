from datetime import datetime
from pathlib import Path

from pil_utils import BuildImage

from meme_generator import add_meme

img_dir = Path(__file__).parent / "images"


def dog_face(images: list[BuildImage], texts, args):
    img = images[0].convert("RGBA").square().resize((180, 180))
    frame = BuildImage.open(img_dir / "0.png")
    frame.paste(img, (312, 115), below=True)
    return frame.save_jpg()


add_meme(
    "dog_face",
    dog_face,
    min_images=1,
    max_images=1,
    keywords=["🐶","狗"],
    date_created=datetime(2025, 5, 25),
    date_modified=datetime(2025, 5, 25),
)
