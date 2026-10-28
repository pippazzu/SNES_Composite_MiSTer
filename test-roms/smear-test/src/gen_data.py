#!/usr/bin/env python3
"""Generate tiles, tilemaps and palettes for the colour smear test ROM.

Recreates the test screens from Chris Covell's "Super Famicom / SNES Model 1
Blurry RGB" page (chrismcovell.com/gotRGB/snesblur.html):

  page 1  coloured text: red on orange, orange on red, cyan-tinged blue on
          purple, blue on yellow, yellow on blue
  page 2  an 8-pixel-wide bar on a solid background, every pairing of white,
          grey and black, as an overview
  3-8     the same bars one per page, full screen, as Covell used them for
          his oscilloscope captures

Output: data.bin (included by smeartest.s).
"""
import struct
import sys

# ---------------------------------------------------------------- colours
def rgb(r, g, b):
    """5-bit components -> SNES BGR555."""
    return r | (g << 5) | (b << 10)

def rgb8(r, g, b):
    return rgb(round(r * 31 / 255), round(g * 31 / 255), round(b * 31 / 255))

BLACK = rgb(0, 0, 0)
WHITE = rgb(31, 31, 31)
GREY = rgb(16, 16, 16)            # "medium grey": half-scale on every channel
TITLE = rgb(31, 31, 31)
DIM = rgb(14, 14, 14)

ORANGE = rgb8(246, 128, 44)       # sampled from Covell's BITMAP column
RED = rgb8(244, 29, 34)
PURPLE = rgb(16, 0, 16)           # "both red & blue at medium levels"
CYANBLUE = rgb(0, 16, 31)         # "cyan-tinged blue": G mid, B full, R off
YELLOW = rgb(31, 31, 0)
BLUE = rgb(0, 0, 31)

# ---------------------------------------------------------------- font
# 5x7 glyphs, emboldened by OR-ing each row with itself shifted one pixel
# right. That gives 2-pixel vertical strokes and 1-pixel horizontal strokes,
# the chunky look of the text in Covell's bitmaps.
GLYPHS = {
    'A': ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    'B': ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    'C': ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    'D': ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    'E': ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    'F': ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    'G': ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    'H': ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    'I': ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    'J': ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    'K': ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    'L': ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    'M': ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    'N': ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
    'O': ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    'P': ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    'Q': ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    'R': ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    'S': ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    'T': ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    'U': ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    'V': ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    'W': ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    'X': ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    'Y': ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    'Z': ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    '0': ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    '1': ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    '2': ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    '3': ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
    '4': ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    '5': ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    '6': ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    '7': ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    '8': ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    '9': ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    '/': ["00001", "00001", "00010", "00100", "01000", "10000", "10000"],
    ':': ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
    '-': ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    '.': ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    '(': ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
    ')': ["01000", "00100", "00010", "00010", "00010", "00100", "01000"],
}

# Tile numbers. Pixel value 1 = background colour, 2 = foreground colour.
T_EMPTY = 0          # colour 0 (backdrop, black)
T_BG = 1             # solid colour 1
T_FG = 2             # solid colour 2
FONT_BASE = 3
CHARS = sorted(GLYPHS)
CHAR_TILE = {c: FONT_BASE + i for i, c in enumerate(CHARS)}
CHAR_TILE[' '] = T_BG


def tile_4bpp(pixels):
    """8x8 list of colour indices -> 32 bytes of SNES 4bpp planar data."""
    out = bytearray(32)
    for y in range(8):
        for x in range(8):
            v = pixels[y][x]
            bit = 7 - x
            for p in range(4):
                if v >> p & 1:
                    off = (p >> 1) * 16 + y * 2 + (p & 1)
                    out[off] |= 1 << bit
    return bytes(out)


def glyph_pixels(rows):
    pix = [[1] * 8 for _ in range(8)]
    for y, r in enumerate(rows):
        bits = int(r, 2)
        # 6 columns after emboldening; the glyph sits in x=1..6
        wide = (bits << 1) | bits
        for x in range(6):
            if wide >> (5 - x) & 1:
                pix[y][1 + x] = 2
    return pix


def build_chr():
    tiles = [
        [[0] * 8 for _ in range(8)],
        [[1] * 8 for _ in range(8)],
        [[2] * 8 for _ in range(8)],
    ]
    for c in CHARS:
        tiles.append(glyph_pixels(GLYPHS[c]))
    return b"".join(tile_4bpp(t) for t in tiles)


# ---------------------------------------------------------------- screens
class Screen:
    def __init__(self):
        self.map = [[0] * 32 for _ in range(32)]   # tile | pal<<10

    def put(self, col, row, tile, pal):
        self.map[row][col] = tile | (pal << 10)

    def text(self, col, row, s, pal):
        for i, ch in enumerate(s):
            self.put(col + i, row, CHAR_TILE[ch], pal)

    def ctext(self, row, s, pal):
        self.text((32 - len(s)) // 2, row, s, pal)

    def fill(self, col, row, w, h, tile, pal):
        for y in range(row, row + h):
            for x in range(col, col + w):
                self.put(x, y, tile, pal)

    def panel(self, row, s, pal, margin=1):
        """Covell-style text panel: solid box 3 tiles tall, text in the middle row."""
        w = len(s) + 2 * margin
        col = (32 - w) // 2
        self.fill(col, row, w, 3, T_BG, pal)
        self.text(col + margin, row + 1, s, pal)

    def data(self):
        return b"".join(struct.pack("<H", v) for r in self.map for v in r)


def palettes(entries):
    """entries: list of (bg, fg) per palette 0..7 -> 256 bytes (16 colours each)."""
    out = bytearray()
    for i in range(8):
        bg, fg = entries[i] if i < len(entries) else (BLACK, BLACK)
        cols = [BLACK, bg, fg] + [BLACK] * 13
        out += b"".join(struct.pack("<H", c) for c in cols)
    return bytes(out)


def page_text():
    s = Screen()
    s.ctext(1, "COLOUR TEXT SMEAR TEST", 0)
    s.panel(3, "RED TEXT", 1)          # red -> orange: right edges smear
    s.panel(7, "ORANGE", 2)            # red bg bleeds into left of orange text
    s.panel(11, "CYAN TEXT", 3)        # purple <-> cyan-blue: both edges smear
    s.panel(15, "BLUE TEXT", 4)        # primaries: should stay sharp
    s.panel(19, "YELLOW", 5)
    s.ctext(24, "PAGE 1/%d   L R: PAGE" % NUM_PAGES, 6)
    pal = palettes([
        (BLACK, TITLE),
        (ORANGE, RED),
        (RED, ORANGE),
        (PURPLE, CYANBLUE),
        (YELLOW, BLUE),
        (BLUE, YELLOW),
        (BLACK, DIM),
    ])
    return s.data(), pal


BAR_COL = 15            # 8-pixel bar at x = 120..127
BAR_COMBOS = [
    ("WHITE BAR ON BLACK", BLACK, WHITE),
    ("BLACK BAR ON WHITE", WHITE, BLACK),
    ("GREY BAR ON BLACK", BLACK, GREY),
    ("BLACK BAR ON GREY", GREY, BLACK),
    ("WHITE BAR ON GREY", GREY, WHITE),
    ("GREY BAR ON WHITE", WHITE, GREY),
]
NUM_PAGES = 2 + len(BAR_COMBOS)


def page_bars():
    s = Screen()
    s.ctext(1, "8 PIXEL BAR TEST", 0)
    pals = [(BLACK, TITLE)]
    for i, (label, bg, fg) in enumerate(BAR_COMBOS):
        row = 3 + i * 4
        p = i + 1
        s.ctext(row, label, 0)
        s.fill(0, row + 1, 32, 2, T_BG, p)
        s.fill(BAR_COL, row + 1, 1, 2, T_FG, p)
        pals.append((bg, fg))
    s.ctext(27, "PAGE 2/%d" % NUM_PAGES, 7)
    pals.append((BLACK, DIM))
    return s.data(), palettes(pals)


def page_bar_full(n, label, bg, fg):
    """One bar, full screen, label on a black strip at the bottom."""
    s = Screen()
    s.fill(0, 0, 32, 25, T_BG, 1)
    s.fill(BAR_COL, 0, 1, 25, T_FG, 1)
    s.ctext(26, "%s  %d/%d" % (label, n, NUM_PAGES), 0)
    return s.data(), palettes([(BLACK, DIM), (bg, fg)])


def main(out):
    chr_data = build_chr()
    assert len(chr_data) <= 0x2000
    chr_data = chr_data.ljust(0x2000, b"\0")
    pages = [page_text(), page_bars()]
    for i, combo in enumerate(BAR_COMBOS):
        pages.append(page_bar_full(3 + i, *combo))
    assert len(pages) == NUM_PAGES
    with open(out, "wb") as f:
        # layout must match smeartest.s: 8 KB tiles, then per page a 2 KB
        # tilemap followed by a 256-byte palette ($900 bytes per page)
        f.write(chr_data)
        for m, p in pages:
            f.write(m)
            f.write(p)
    with open("pages.inc", "w") as f:
        f.write("NUM_PAGES = %d\n" % NUM_PAGES)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "data.bin")
