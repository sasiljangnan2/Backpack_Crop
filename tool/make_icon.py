"""앱 아이콘 원본(assets/icon/*.png)을 만든다.

    python tool/make_icon.py
    dart run flutter_launcher_icons

에메랄드 바탕(#009B77)에 흰 배낭. 안드로이드 적응형 아이콘용 전경(투명 바탕)도 함께 만든다.
"""
from pathlib import Path

from PIL import Image, ImageDraw

BRAND = (0, 155, 119, 255)
WHITE = (255, 255, 255, 255)
SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'icon'


def backpack(draw: ImageDraw.ImageDraw, scale: float, cx: float, cy: float, cut=BRAND) -> None:
    def box(x0, y0, x1, y1):
        return [cx + x0 * scale, cy + y0 * scale, cx + x1 * scale, cy + y1 * scale]

    w = 22 * scale
    # 손잡이
    draw.rounded_rectangle(box(-90, -250, 90, -110), radius=90 * scale, outline=WHITE, width=int(w))
    # 몸통
    draw.rounded_rectangle(box(-210, -170, 210, 260), radius=120 * scale, fill=WHITE)
    # 덮개 선
    draw.rounded_rectangle(box(-150, -90, 150, 40), radius=60 * scale, fill=cut)
    draw.rounded_rectangle(box(-128, -68, 128, 18), radius=44 * scale, fill=WHITE)
    # 앞주머니
    draw.rounded_rectangle(box(-130, 90, 130, 210), radius=40 * scale, fill=cut)
    draw.rectangle(box(-30, 70, 30, 120), fill=WHITE)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    icon = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(icon)
    d.rounded_rectangle([0, 0, SIZE, SIZE], radius=230, fill=BRAND)
    backpack(d, 1.35, SIZE / 2, SIZE / 2 + 20)
    icon.save(OUT / 'icon.png')

    # 적응형 아이콘 전경: 가운데 66% 안에 들어가게 작게
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(fg)
    backpack(d, 0.95, SIZE / 2, SIZE / 2 + 15, cut=(0, 0, 0, 0))
    fg.save(OUT / 'icon_foreground.png')


if __name__ == '__main__':
    main()
