# Colour smear test ROM

`smeartest.sfc` recreates the test screens from Chris Covell's
[Super Famicom / SNES Model 1 Blurry RGB](https://www.chrismcovell.com/gotRGB/snesblur.html) page.
32 KB LoROM, NTSC header. Runs on real hardware and the MiSTer SNES core.

Controls: R, A or Right goes to the next page. L, B or Left goes back.

| Page | Content | What smears on an old SFC/SNES |
| --- | --- | --- |
| 1 | RED TEXT on orange, ORANGE on red, CYAN TEXT on purple, BLUE TEXT on yellow, YELLOW on blue | Red text gets fat right edges, orange text gets thin left edges, cyan text smears on both sides, blue/yellow (primaries) stay sharp |
| 2 | Overview: 8-pixel bar on every pairing of white, grey and black | Edges going to grey are slow |
| 3–8 | The same six bars, one per page, full screen | Same, for a scope or close-up photos |

Colours (5-bit per channel): orange and red are sampled from Covell's bitmap
(246,128,44 → 30,16,5 and 244,29,34 → 30,4,4). His bitmaps for the purple
and blue/yellow panels could not be downloaded, so those follow his
description: purple = R 16, B 16; "cyan-tinged blue" = G 16, B 31;
yellow = 31,31,0; blue = 0,0,31; grey = 16,16,16. The text in those three
panels is my choice. The bar is at x = 120–127.

`pages-preview.png` shows all eight pages from mednafen.

## Rebuild

Needs cc65 (`ca65`, `ld65`) and Python 3: `sh src/build.sh` (writes `src/smeartest.sfc`).
