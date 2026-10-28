# [Super Nintendo Entertainment System](https://en.wikipedia.org/wiki/Super_Nintendo_Entertainment_System) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki), with composite video

Written by [srg320](https://github.com/srg320)

This fork adds the console's composite video: the picture an early (multi-chip) NTSC SNES sends through its AV cable, decoded with Kitrinx's composite filters. It also adds the soft RGB edges of the multi-chip console's PPU2. See [Composite video](#composite-video).

## Features
* Cycle accurate SNES replica.
* Supports LoROM, HiROM, ExHiROM.
* Supports additional chips: DSP-1/2/3/4, ST010, CX4, SDD1, SuperFX(GSU-1/2), SA1, OBC1, SPC7110, S-RTC, BSX, Sufami Turbo.
* MSU-1 Support (1GB max).
* Save states support incl chips SA1, DSP and SuperFX.
* Cheat engine.
* Save/Load Backup RAM.
* Supports mouse.
* Light gun support via Wiimote, mouse or analog stick.
* [SuperFX Turbo and CPU Turbo.](https://github.com/MiSTer-devel/SNES_MiSTer/blob/master/SNES_Turbo.md)
* Composite video (see below).

## Installation
* Copy \*.rbf to root of SD card. Put some ROMs (\*.SFC, \*.SMC, \*.BIN) into games\SNES folder.
* Save states: Place [boot1.rom](https://github.com/MiSTer-devel/SNES_MiSTer/raw/master/releases/boot1.rom) in games\SNES folder.
* BSX: Place bsx_bios.rom in games\SNES folder.

## Composite video

Based on Kitrinx's NES core implementation. Not yet measured against a console with an oscilloscope. ROHM BA6592F encoder from its data sheet, the SHVC-CPU-01 board filters from the OpenSFC netlist and Donaldson's schematic, decoded with Kitrinx's composite filters. The PPU2's RGB edges are fitted to Chris Covell's oscilloscope captures of a multi-chip console: edges toward middle brightness settle more slowly than edges toward black or full brightness. Runs in step with the video signal, adding under a microsecond of delay. Technical notes: [docs/composite.md](docs/composite.md).

Options, in **Audio & Video**:

* **PPU2 RGB**: Multi-chip (the softer edges of the multi-chip PPU2, used by RGB out and by composite) / Original core (the core's clean RGB).
* **Composite (NTSC)**: Off / Budget TV (notch filter, softer colour) / Premium TV (comb filter, sharper colour).
* **Comp. Brightness**: Japan (the console's own black) / USA (a US set: the darkest shades crush to black) / More / Much More / Too Much.
* **Comp. Sharpness**: Off / Low / Medium / High (the TV's sharpness knob).

Composite is NTSC only: on PAL the output follows the PPU2 RGB option, and light gun mode uses the core's clean RGB. Force 256px is greyed out while Multi-chip or composite is on.

This core is for 15 kHz RGB CRTs and HDMI. The scandoubler, HQ2x and the core's scanline effects are removed, and so is Pseudo Transparency/Blend (the composite path does that blending itself). The HDMI scaler's adaptive scanlines still work. For 31 kHz VGA, use the main core, or MiSTer's `vga_scaler=1`.
