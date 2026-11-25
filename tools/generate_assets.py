#!/usr/bin/env python3
"""
Generates all Pixel Art PNG spritesheets/atlases/portraits and PCM WAV audio
for Whispering Valley using only Python standard library.
"""
import json
import math
import os
import random
import struct
import wave
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(ROOT, "data")
ASSETS_DIR = os.path.join(ROOT, "assets")


def hex_rgba(h: str, a: int = 255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(col, factor: float):
    r, g, b, a = col
    return (
        max(0, min(255, int(r * factor))),
        max(0, min(255, int(g * factor))),
        max(0, min(255, int(b * factor))),
        a,
    )


def write_png(path: str, width: int, height: int, pixels):
    """pixels: flat bytearray or list of RGBA tuples length width*height."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    raw = bytearray()
    if isinstance(pixels, (bytes, bytearray)):
        stride = width * 4
        for y in range(height):
            raw.append(0)
            raw.extend(pixels[y * stride:(y + 1) * stride])
    else:
        for y in range(height):
            raw.append(0)
            row_start = y * width
            for x in range(width):
                r, g, b, a = pixels[row_start + x]
                raw.extend((r, g, b, a))

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", crc)

    ihdr = struct.pack("!IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 6)
    png_bytes = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png_bytes)


class Canvas:
    def __init__(self, w: int, h: int, bg=(0, 0, 0, 0)):
        self.w = w
        self.h = h
        self.buf = bytearray(bg * (w * h))

    def set(self, x: int, y: int, col):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 4
            if col[3] == 255:
                self.buf[i:i + 4] = bytes(col)
            elif col[3] > 0:
                sa = col[3] / 255.0
                da = 1.0 - sa
                self.buf[i] = int(col[0] * sa + self.buf[i] * da)
                self.buf[i + 1] = int(col[1] * sa + self.buf[i + 1] * da)
                self.buf[i + 2] = int(col[2] * sa + self.buf[i + 2] * da)
                self.buf[i + 3] = min(255, int(col[3] + self.buf[i + 3] * da))

    def rect(self, x: int, y: int, w: int, h: int, col):
        for py in range(y, y + h):
            for px in range(x, x + w):
                self.set(px, py, col)

    def circle(self, cx: int, cy: int, r: int, col):
        for py in range(cy - r, cy + r + 1):
            for px in range(cx - r, cx + r + 1):
                if (px - cx) * (px - cx) + (py - cy) * (py - cy) <= r * r:
                    self.set(px, py, col)

    def save(self, path: str):
        write_png(path, self.w, self.h, self.buf)


OUTLINE = (32, 24, 28, 255)


def generate_tileset():
    # 16 cols x 4 rows of 16x16 = 256 x 64
    c = Canvas(256, 64)
    rng = random.Random(42)

    def tile_fill(col_idx, row_idx, base, speckle_cols):
        ox, oy = col_idx * 16, row_idx * 16
        c.rect(ox, oy, 16, 16, base)
        for _ in range(18):
            px = ox + rng.randint(0, 15)
            py = oy + rng.randint(0, 15)
            c.set(px, py, rng.choice(speckle_cols))

    # Row 0: Ground terrains (0..15)
    tile_fill(0, 0, hex_rgba("#5fa34d"), [hex_rgba("#529142"), hex_rgba("#72b55c")])  # Spring grass
    tile_fill(1, 0, hex_rgba("#5fa34d"), [hex_rgba("#72b55c")])
    c.set(4, 5, hex_rgba("#f5df66")); c.set(11, 10, hex_rgba("#f29cb8"))  # Flower grass
    tile_fill(2, 0, hex_rgba("#4c8c42"), [hex_rgba("#3e7836"), hex_rgba("#63a353")])  # Summer/Forest grass
    tile_fill(3, 0, hex_rgba("#a87b4c"), [hex_rgba("#94693e"), hex_rgba("#bc8c5b")])  # Dirt
    # Tilled dry soil (4)
    tile_fill(4, 0, hex_rgba("#8a5d36"), [hex_rgba("#734b28")])
    for y in (3, 7, 11, 14):
        c.rect(4 * 16 + 1, y, 14, 1, hex_rgba("#603d1f"))
    # Tilled watered soil (5)
    tile_fill(5, 0, hex_rgba("#523420"), [hex_rgba("#402616")])
    for y in (3, 7, 11, 14):
        c.rect(5 * 16 + 1, y, 14, 1, hex_rgba("#361f12"))
    # Sand (6), Dune (7), Snow (8), Snow rock (9)
    tile_fill(6, 0, hex_rgba("#e5cb85"), [hex_rgba("#d4b76e"), hex_rgba("#f2dc9b")])
    tile_fill(7, 0, hex_rgba("#deb86b"), [hex_rgba("#c9a053"), hex_rgba("#ecd08d")])
    tile_fill(8, 0, hex_rgba("#e6f0f7"), [hex_rgba("#d2e3ef"), hex_rgba("#ffffff")])
    tile_fill(9, 0, hex_rgba("#d5e5f0"), [hex_rgba("#b5cce0"), hex_rgba("#ffffff")])
    # Autumn grass (10), Leaf turf (11)
    tile_fill(10, 0, hex_rgba("#c78a38"), [hex_rgba("#b07428"), hex_rgba("#dea14c")])
    tile_fill(11, 0, hex_rgba("#b87533"), [hex_rgba("#d9593b"), hex_rgba("#e6b647")])
    # Stone floor (12), Mine floor (13), Mushroom turf (14), Sanctuary turf (15)
    tile_fill(12, 0, hex_rgba("#858b94"), [hex_rgba("#6f757e"), hex_rgba("#9da4ae")])
    tile_fill(13, 0, hex_rgba("#4c4654"), [hex_rgba("#3d3845"), hex_rgba("#5e5869")])
    tile_fill(14, 0, hex_rgba("#564878"), [hex_rgba("#6c5994"), hex_rgba("#8e6fc4")])
    tile_fill(15, 0, hex_rgba("#438282"), [hex_rgba("#60abab"), hex_rgba("#89d9d0")])

    # Row 1: Water, paths, walls, interior floors
    tile_fill(0, 1, hex_rgba("#3b8ec2"), [hex_rgba("#57a8db"), hex_rgba("#2f77a6")])  # Water
    c.rect(2, 20, 4, 1, hex_rgba("#87cef5")); c.rect(9, 26, 5, 1, hex_rgba("#87cef5"))
    tile_fill(1, 1, hex_rgba("#296b99"), [hex_rgba("#357ead")])  # Deep water
    tile_fill(2, 1, hex_rgba("#69b6db"), [hex_rgba("#a8dff5")])  # Shore
    # Cobble path (3)
    tile_fill(3, 1, hex_rgba("#918b82"), [hex_rgba("#767067")])
    for bx, by in [(3, 18), (9, 19), (2, 24), (10, 25), (6, 28)]:
        c.rect(3 * 16 + bx, by, 4, 3, hex_rgba("#b3aca3"))
    # Wood plank path (4) & Bridge (5)
    for px_col in (4, 5):
        ox = px_col * 16
        c.rect(ox, 16, 16, 16, hex_rgba("#9c6b3f"))
        for y in range(16, 32, 4):
            c.rect(ox, y, 16, 1, hex_rgba("#694322"))
        if px_col == 5:
            c.rect(ox, 16, 16, 2, hex_rgba("#523318"))
            c.rect(ox, 30, 16, 2, hex_rgba("#523318"))
    # Fence post (6), Fence H (7), Stone Wall (8), Hedge (9)
    tile_fill(6, 1, hex_rgba("#5fa34d"), [hex_rgba("#529142")])
    c.rect(6 * 16 + 5, 19, 6, 11, hex_rgba("#8b5a34"))
    c.rect(6 * 16 + 6, 18, 4, 2, hex_rgba("#ab7549"))
    tile_fill(7, 1, hex_rgba("#5fa34d"), [hex_rgba("#529142")])
    c.rect(7 * 16, 21, 16, 4, hex_rgba("#8b5a34"))
    c.rect(7 * 16 + 5, 18, 6, 12, hex_rgba("#ab7549"))
    tile_fill(8, 1, hex_rgba("#6c6f78"), [hex_rgba("#545760"), hex_rgba("#888c96")])
    c.rect(8 * 16, 16, 16, 2, hex_rgba("#9ea3ad"))
    tile_fill(9, 1, hex_rgba("#2f6930"), [hex_rgba("#224f23"), hex_rgba("#448545")])  # Hedge
    tile_fill(10, 1, hex_rgba("#3d4a35"), [hex_rgba("#293323")])  # Forest border cliff
    tile_fill(11, 1, hex_rgba("#4f5d6b"), [hex_rgba("#38434f")])  # Mountain cliff
    # Interior wood floor (12), Rug (13), Interior wall (14), Shipping bin (15)
    c.rect(12 * 16, 16, 16, 16, hex_rgba("#b8824c"))
    for y in range(16, 32, 4):
        c.rect(12 * 16, y, 16, 1, hex_rgba("#916234"))
    c.rect(13 * 16, 16, 16, 16, hex_rgba("#a33e46"))
    c.rect(13 * 16 + 2, 18, 12, 12, hex_rgba("#d9a952"))
    c.rect(13 * 16 + 4, 20, 8, 8, hex_rgba("#c44d56"))
    c.rect(14 * 16, 16, 16, 16, hex_rgba("#d6c29f"))
    c.rect(14 * 16, 28, 16, 4, hex_rgba("#7a5130"))
    c.rect(15 * 16 + 1, 18, 14, 12, hex_rgba("#8b5a34"))
    c.rect(15 * 16 + 2, 19, 12, 4, hex_rgba("#ba844e"))
    c.rect(15 * 16 + 6, 24, 4, 3, hex_rgba("#e5c158"))

    # Row 2: Nature obstacles, Ores, Mine Ladder, Signs
    # Pine tree (0), Oak tree (1), Maple (2), Palm (3), Giant Shroom (4), Crystal (5)
    trees = [
        (0, "#245938", "#35784d", "#5c3b24"),
        (1, "#377a38", "#54a34c", "#734a2b"),
        (2, "#ba4f29", "#de7b35", "#694126"),
        (3, "#4ea143", "#74c458", "#8c6b43"),
        (4, "#a8385b", "#e384a0", "#e6d8c3"),
        (5, "#47a8b5", "#89e8f0", "#3a6e7d"),
    ]
    for tidx, dark_c, light_c, trunk_c in trees:
        ox = tidx * 16
        c.rect(ox + 6, 42, 4, 6, hex_rgba(trunk_c))
        c.circle(ox + 8, 38, 6, hex_rgba(dark_c))
        c.circle(ox + 7, 37, 4, hex_rgba(light_c))

    # Boulder (6), Copper (7), Iron (8), Gold (9), Iridium (10)
    ores = [
        (6, "#7b8088", "#9ea3ab"),
        (7, "#767378", "#d4763b"),
        (8, "#6f747d", "#b8cde0"),
        (9, "#736e66", "#f2c641"),
        (10, "#5c5269", "#a852e6"),
    ]
    for oidx, rock_c, vein_c in ores:
        ox = oidx * 16
        c.circle(ox + 8, 41, 5, OUTLINE)
        c.circle(ox + 8, 41, 4, hex_rgba(rock_c))
        c.rect(ox + 6, 39, 2, 2, hex_rgba(vein_c))
        c.rect(ox + 9, 41, 2, 2, hex_rgba(vein_c))

    # Mine Ladder (11), Hearth (12), Signpost (13), Mailbox (14), Well (15)
    ox = 11 * 16
    c.rect(ox + 3, 33, 2, 14, hex_rgba("#8b5a34"))
    c.rect(ox + 11, 33, 2, 14, hex_rgba("#8b5a34"))
    for y in (35, 39, 43):
        c.rect(ox + 3, y, 10, 2, hex_rgba("#b57c4a"))
    # Hearth (12)
    c.rect(12 * 16 + 2, 34, 12, 12, hex_rgba("#696268"))
    c.rect(12 * 16 + 5, 38, 6, 7, hex_rgba("#f07828"))
    c.rect(12 * 16 + 6, 40, 4, 4, hex_rgba("#ffdf66"))
    # Sign (13)
    c.rect(13 * 16 + 7, 40, 2, 7, hex_rgba("#6e4726"))
    c.rect(13 * 16 + 2, 34, 12, 7, hex_rgba("#b57c4a"))
    # Mailbox (14)
    c.rect(14 * 16 + 7, 40, 2, 7, hex_rgba("#6e4726"))
    c.rect(14 * 16 + 4, 34, 8, 6, hex_rgba("#4f7cb5"))
    c.rect(14 * 16 + 11, 35, 2, 3, hex_rgba("#e04a4a"))
    # Well (15)
    c.circle(15 * 16 + 8, 42, 6, hex_rgba("#7a808a"))
    c.circle(15 * 16 + 8, 42, 4, hex_rgba("#3b8ec2"))
    c.rect(15 * 16 + 3, 33, 10, 3, hex_rgba("#8c4432"))

    # Row 3: Interactables / Machines / Decor (0..15)
    # Bed (0), Stove (1), Chest (2), Workbench (3), Furnace (4), Preserve Jar (5), Keg (6), Cheese Press (7)
    c.rect(2, 50, 12, 13, hex_rgba("#8b5a34"))
    c.rect(3, 51, 10, 4, hex_rgba("#f5efe0"))
    c.rect(3, 55, 10, 7, hex_rgba("#4b78a8"))
    # Stove (1)
    c.rect(16 + 2, 50, 12, 13, hex_rgba("#4a4e57"))
    c.circle(16 + 5, 53, 2, hex_rgba("#e87538"))
    c.circle(16 + 10, 53, 2, hex_rgba("#2b2d33"))
    # Chest (2)
    c.rect(32 + 2, 52, 12, 10, hex_rgba("#a86e39"))
    c.rect(32 + 2, 55, 12, 2, hex_rgba("#52361c"))
    c.rect(32 + 7, 55, 2, 3, hex_rgba("#f2cf52"))
    # Workbench (3)
    c.rect(48 + 1, 51, 14, 11, hex_rgba("#9c6b3f"))
    c.rect(48 + 3, 52, 10, 4, hex_rgba("#c9935b"))
    # Furnace (4)
    c.rect(64 + 3, 50, 10, 13, hex_rgba("#5c616b"))
    c.rect(64 + 5, 56, 6, 5, hex_rgba("#f26522"))
    # Preserve Jar (5), Keg (6), Cheese Press (7), Loom (8)
    c.rect(80 + 4, 51, 8, 11, hex_rgba("#9c663b")); c.rect(80 + 3, 50, 10, 2, hex_rgba("#d9a45b"))
    c.rect(96 + 3, 50, 10, 12, hex_rgba("#7a4a24")); c.rect(96 + 3, 54, 10, 2, hex_rgba("#8c949e"))
    c.rect(112 + 3, 51, 10, 11, hex_rgba("#c9a255"))
    c.rect(128 + 2, 50, 12, 12, hex_rgba("#8b5a34")); c.rect(128 + 4, 52, 8, 6, hex_rgba("#e8dfc8"))
    # Sprinklers (9, 10, 11)
    for si, scol in [(9, "#b86b3a"), (10, "#b8c7d4"), (11, "#9c59d1")]:
        ox = si * 16
        c.circle(ox + 8, 56, 4, hex_rgba(scol))
        c.set(ox + 8, 56, hex_rgba("#4db8e8"))
    # Scarecrow (12), Lamp (13), Planter (14), Statue (15)
    c.rect(12 * 16 + 7, 52, 2, 11, hex_rgba("#734a2b"))
    c.rect(12 * 16 + 3, 54, 10, 3, hex_rgba("#547d43"))
    c.circle(12 * 16 + 8, 51, 3, hex_rgba("#e8ab48"))
    c.rect(13 * 16 + 7, 52, 2, 11, hex_rgba("#383d47"))
    c.circle(13 * 16 + 8, 51, 3, hex_rgba("#ffe787"))
    c.rect(14 * 16 + 2, 56, 12, 7, hex_rgba("#8b5a34"))
    c.circle(14 * 16 + 5, 54, 2, hex_rgba("#f07898"))
    c.circle(14 * 16 + 10, 54, 2, hex_rgba("#f5d451"))
    c.rect(15 * 16 + 4, 50, 8, 13, hex_rgba("#76c2ba"))
    c.circle(15 * 16 + 8, 52, 3, hex_rgba("#bdf7f0"))

    c.save(os.path.join(ASSETS_DIR, "tilesets", "world_tileset.png"))


def draw_char_sprite(c: Canvas, ox: int, oy: int, d: int, frame: int, skin, hair, outfit, style_hair=0, style_outfit=0):
    # 16x24 sprite cell. d: 0=down, 1=up, 2=left, 3=right. frame: 0..3
    bob = -1 if frame in (1, 3) else 0
    leg_l = 1 if frame == 1 else (-1 if frame == 3 else 0)
    leg_r = -leg_l

    # Shadow
    c.rect(ox + 4, oy + 21, 8, 2, (0, 0, 0, 75))
    # Legs / boots
    c.rect(ox + 5, oy + 17 + leg_l, 2, 4, OUTLINE)
    c.rect(ox + 9, oy + 17 + leg_r, 2, 4, OUTLINE)
    # Torso / outfit
    c.rect(ox + 4, oy + 11 + bob, 8, 7, outfit)
    c.rect(ox + 3, oy + 11 + bob, 1, 5, shade(outfit, 0.85))
    c.rect(ox + 12, oy + 11 + bob, 1, 5, shade(outfit, 0.85))
    if style_outfit % 2 == 1:
        c.rect(ox + 6, oy + 12 + bob, 4, 4, shade(outfit, 1.25))
    # Hands
    c.rect(ox + 3, oy + 16 + bob, 1, 2, skin)
    c.rect(ox + 12, oy + 16 + bob, 1, 2, skin)
    # Head
    c.rect(ox + 4, oy + 4 + bob, 8, 7, skin)
    c.rect(ox + 3, oy + 5 + bob, 10, 5, skin)
    # Hair
    c.rect(ox + 3, oy + 2 + bob, 10, 3, hair)
    if d == 1:  # Back view
        c.rect(ox + 3, oy + 4 + bob, 10, 6 + (style_hair % 3), hair)
    else:
        c.rect(ox + 3, oy + 4 + bob, 2, 3 + (style_hair % 2), hair)
        c.rect(ox + 11, oy + 4 + bob, 2, 3 + (style_hair % 2), hair)
        if d == 0:
            c.set(ox + 5, oy + 8 + bob, OUTLINE)
            c.set(ox + 10, oy + 8 + bob, OUTLINE)
        elif d == 2:
            c.set(ox + 5, oy + 8 + bob, OUTLINE)
        elif d == 3:
            c.set(ox + 10, oy + 8 + bob, OUTLINE)


def generate_player_sheets():
    pdir = os.path.join(ASSETS_DIR, "sprites", "player")
    # Base sheet: 64 x 96 (4 frames x 4 dirs, neutral white skin so skinColor modulates cleanly)
    base = Canvas(64, 96)
    white_skin = (245, 245, 245, 255)
    for d in range(4):
        for f in range(4):
            draw_char_sprite(base, f * 16, d * 24, d, f, white_skin, (0, 0, 0, 0), (0, 0, 0, 0))
    base.save(os.path.join(pdir, "base.png"))

    # Hair sheet: 256 x 288 (16 cols = dir*4+frame, 12 styles)
    hair_c = Canvas(256, 288)
    hcol = (240, 240, 240, 255)
    hdark = (205, 205, 205, 255)
    for style in range(12):
        for d in range(4):
            for f in range(4):
                ox = (d * 4 + f) * 16
                oy = style * 24
                bob = -1 if f in (1, 3) else 0
                hair_c.rect(ox + 3, oy + 2 + bob, 10, 3, hcol)
                if style % 4 == 1:
                    hair_c.rect(ox + 4, oy + 1 + bob, 8, 2, hdark)
                if d == 1:
                    hair_c.rect(ox + 3, oy + 4 + bob, 10, 5 + (style % 4), hcol)
                else:
                    side_len = 2 + (style % 5)
                    hair_c.rect(ox + 2, oy + 4 + bob, 2, side_len, hdark)
                    hair_c.rect(ox + 12, oy + 4 + bob, 2, side_len, hdark)
    hair_c.save(os.path.join(pdir, "hair.png"))

    # Outfit sheet: 256 x 336 (14 styles)
    out_c = Canvas(256, 336)
    ocol = (240, 240, 240, 255)
    oshade = (195, 195, 195, 255)
    for style in range(14):
        for d in range(4):
            for f in range(4):
                ox = (d * 4 + f) * 16
                oy = style * 24
                bob = -1 if f in (1, 3) else 0
                out_c.rect(ox + 4, oy + 11 + bob, 8, 7, ocol)
                out_c.rect(ox + 3, oy + 11 + bob, 1, 5, oshade)
                out_c.rect(ox + 12, oy + 11 + bob, 1, 5, oshade)
                if style % 3 == 1:
                    out_c.rect(ox + 5, oy + 13 + bob, 6, 4, oshade)
                elif style % 3 == 2:
                    out_c.rect(ox + 4, oy + 16 + bob, 8, 2, oshade)
    out_c.save(os.path.join(pdir, "outfit.png"))

    # Accessory sheet: 256 x 288 (12 styles, 0 = none)
    acc_c = Canvas(256, 288)
    acc_colors = [
        (0, 0, 0, 0), hex_rgba("#e5c158"), hex_rgba("#f07898"), hex_rgba("#5da3c9"),
        hex_rgba("#454a54"), hex_rgba("#c94b4b"), hex_rgba("#529954"), hex_rgba("#f2f4f7"),
        hex_rgba("#e09b3d"), hex_rgba("#d95b7b"), hex_rgba("#6be0c8"), hex_rgba("#a878f5")
    ]
    for style in range(1, 12):
        col = acc_colors[style]
        for d in range(4):
            for f in range(4):
                ox = (d * 4 + f) * 16
                oy = style * 24
                bob = -1 if f in (1, 3) else 0
                if style in (1, 7, 8):  # Hats
                    acc_c.rect(ox + 2, oy + 2 + bob, 12, 2, col)
                    acc_c.rect(ox + 4, oy + 0 + bob, 8, 2, shade(col, 0.85))
                elif style in (2, 11):  # Crown / Circlet
                    acc_c.rect(ox + 4, oy + 2 + bob, 8, 2, col)
                    acc_c.set(ox + 7, oy + 1 + bob, hex_rgba("#fff08a"))
                elif style in (3, 4):  # Glasses / Goggles
                    if d != 1:
                        acc_c.rect(ox + 4, oy + 7 + bob, 3, 2, col)
                        acc_c.rect(ox + 9, oy + 7 + bob, 3, 2, col)
                else:
                    acc_c.rect(ox + 3, oy + 2 + bob, 10, 2, col)
    acc_c.save(os.path.join(pdir, "accessory.png"))


def generate_npcs_and_portraits(npcs):
    for idx, npc in enumerate(npcs):
        nid = npc["id"]
        cols = npc["colors"]
        skin = hex_rgba(cols["skin"])
        hair = hex_rgba(cols["hair"])
        outfit = hex_rgba(cols["outfit"])

        # NPC 64x96 sprite
        sc = Canvas(64, 96)
        for d in range(4):
            for f in range(4):
                draw_char_sprite(sc, f * 16, d * 24, d, f, skin, hair, outfit, idx % 4, idx % 3)
        sc.save(os.path.join(ASSETS_DIR, "sprites", "npc", f"{nid}.png"))

        # Portrait 96x32 (3 expressions: neutral, happy, surprised)
        pc = Canvas(96, 32)
        bg = hex_rgba("#e8d9b5")
        border = hex_rgba("#6e4726")
        for exp in range(3):
            ox = exp * 32
            pc.rect(ox, 0, 32, 32, bg)
            pc.rect(ox, 0, 32, 1, border); pc.rect(ox, 31, 32, 1, border)
            pc.rect(ox, 0, 1, 32, border); pc.rect(ox + 31, 0, 1, 32, border)
            # Shoulders / outfit
            pc.rect(ox + 6, 22, 20, 9, outfit)
            pc.rect(ox + 12, 21, 8, 4, shade(outfit, 1.2))
            # Neck & face
            pc.rect(ox + 13, 19, 6, 4, shade(skin, 0.9))
            pc.circle(ox + 16, 13, 8, skin)
            # Hair
            pc.rect(ox + 8, 4, 16, 5, hair)
            pc.rect(ox + 7, 6, 3, 10 + (idx % 4), hair)
            pc.rect(ox + 22, 6, 3, 10 + (idx % 4), hair)
            # Eyes & mouth
            if exp == 1:  # Happy
                pc.rect(ox + 11, 12, 3, 1, OUTLINE)
                pc.rect(ox + 18, 12, 3, 1, OUTLINE)
                pc.rect(ox + 13, 16, 6, 2, hex_rgba("#d96666"))
            elif exp == 2:  # Surprised
                pc.rect(ox + 12, 11, 2, 3, OUTLINE)
                pc.rect(ox + 18, 11, 2, 3, OUTLINE)
                pc.rect(ox + 15, 16, 2, 3, OUTLINE)
            else:
                pc.rect(ox + 12, 12, 2, 2, OUTLINE)
                pc.rect(ox + 18, 12, 2, 2, OUTLINE)
                pc.rect(ox + 14, 17, 4, 1, shade(skin, 0.65))
        pc.save(os.path.join(ASSETS_DIR, "portraits", f"{nid}.png"))


def generate_crops_atlas(crops):
    # 5 stages x 64 crops = 80 x 1024
    c = Canvas(80, 1024)
    cat_colors = {
        "Vegetables": ["#f2ead3", "#e88a38", "#d64545", "#6bb347", "#9958b8"],
        "Fruits": ["#e6455a", "#4b7be5", "#f092c2", "#f5be3b", "#6e42a8"],
        "Flowers": ["#f25e86", "#f5d742", "#5ba3f0", "#c274e8", "#a8f2eb"],
        "Grains": ["#e5c158", "#d4b468", "#c28f3e", "#d65252"],
        "Mushrooms": ["#d4b898", "#8f6240", "#e6aa3e", "#9452c9", "#69f0e8"],
        "Special": ["#58c7e8", "#a369f2", "#ffd954", "#6b479e", "#fff0a6"],
    }
    for row, crop in enumerate(crops):
        oy = row * 16
        palette = cat_colors.get(crop["category"], ["#7ec850"])
        ripe_col = hex_rgba(palette[row % len(palette)])
        # Stage 0: Seeds in soil
        for sx, sy in [(5, 11), (9, 12), (7, 13)]:
            c.rect(sx, oy + sy, 2, 2, hex_rgba("#d9be82"))
        # Stage 1: Tiny sprout
        c.rect(16 + 7, oy + 10, 2, 4, hex_rgba("#63b346"))
        c.rect(16 + 5, oy + 9, 2, 2, hex_rgba("#82d45b"))
        c.rect(16 + 9, oy + 9, 2, 2, hex_rgba("#82d45b"))
        # Stage 2: Mid leaves
        c.rect(32 + 7, oy + 7, 2, 7, hex_rgba("#4e9636"))
        c.circle(32 + 5, oy + 8, 2, hex_rgba("#76c752"))
        c.circle(32 + 10, oy + 8, 2, hex_rgba("#76c752"))
        # Stage 3: Tall budding plant
        c.rect(48 + 7, oy + 5, 2, 9, hex_rgba("#3e822a"))
        c.circle(48 + 5, oy + 7, 3, hex_rgba("#66b848"))
        c.circle(48 + 10, oy + 7, 3, hex_rgba("#66b848"))
        c.rect(48 + 7, oy + 4, 2, 2, shade(ripe_col, 0.9))
        # Stage 4: Mature harvestable crop
        ox = 64
        c.rect(ox + 7, oy + 7, 2, 7, hex_rgba("#468c32"))
        c.circle(ox + 4, oy + 10, 2, hex_rgba("#6bc24c"))
        c.circle(ox + 11, oy + 10, 2, hex_rgba("#6bc24c"))
        c.circle(ox + 8, oy + 6, 4, OUTLINE)
        c.circle(ox + 8, oy + 6, 3, ripe_col)
        c.set(ox + 7, oy + 5, shade(ripe_col, 1.3))
    c.save(os.path.join(ASSETS_DIR, "sprites", "crops", "crops_atlas.png"))


def generate_items_atlas(items):
    cols = 22
    rows = (len(items) + cols - 1) // cols
    c = Canvas(cols * 16, rows * 16)
    cat_palettes = {
        "Seeds": "#d9b468",
        "Crops": "#6ec248",
        "Fish": "#4ea1d6",
        "Tools": "#99a6b5",
        "Forage": "#78b856",
        "Minerals": "#66c2cf",
        "Materials": "#b8824c",
        "Food": "#e39b4f",
        "Furniture": "#9c6b3f",
        "Decorations": "#d4849c",
        "Quest Items": "#f0c948",
        "Special Items": "#a66be8",
    }
    for item in items:
        idx = item["atlasIndex"]
        ox = (idx % cols) * 16
        oy = (idx // cols) * 16
        cat = item["category"]
        # Deterministic hue variation per item id
        h = sum(ord(ch) * (i + 1) for i, ch in enumerate(item["id"]))
        base = hex_rgba(cat_palettes.get(cat, "#cccccc"))
        r = max(40, min(250, (base[0] + (h % 70) - 35)))
        g = max(40, min(250, (base[1] + ((h >> 3) % 70) - 35)))
        b = max(40, min(250, (base[2] + ((h >> 6) % 70) - 35)))
        col = (r, g, b, 255)

        if cat == "Seeds":
            c.rect(ox + 3, oy + 3, 10, 11, OUTLINE)
            c.rect(ox + 4, oy + 4, 8, 9, hex_rgba("#e8d29e"))
            c.rect(ox + 5, oy + 6, 6, 5, col)
        elif cat == "Fish":
            c.circle(ox + 8, oy + 8, 4, OUTLINE)
            c.circle(ox + 8, oy + 8, 3, col)
            c.rect(ox + 11, oy + 6, 3, 4, shade(col, 0.85))
            c.set(ox + 6, oy + 7, (255, 255, 255, 255))
        elif cat == "Tools":
            c.rect(ox + 3, oy + 10, 8, 2, hex_rgba("#8b5a34"))
            c.rect(ox + 9, oy + 3, 4, 6, OUTLINE)
            c.rect(ox + 10, oy + 4, 3, 4, col)
        elif cat == "Food":
            c.circle(ox + 8, oy + 9, 5, hex_rgba("#f0ece0"))
            c.circle(ox + 8, oy + 8, 3, col)
            c.set(ox + 7, oy + 4, (255, 255, 255, 190))
        elif cat == "Minerals":
            c.rect(ox + 5, oy + 3, 6, 10, OUTLINE)
            c.rect(ox + 6, oy + 4, 4, 8, col)
            c.rect(ox + 7, oy + 5, 2, 3, shade(col, 1.35))
        elif cat in ("Furniture", "Decorations"):
            c.rect(ox + 3, oy + 4, 10, 9, OUTLINE)
            c.rect(ox + 4, oy + 5, 8, 7, col)
            c.rect(ox + 5, oy + 6, 6, 2, shade(col, 1.2))
        else:
            c.circle(ox + 8, oy + 8, 5, OUTLINE)
            c.circle(ox + 8, oy + 8, 4, col)
            c.rect(ox + 6, oy + 6, 2, 2, shade(col, 1.3))
    c.save(os.path.join(ASSETS_DIR, "sprites", "items", "items_atlas.png"))


def generate_animals_and_monsters(animals, monsters):
    # Animals: 4 frames x 12 rows of 16x16 = 64 x 192
    ac = Canvas(64, 192)
    a_cols = [
        "#f7f4e8", "#c97a42", "#639675", "#9c7b5a",
        "#e6d8cc", "#f2f0eb", "#d9c2a3", "#f7f5f0",
        "#e0b892", "#e89cb0", "#f2c641", "#a3e0eb"
    ]
    for row, _ in enumerate(animals):
        col = hex_rgba(a_cols[row % len(a_cols)])
        for f in range(4):
            ox = f * 16
            oy = row * 16 + (-1 if f % 2 == 1 else 0)
            ac.circle(ox + 8, oy + 9, 4, OUTLINE)
            ac.circle(ox + 8, oy + 9, 3, col)
            ac.rect(ox + 10, oy + 6, 3, 3, col)
            ac.set(ox + 12, oy + 7, OUTLINE)
            ac.rect(ox + 6, oy + 13, 1, 2, OUTLINE)
            ac.rect(ox + 9, oy + 13, 1, 2, OUTLINE)
    ac.save(os.path.join(ASSETS_DIR, "sprites", "animals", "animals_atlas.png"))

    # Monsters: 4 frames x 10 rows of 24x24 = 96 x 240
    mc = Canvas(96, 240)
    for row, mon in enumerate(monsters):
        col = hex_rgba(mon["color"])
        r_size = 9 if mon["boss"] else 6
        for f in range(4):
            ox = f * 24
            oy = row * 24 + (-1 if f in (1, 3) else 0)
            mc.circle(ox + 12, oy + 13, r_size + 1, OUTLINE)
            mc.circle(ox + 12, oy + 13, r_size, col)
            mc.rect(ox + 8, oy + 10, 2, 2, (255, 70, 70, 255))
            mc.rect(ox + 14, oy + 10, 2, 2, (255, 70, 70, 255))
            if mon["boss"]:
                mc.rect(ox + 8, oy + 3, 8, 3, hex_rgba("#ffd954"))
    mc.save(os.path.join(ASSETS_DIR, "sprites", "monsters", "monsters_atlas.png"))


def generate_buildings_and_ui():
    # Buildings atlas: 8 cols x 4 rows of 48x48 = 384 x 192
    bc = Canvas(384, 192)
    roof_cols = ["#b54d3c", "#4b75a3", "#599452", "#9c6d3e", "#74529c", "#3e8c8c"]
    for i in range(32):
        ox = (i % 8) * 48
        oy = (i // 8) * 48
        rc = hex_rgba(roof_cols[i % len(roof_cols)])
        if i < 9:  # Full large buildings
            bc.rect(ox + 4, oy + 18, 40, 26, OUTLINE)
            bc.rect(ox + 5, oy + 19, 38, 24, hex_rgba("#e6d2aa"))
            bc.rect(ox + 2, oy + 6, 44, 15, OUTLINE)
            bc.rect(ox + 3, oy + 7, 42, 13, rc)
            bc.rect(ox + 19, oy + 28, 10, 15, hex_rgba("#6e4726"))
            bc.rect(ox + 9, oy + 24, 7, 7, hex_rgba("#87cef5"))
            bc.rect(ox + 32, oy + 24, 7, 7, hex_rgba("#87cef5"))
        else:  # Machines / Furniture / Decor centered nicely
            bc.rect(ox + 14, oy + 14, 20, 24, OUTLINE)
            bc.rect(ox + 15, oy + 15, 18, 22, rc)
            bc.rect(ox + 18, oy + 18, 12, 8, shade(rc, 1.25))
    bc.save(os.path.join(ASSETS_DIR, "sprites", "buildings", "buildings_atlas.png"))

    # UI icons: 16 cols x 2 rows of 16x16 = 256 x 32
    uc = Canvas(256, 32)
    icon_defs = [
        (0, "#ffd954"), (1, "#b8c7d9"), (2, "#5ba3e0"), (3, "#6b509c"),
        (4, "#e6f5ff"), (5, "#c2ccd6"), (6, "#76c752"), (7, "#f59e42"),
        (8, "#cf5c36"), (9, "#96d4f0"), (10, "#e04a5a"), (11, "#523238"),
        (12, "#f5cf42"), (13, "#8ce052"), (14, "#94a3b8"), (15, "#d4844a")
    ]
    for idx, ch in icon_defs:
        ox = idx * 16
        uc.circle(ox + 8, 8, 6, OUTLINE)
        uc.circle(ox + 8, 8, 5, hex_rgba(ch))
    uc.save(os.path.join(ASSETS_DIR, "ui", "ui_icons.png"))


def write_wav(path: str, samples, sample_rate: int = 22050):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        frames = bytearray()
        for s in samples:
            val = max(-32767, min(32767, int(s * 32767)))
            frames.extend(struct.pack("<h", val))
        wf.writeframes(bytes(frames))


def synth_melody(notes_hz, beat_sec: float, sr: int = 22050, amp: float = 0.22):
    out = []
    for hz in notes_hz:
        n = int(sr * beat_sec)
        for i in range(n):
            t = i / sr
            env = min(1.0, i / (sr * 0.03)) * min(1.0, (n - i) / (sr * 0.06))
            if hz <= 0:
                out.append(0.0)
            else:
                v = math.sin(2 * math.pi * hz * t) * 0.7 + math.sin(4 * math.pi * hz * t) * 0.2
                out.append(v * amp * env)
    return out


def generate_audio():
    # Music loops (cozy pentatonic & modal themes, ~4-6s clean loops)
    music_specs = {
        "main_theme": ([261.6, 329.6, 392.0, 523.3, 440.0, 392.0, 329.6, 293.7], 0.45),
        "spring": ([293.7, 349.2, 440.0, 523.3, 440.0, 392.0, 349.2, 329.6], 0.45),
        "summer": ([329.6, 392.0, 493.9, 587.3, 523.3, 440.0, 392.0, 329.6], 0.42),
        "autumn": ([246.9, 293.7, 370.0, 440.0, 392.0, 329.6, 293.7, 246.9], 0.5),
        "winter": ([220.0, 261.6, 329.6, 392.0, 329.6, 293.7, 261.6, 220.0], 0.55),
        "mine": ([164.8, 196.0, 220.0, 196.0, 146.8, 164.8, 196.0, 130.8], 0.5),
        "festival": ([392.0, 440.0, 523.3, 587.3, 659.3, 587.3, 523.3, 440.0], 0.32),
    }
    for name, (notes, beat) in music_specs.items():
        write_wav(os.path.join(ASSETS_DIR, "audio", "music", f"{name}.wav"), synth_melody(notes, beat))

    # Ambient loops (gentle filtered noise / soft pads, 3s)
    rng = random.Random(101)
    sr = 22050
    for amb_name, freq, noise_amt in [
        ("forest", 220.0, 0.04),
        ("village", 261.6, 0.03),
        ("rain", 0.0, 0.09),
        ("thunder", 82.0, 0.14),
        ("ocean", 110.0, 0.08),
        ("animals", 330.0, 0.04),
    ]:
        n = sr * 3
        samples = []
        last = 0.0
        for i in range(n):
            t = i / sr
            lfo = 0.5 + 0.5 * math.sin(2 * math.pi * 0.4 * t)
            wn = (rng.random() * 2 - 1) * noise_amt
            last = last * 0.85 + wn * 0.15
            tone = math.sin(2 * math.pi * freq * t) * 0.05 if freq > 0 else 0.0
            samples.append((last + tone) * lfo)
        write_wav(os.path.join(ASSETS_DIR, "audio", "ambient", f"{amb_name}.wav"), samples)

    # Crisp SFX
    sfx_specs = {
        "ui_click": (660, 880, 0.07),
        "hoe": (180, 110, 0.12),
        "water": (440, 620, 0.18),
        "seed": (520, 700, 0.10),
        "harvest": (580, 920, 0.14),
        "axe": (160, 95, 0.15),
        "pickaxe": (780, 420, 0.14),
        "scythe": (900, 320, 0.11),
        "fish_cast": (320, 680, 0.22),
        "fish_bite": (880, 1040, 0.18),
        "fish_catch": (523, 1046, 0.30),
        "sword": (420, 220, 0.12),
        "hit": (190, 90, 0.14),
        "coin": (988, 1318, 0.16),
        "level_up": (440, 880, 0.40),
        "sleep": (392, 261, 0.45),
    }
    for sname, (f0, f1, dur) in sfx_specs.items():
        n = int(sr * dur)
        samples = []
        for i in range(n):
            p = i / max(1, n - 1)
            hz = f0 + (f1 - f0) * p
            env = 1.0 - p
            samples.append(math.sin(2 * math.pi * hz * (i / sr)) * 0.35 * env)
        write_wav(os.path.join(ASSETS_DIR, "audio", "sfx", f"{sname}.wav"), samples)


def main():
    with open(os.path.join(DATA_DIR, "items.json"), "r", encoding="utf-8") as f:
        items = json.load(f)
    with open(os.path.join(DATA_DIR, "crops.json"), "r", encoding="utf-8") as f:
        crops = json.load(f)
    with open(os.path.join(DATA_DIR, "npcs.json"), "r", encoding="utf-8") as f:
        npcs = json.load(f)
    with open(os.path.join(DATA_DIR, "animals.json"), "r", encoding="utf-8") as f:
        animals = json.load(f)
    with open(os.path.join(DATA_DIR, "monsters.json"), "r", encoding="utf-8") as f:
        monsters = json.load(f)

    generate_tileset()
    generate_player_sheets()
    generate_npcs_and_portraits(npcs)
    generate_crops_atlas(crops)
    generate_items_atlas(items)
    generate_animals_and_monsters(animals, monsters)
    generate_buildings_and_ui()
    generate_audio()
    print("Generated all Pixel Art PNGs and WAV audio files cleanly!")


if __name__ == "__main__":
    main()
