#!/usr/bin/env python3
"""Draws the addon's window artwork as TGA files in addon/AdventureChronicler/media/.

Everything is drawn from code here (shapes, gradients and seeded noise), so the images contain
nothing copied from the game or elsewhere and are the same every run. Sizes are powers of two and
the files are uncompressed 32-bit TGA, which the game client reads.

Run: python3 tools/gen_textures.py          (writes the files)
     python3 tools/gen_textures.py --check  (fails if the files are out of date)
"""
import io
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "addon", "AdventureChronicler", "media")
SS = 4  # supersampling for smooth edges

GOLD = (214, 170, 92, 255)
GOLD_HI = (240, 208, 140, 255)
GOLD_LO = (150, 108, 50, 255)


def noise(w, h, seed, scale, amp):
    """Smooth value noise in [-amp, amp], made by blurring random pixels."""
    rnd = random.Random(seed)
    small = Image.new("L", (max(1, w // scale), max(1, h // scale)))
    small.putdata([rnd.randint(0, 255) for _ in range(small.width * small.height)])
    big = small.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(scale / 2))
    return [((v - 128) / 128.0) * amp for v in big.getdata()]


def shade(base, w, h, seed, layers, vignette=0.0, spots=0, spot_dark=0.0):
    img = Image.new("RGBA", (w, h))
    fields = [noise(w, h, seed + i, s, a) for i, (s, a) in enumerate(layers)]
    rnd = random.Random(seed * 7)
    spot_list = [(rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(4, w / 6)) for _ in range(spots)]
    px = []
    for y in range(h):
        for x in range(w):
            i = y * w + x
            d = sum(f[i] for f in fields)
            if vignette:
                dx, dy = (x / w - 0.5) * 2, (y / h - 0.5) * 2
                d -= vignette * max(0.0, (dx * dx + dy * dy) ** 0.5 - 0.35)
            for sx, sy, sr in spot_list:
                r = math.hypot(x - sx, y - sy)
                if r < sr:
                    d -= spot_dark * (1 - r / sr) ** 2
            px.append(tuple(max(0, min(255, int(c * (1 + d)))) for c in base) + (255,))
    img.putdata(px)
    return img


def frame_bg():
    return shade((34, 28, 22), 256, 256, 11, [(32, 0.10), (6, 0.05)], vignette=0.25)


def header_bg():
    img = shade((44, 35, 26), 256, 64, 12, [(24, 0.08), (4, 0.04)])
    grad = Image.linear_gradient("L").resize((256, 64)).point(lambda v: 255 - v // 3)
    dark = Image.new("RGBA", (256, 64), (18, 14, 10, 255))
    return Image.composite(img, dark, grad)


def parchment():
    # Darker, weathered parchment so cream text elsewhere stays the brightest thing on screen.
    return shade((206, 182, 136), 256, 128, 13, [(40, 0.08), (10, 0.06), (3, 0.03)],
                 vignette=0.35, spots=9, spot_dark=0.18)


def button(base, seed):
    w, h = 128, 64
    img = shade(base, w, h, seed, [(16, 0.08), (4, 0.04)])
    grad = Image.linear_gradient("L").resize((w, h))
    dark = Image.new("RGBA", (w, h), tuple(int(c * 0.55) for c in base) + (255,))
    img = Image.composite(dark, img, grad.point(lambda v: v // 2))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=GOLD_LO)
    d.rectangle([2, 2, w - 3, h - 3], outline=(0, 0, 0, 160))
    d.line([3, 3, w - 4, 3], fill=(255, 235, 200, 40))
    return img


def glow():
    w, h = 128, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    a = Image.new("L", (w, h), 0)
    ImageDraw.Draw(a).rounded_rectangle([10, 8, w - 11, h - 9], radius=12, fill=110)
    a = a.filter(ImageFilter.GaussianBlur(10))
    img.putalpha(a)
    img = Image.merge("RGBA", (Image.new("L", (w, h), 255), Image.new("L", (w, h), 210),
                               Image.new("L", (w, h), 140), a))
    return img


def canvas(n=64):
    return Image.new("RGBA", (n * SS, n * SS), (0, 0, 0, 0))


def finish(img, n=64, shadow=True):
    img = img.resize((n, n), Image.LANCZOS)
    if shadow:
        a = img.getchannel("A").filter(ImageFilter.GaussianBlur(1.2))
        sh = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        sh.putalpha(a.point(lambda v: v * 3 // 5))
        out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        out.alpha_composite(sh, (1, 1))
        out.alpha_composite(img)
        return out
    return img


def S(*pts):
    return [(x * SS, y * SS) for x, y in pts]


def w(v):
    return int(v * SS)


def diamond():
    img = canvas(16)
    d = ImageDraw.Draw(img)
    d.polygon(S((8, 1), (15, 8), (8, 15), (1, 8)), fill=GOLD)
    d.polygon(S((8, 4), (12, 8), (8, 12), (4, 8)), fill=GOLD_HI)
    return finish(img, 16, shadow=False)


def dot():
    img = canvas(32)
    d = ImageDraw.Draw(img)
    d.ellipse(S((7, 7), (25, 25)), fill=(255, 255, 255, 255))
    a = img.getchannel("A").filter(ImageFilter.GaussianBlur(3 * SS))
    halo = Image.new("RGBA", img.size, (255, 255, 255, 0))
    halo.putalpha(a.point(lambda v: v // 2))
    halo.alpha_composite(img)
    return finish(halo, 32, shadow=False)


def compass():
    img = canvas(64)
    d = ImageDraw.Draw(img)
    c = 32
    d.ellipse(S((14, 14), (50, 50)), outline=GOLD, width=w(2))
    for ang in range(0, 360, 45):
        long_ = ang % 90 == 0
        r = 30 if long_ else 18
        a = math.radians(ang)
        tip = (c + r * math.sin(a), c - r * math.cos(a))
        side = 5 if long_ else 4
        l = (c + side * math.sin(a - math.pi / 2), c - side * math.cos(a - math.pi / 2))
        rr = (c + side * math.sin(a + math.pi / 2), c - side * math.cos(a + math.pi / 2))
        d.polygon(S(tip, l, (c, c)), fill=GOLD_HI)
        d.polygon(S(tip, rr, (c, c)), fill=GOLD_LO)
    d.ellipse(S((29, 29), (35, 35)), fill=GOLD_HI)
    return finish(img)


# Line-art icons in gold, in the style of the mock.
def icon(draw_fn):
    img = canvas(64)
    draw_fn(ImageDraw.Draw(img))
    return finish(img)


def ic_instance(d):
    d.rectangle(S((12, 54), (52, 58)), fill=GOLD)
    d.rectangle(S((14, 26), (22, 54)), fill=GOLD)
    d.rectangle(S((42, 26), (50, 54)), fill=GOLD)
    d.pieslice(S((14, 8), (50, 44)), 180, 360, fill=GOLD)
    d.pieslice(S((22, 16), (42, 36)), 180, 360, fill=(0, 0, 0, 0))
    d.rectangle(S((22, 26), (42, 54)), fill=(0, 0, 0, 0))


def ic_encounter(d):
    for flip in (False, True):
        def P(x, y):
            return (64 - x, y) if flip else (x, y)
        d.polygon(S(P(10, 10), P(16, 10), P(46, 40), P(42, 44)), fill=GOLD_HI)
        d.line(S(P(36, 48), P(50, 34)), fill=GOLD, width=w(4))
        d.line(S(P(44, 44), P(54, 54)), fill=GOLD, width=w(4))


def ic_bookmark(d):
    d.polygon(S((18, 8), (46, 8), (46, 56), (32, 44), (18, 56)), fill=GOLD)
    d.polygon(S((22, 12), (42, 12), (42, 46), (32, 38), (22, 46)), fill=GOLD_HI)


def ic_zone(d):
    d.ellipse(S((18, 6), (46, 34)), fill=GOLD)
    d.polygon(S((20, 26), (44, 26), (32, 56)), fill=GOLD)
    d.ellipse(S((26, 14), (38, 26)), fill=(0, 0, 0, 0))


def ic_quest(d):
    d.rounded_rectangle(S((16, 10), (48, 54)), radius=w(4), outline=GOLD, width=w(4))
    for y in (22, 31, 40):
        d.line(S((23, y), (41, y)), fill=GOLD_HI, width=w(3))


def ic_item(d):
    d.rounded_rectangle(S((14, 22), (50, 56)), radius=w(8), fill=GOLD)
    d.arc(S((22, 8), (42, 30)), 180, 360, fill=GOLD_HI, width=w(4))
    d.line(S((22, 34), (42, 34)), fill=GOLD_LO, width=w(3))


def ic_pvp(d):
    d.line(S((18, 6), (18, 58)), fill=GOLD_HI, width=w(4))
    d.polygon(S((20, 8), (50, 14), (40, 22), (50, 30), (20, 32)), fill=GOLD)


def ic_death(d):
    d.ellipse(S((14, 8), (50, 42)), fill=GOLD)
    d.rectangle(S((22, 38), (42, 52)), fill=GOLD)
    d.ellipse(S((20, 20), (29, 30)), fill=(0, 0, 0, 0))
    d.ellipse(S((35, 20), (44, 30)), fill=(0, 0, 0, 0))
    for x in (26, 32, 38):
        d.line(S((x, 44), (x, 52)), fill=(0, 0, 0, 0), width=w(2))


def ic_screenshot(d):
    d.rounded_rectangle(S((8, 18), (56, 50)), radius=w(5), fill=GOLD)
    d.rectangle(S((22, 12), (36, 18)), fill=GOLD)
    d.ellipse(S((22, 22), (42, 44)), fill=(0, 0, 0, 0))
    d.ellipse(S((27, 27), (37, 39)), fill=GOLD_HI)


def ic_note(d):
    d.polygon(S((44, 6), (54, 12), (26, 52), (18, 56), (18, 48)), fill=GOLD)
    d.line(S((46, 12), (24, 46)), fill=GOLD_HI, width=w(2))
    d.line(S((10, 58), (52, 58)), fill=GOLD_LO, width=w(3))


def ic_other(d):
    d.ellipse(S((22, 22), (42, 42)), fill=GOLD)


def ic_clock(d):
    d.ellipse(S((8, 8), (56, 56)), fill=GOLD)
    d.ellipse(S((13, 13), (51, 51)), fill=(40, 30, 20, 255))
    d.line(S((32, 32), (32, 17)), fill=GOLD_HI, width=w(4))
    d.line(S((32, 32), (43, 38)), fill=GOLD_HI, width=w(4))


def ic_stop(d):
    d.rounded_rectangle(S((14, 14), (50, 50)), radius=w(4), fill=(230, 170, 70, 255))
    d.rounded_rectangle(S((18, 18), (46, 46)), radius=w(3), fill=(246, 196, 104, 255))


def ic_export(d):
    d.rectangle(S((10, 30), (14, 54)), fill=GOLD)
    d.rectangle(S((10, 50), (50, 54)), fill=GOLD)
    d.rectangle(S((46, 40), (50, 54)), fill=GOLD)
    d.line(S((22, 44), (46, 18)), fill=GOLD_HI, width=w(5))
    d.polygon(S((34, 12), (54, 10), (52, 30)), fill=GOLD_HI)


def ic_add_note(d):
    d.rectangle(S((10, 14), (40, 56)), outline=GOLD, width=w(4))
    for y in (26, 34, 42):
        d.line(S((16, y), (32, y)), fill=GOLD, width=w(3))
    d.polygon(S((48, 6), (56, 12), (36, 40), (28, 44), (30, 36)), fill=GOLD_HI)


def ic_close(d):
    d.rectangle(S((4, 4), (60, 60)), outline=GOLD, width=w(4))
    d.line(S((20, 20), (44, 44)), fill=GOLD_HI, width=w(6))
    d.line(S((44, 20), (20, 44)), fill=GOLD_HI, width=w(6))


ICONS = {
    "icon_instance": ic_instance, "icon_encounter": ic_encounter, "icon_bookmark": ic_bookmark,
    "icon_zone": ic_zone, "icon_quest": ic_quest, "icon_item": ic_item, "icon_pvp": ic_pvp,
    "icon_death": ic_death, "icon_screenshot": ic_screenshot, "icon_note": ic_note,
    "icon_other": ic_other, "icon_clock": ic_clock, "icon_stop": ic_stop, "icon_export": ic_export,
    "icon_add_note": ic_add_note, "icon_close": ic_close,
}


def all_images():
    imgs = {
        "frame_bg": frame_bg(), "header_bg": header_bg(), "parchment": parchment(),
        "button_dark": button((70, 54, 38), 21), "button_red": button((112, 30, 24), 22),
        "button_gold": button((196, 146, 62), 23), "button_glow": glow(),
        "diamond": diamond(), "dot": dot(), "compass": compass(),
    }
    for name, fn in ICONS.items():
        imgs[name] = icon(fn)
    return imgs


def tga_bytes(img):
    buf = io.BytesIO()
    img.convert("RGBA").save(buf, format="TGA", rle=False)
    return buf.getvalue()


def main(argv):
    check = "--check" in argv
    os.makedirs(OUT, exist_ok=True)
    stale = []
    for name, img in sorted(all_images().items()):
        assert img.width & (img.width - 1) == 0 and img.height & (img.height - 1) == 0, name
        data = tga_bytes(img)
        path = os.path.join(OUT, name + ".tga")
        if check:
            if not os.path.isfile(path) or open(path, "rb").read() != data:
                stale.append(name)
        else:
            with open(path, "wb") as fh:
                fh.write(data)
        if "--png" in argv:
            img.save(os.path.join("/tmp", "ac_media_" + name + ".png"))
    if stale:
        print("out of date: " + ", ".join(stale) + " (run tools/gen_textures.py)", file=sys.stderr)
        return 1
    print(("checked " if check else "wrote ") + f"{len(all_images())} textures")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
