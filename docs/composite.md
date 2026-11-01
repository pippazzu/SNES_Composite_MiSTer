# Composite video: technical notes

## Multi-chip SNES composite output (BA6592F)

Sources: the OpenSFC SHVC-CPU-01 Rev A KiCad netlist (read from `SHVC-CPU-01.kicad_pcb`), Jonathon W. Donaldson's SNES schematic, the ROHM BA6592F/BA6592FS data sheet (15 pages), Fullsnes for the S-PPU2 pins. The PPU2's RGB edges come from Chris Covell's oscilloscope captures of a multi-chip SFC/SNES at the multi-out, with Mike Moffitt's and Torapu's traces as cross-checks. No console has been measured for this core yet; every figure below comes from these documents and Covell's captures.

1. **The PPU2** outputs analog R, G and B from its DAC, horizontal and vertical sync, and a BURST flag that drives both the BA6592F's clamp (pin 3) and burst (pin 16) inputs (netlist). Its RGB edges do not settle at one speed: on Covell's captures a black-to-white step rises 10–90% in about 119 ns, black-to-grey in about 305 ns. These figures were read off screenshots, include the board's output buffers and the probe, and come from one console. There is no RGB filtering on the board: R, G and B pass through PNP emitter followers and a 300 Ω / 120 Ω network into 1 µF at the encoder inputs, with only 47 pF at the multi-out pins. The burst flag's position on the line has not been measured.
2. **The BA6592F encoder** turns RGB into luma and chroma (data sheet): about 0.42 V of R−Y and 0.31 V of B−Y for a 0.7 V primary, modulator gains of 10.5 dB (R−Y) and 11 dB (B−Y), a 0.46 Vp-p burst, 1.4 V white and −0.55 V sync at YO, a YI-to-VO gain of 1.5/0.7. The data sheet gives white and primary levels but not its three luma coefficients. VO is an NPN emitter follower with a 6.0 kΩ pull-down (data sheet p.8).
3. **The board's filters** (netlist):
   * colour difference: R37 270 Ω / C15 220 pF (R−Y) and R35 270 Ω / C13 220 pF (B−Y) between the encoder's outputs and inputs.
   * luma and composite buffers: 470 Ω series, 10 kΩ and 10 pF shunt (R38/R39/C17 into Q11, R30/R31/C12 into Q10).
   * luma feedback: taken at Q11's emitter, halved by R40/R41 (39 Ω / 39 Ω) through C18 into YI.
   * the composite jack: R33 56 Ω into the TV's 75 Ω, behind back-to-back C57/C58 100 µF.
4. **C21 (51 pF) on the VO pin**: VO can charge C21 freely, but only the 6.0 kΩ pull-down in parallel with R30 + R31 (3.81 kΩ in all) discharges it, so falling edges slew at about 10 V/µs (τ = 194 ns). Fully saturated chroma needs about that much, so the falling half of strong colours is slowed. This follows from the data sheet and netlist; it has not been seen on a scope.

## How it is implemented

1. **PPU2 pins**: the core's RGB, sync (dots 296 to 318) and a burst gate from the PPU's dot counter (dots 327 to 1, 15 dots including the first long dot), at the 42.95454 MHz video clock, 12 samples per subcarrier cycle. The subcarrier runs continuously, and the PPU's short line is kept. Composite sync follows horizontal sync, inverted during vertical sync; the burst is off during vertical sync.
2. **PPU2 RGB edges**: one one-pole filter per channel whose time constant depends on the level it is heading to: τ = 55 + 340·x·(1−x) ns, x the target level from 0 to 1. That gives about 121 ns and 308 ns for the two steps in item 1. A 32-entry table holds the exact zero-order-hold coefficients. Black to white and black to grey are fitted; the shape between them, rise against fall, and the three channels being equal are assumed. The same filter feeds RGB out (option Multi-chip) and the encoder. Full scale at the encoder input is taken as 0.7 V; the 300/120 network has not been tied to this.
3. **Encoder**: the data sheet's typical values. The luma matrix is the conventional 0.299 / 0.587 / 0.114. Modulation is an ideal sine at the fundamental. Pin voltages are signed Q3.16, relative to the clamped black level.
4. **Board filters**: the colour-difference loops and both buffers solved as exact zero-order-hold filters at 42.95454 MHz, with ideal emitter followers and ideal coupling capacitors. The C21 discharge (item 4 above) is the VO pin following rising edges and decaying on falling ones by 0.8867 a sample (exact: 0.8872), assuming the typical 2.0 V VO level at black. This adds one sample, so the picture timing is delayed by 27 samples to stay in line with the decoded picture.
5. **Composite filters**: Kitrinx's composite decoder from the NES core, run at 12 samples per subcarrier cycle, with the changes listed below. Its contrast input is fixed at 2604 (a 0.78 V white at the jack into 75 Ω); Comp. Brightness gives it the same black offsets as the Mega Drive core. The decoded picture is taken every second sample: 21.48 MHz, four per lores pixel and two per hires pixel, so the scaler has six samples per subcarrier cycle to draw it with (one in four, as the Multi-chip RGB output still is, left it three). The pixels taken before are among them.
6. **Gamma**: the decoded pixels come every two clocks, too fast for the gamma block inside `video_mixer`, which looks R, G and B up one after another and needs four clocks per pixel. The core uses the framework's `gamma_fast` instead, on every path, which looks the three up at once from the same curve with the same one-pixel delay.

Not implemented: PAL, S-video, the 1-CHIP console, DAC ringing and code-dependent glitches, carrier leakage, the external carrier phase network. Light gun mode uses the core's own RGB.

In simulation (Icarus Verilog) the core passes the PPU2 step and DC checks, the encoder level checks, a three-frame composite run, and all 16 NTSC mode and preset cases (224/239 lines, 448/478 interlaced, hires and pseudo-hires). Brightness and sharpness change pixels but not timing. These runs use synthetic PPU pin patterns, not games. `test-roms/smear-test` holds a ROM with Covell's colour-smear screens.

## Changes to Kitrinx's composite decoder

The decoder is Kitrinx's from the NES core (MIT licence; the changes are MIT too), in `rtl/composite/composite_decoder.sv`. It starts from the Mega Drive core's version and differs from it as noted.

* **Burst gate and black clamp** are timed from the trailing edge of sync, as a set's burst gate pulse is, instead of from the leading edge. The SNES core sets them 2.1 and 4.9 µs after the trailing edge (the Mega Drive core: 1.3 and 3.8). The PPU's sync is 23 dots (about 4.3 µs) and its burst flag starts about 1.5 µs after sync ends and lasts about 2.8 µs, so the Mega Drive's burst gate would catch the burst's leading edge and its black clamp would land inside the burst.
* **Chroma is blanked** until the back porch is over, as a set blanks it through horizontal blanking, so the long burst is never shown.
* **Premium TV comb** uses a set's fixed 227.5-cycle delay instead of one line of the source. An SNES line is not 227.5 cycles, so a delay of one source line would not meet chroma in antiphase.
* **Sync separator** slices the signal averaged over one subcarrier cycle, as a set's does through its low-pass, instead of the raw signal, so saturated colours that swing down to the sync tip are not counted as line starts. Unlike the Mega Drive version, the average's delay is not taken back out; the gates above include it.
* **Horizontal flywheel**: the inverted sync during vertical sync can leave out a leading edge. The line counter then restarts on its own after one line period, as a set's horizontal oscillator runs on, and it learns the period only from lines close to normal length.
* **Comb line store** is exactly one comb delay long (2,730 16-bit samples in six M10K blocks), wrapping explicitly, instead of a power-of-two buffer.
* Not changing the picture: the sharpness filter's tap spacing is a parameter, two products are folded into one each (same results), the comb's line store is a RAM inside the decoder rather than the core's dpram, and an odd sample count per cycle is supported (not used here).

With a 4.7 µs sync and standard NTSC timing, the decoder gives the same picture as the original, apart from these later gates and the sync average's delay of about 0.13 µs.

## Build

Quartus 17.0.2 Lite, seed 2. Logic 35,551 ALMs (85%), DSP blocks 110/112, RAM blocks 530/553 (96%). Worst setup slack is +0.046 ns and hold slack +0.246 ns at the slow 100 °C corner the MiSTer flow signs off on, so timing passes. Removing the scandoubler, HQ2x and the core's scanline effects frees 25 memory blocks.
