from datetime import datetime
from pathlib import Path

from pil_utils import BuildImage

from meme_generator import MemeArgsModel, add_meme
from meme_generator.exception import TextOverLength
from meme_generator.utils import make_jpg_or_gif

img_dir = Path(__file__).parent / "images"


def fleshlight_miyuko_kamimiya(images: list[BuildImage], texts: list[str], args: MemeArgsModel):
    frame = BuildImage.open(img_dir / "0.png")

    ta = "他"
    name = ta
    if texts:
        name = texts[0]
    elif args.user_infos:
        info = args.user_infos[0]
        ta = "他" if info.gender == "male" else "她"
        name = info.name or ta

    text = f"{name}の❤️最愛"
    #{name}挚爱❤️👩‍❤️‍💋‍👨{name}愛のカップ。
    try:
        frame.draw_text(
            (13, 1039, 428, 1191),
            text,
            fill="white",
            max_fontsize=100,
            min_fontsize=20,
            lines_align="center",
            font_families=["FZShaoEr-M11S"],
        )
    except ValueError:
        raise TextOverLength(name)

    def make(imgs: list[BuildImage]) -> BuildImage:
        img = imgs[0].convert("RGBA").circle().resize((950, 950))
        return frame.copy().paste(img, (275, -10), alpha=True,below=True)

    return make_jpg_or_gif(images, make)


add_meme(
    "fleshlight_miyuko_kamimiya",
    fleshlight_miyuko_kamimiya,
    min_images=1,
    max_images=1,
    min_texts=0,
    max_texts=1,
    keywords=["神宫美优子"],
    date_created=datetime(2025, 3, 24),
    date_modified=datetime(2025, 3, 24),
)
