from datetime import datetime
from pathlib import Path

from pil_utils import BuildImage

from meme_generator import MemeArgsModel, add_meme
from meme_generator.exception import TextOverLength
from meme_generator.utils import make_jpg_or_gif

img_dir = Path(__file__).parent / "images"


def fleshlight_jissbon(images: list[BuildImage], texts: list[str], args: MemeArgsModel):
    frame = BuildImage.open(img_dir / "0.png")

    ta = "他"
    name = ta
    if texts:
        name = texts[0]
    elif args.user_infos:
        info = args.user_infos[0]
        ta = "他" if info.gender == "male" else "她"
        name = info.name or ta

    text = f"{name}の深情❤️推荐"
    #{name}挚爱❤️👩‍❤️‍💋‍👨{name}愛のカップ。
    try:
        frame.draw_text(
            (261, 31, 758, 91),
            text,
            fill=(0, 0, 0),
            max_fontsize=120,
            min_fontsize=20,
            lines_align="left",
            font_families=["FZXS14"],
        )
    except ValueError:
        raise TextOverLength(name)

    def make(imgs: list[BuildImage]) -> BuildImage:
        img = imgs[0].convert("RGBA").circle().resize((180, 180))
        return frame.copy().paste(img, (475, 180), alpha=True)

    return make_jpg_or_gif(images, make)


add_meme(
    "fleshlight_jissbon",
    fleshlight_jissbon,
    min_images=1,
    max_images=1,
    min_texts=0,
    max_texts=1,
    keywords=["杰士邦"],
    date_created=datetime(2024, 12, 21),
    date_modified=datetime(2024, 12, 21),
)
