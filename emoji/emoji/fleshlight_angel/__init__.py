from datetime import datetime
from pathlib import Path

from pil_utils import BuildImage

from meme_generator import MemeArgsModel, add_meme
from meme_generator.exception import TextOverLength
from meme_generator.utils import make_jpg_or_gif

img_dir = Path(__file__).parent / "images"


def fleshlight_angel(images: list[BuildImage], texts: list[str], args: MemeArgsModel):
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
            (533, 39, 779, 140 ),
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
        img = imgs[0].convert("RGBA").circle().resize((675, 675))
        return frame.copy().paste(img, (65, 105), alpha=True,below=True)

    return make_jpg_or_gif(images, make)


add_meme(
    "fleshlight_angel",
    fleshlight_angel,
    min_images=1,
    max_images=1,
    min_texts=0,
    max_texts=1,
    keywords=["天使心"],
    date_created=datetime(2025, 3, 24),
    date_modified=datetime(2025, 3, 24),
)
