; Colour smear test ROM
; Recreates the test screens of Chris Covell's "Super Famicom / SNES Model 1
; Blurry RGB" page. R, A or Right goes to the next page; L, B or Left goes
; back.
; Build: see build.sh. Tile, map and palette data come from gen_data.py.

.p816
.smart -

INIDISP = $2100
BGMODE  = $2105
BG1SC   = $2107
BG12NBA = $210B
BG1HOFS = $210D
BG1VOFS = $210E
VMAIN   = $2115
VMADDL  = $2116
CGADD   = $2121
TM      = $212C
NMITIMEN = $4200
MDMAEN  = $420B
HVBJOY  = $4212
JOY1L   = $4218
DMAP0   = $4300
BBAD0   = $4301
A1T0L   = $4302
A1B0    = $4304
DAS0L   = $4305

MAP_VRAM = $1000            ; word address of the BG1 tilemap

.zeropage
page:     .res 1
pad_old:  .res 2
pad_new:  .res 2

.include "pages.inc"         ; NUM_PAGES, written by gen_data.py

.segment "RODATA"
data:     .incbin "data.bin"
CHR      = data
PAGES    = data + $2000     ; per page: 2 KB tilemap, then 256 B palette

page_addr:
.repeat NUM_PAGES, i
    .word .loword(PAGES + i * $900)
.endrepeat

.segment "CODE"

; DMA from bank 0 to a B-bus register.  X = source, Y = length,
; A (8-bit) = B-bus register low byte, mode in dmap.
.macro dma_to bbad, mode, src, len
    lda #mode
    sta DMAP0
    lda #<bbad
    sta BBAD0
    ldx #.loword(src)
    stx A1T0L
    stz A1B0
    ldx #len
    stx DAS0L
    lda #$01
    sta MDMAEN
.endmacro

reset:
    sei
    clc
    xce                     ; native mode
    rep #$38                ; 16-bit A/X/Y, binary
    .a16
    .i16
    ldx #$1FFF
    txs
    lda #$0000
    tcd                     ; direct page = $0000
    sep #$20
    .a8
    pha
    plb                     ; data bank = $00

    ; ---- PPU / CPU register init
    lda #$80
    sta INIDISP             ; forced blank
    ldx #$2101
@clr1:
    stz $00,x               ; $2101-$210C
    inx
    cpx #$210D
    bne @clr1
@clr2:
    stz $00,x               ; scroll regs are write-twice
    stz $00,x
    inx
    cpx #$2115
    bne @clr2
    lda #$80
    sta VMAIN
    stz $2116
    stz $2117
    stz $211A
    ldx #$211B
@clr3:
    stz $00,x               ; mode 7 matrix, write-twice
    stz $00,x
    inx
    cpx #$2121
    bne @clr3
    ldx #$2123
@clr4:
    stz $00,x               ; windows, TM/TS, colour math
    inx
    cpx #$2134
    bne @clr4
    lda #$30
    sta $2130               ; colour math off
    lda #$E0
    sta $2132               ; fixed colour = black
    stz NMITIMEN
    stz $4201
    stz $420B
    stz $420C
    stz $420D               ; slow ROM

    ; ---- video setup: mode 1, BG1 only
    lda #$01
    sta BGMODE
    lda #(MAP_VRAM >> 8) & $FC
    sta BG1SC               ; 32x32 map at $1000
    stz BG12NBA             ; BG1 tiles at $0000
    lda #$FF
    sta BG1VOFS             ; vertical scroll -1 so map row 0 is screen line 0
    sta BG1VOFS
    stz BG1HOFS
    stz BG1HOFS
    lda #$01
    sta TM

    ; tiles
    ldx #$0000
    stx VMADDL
    dma_to $2118, $01, CHR, $2000

    stz page
    jsr load_page

    ldx #$FFFF
    stx pad_old             ; ignore buttons held at power-on

    lda #$01
    sta NMITIMEN            ; auto joypad read, no NMI
    lda #$0F
    sta INIDISP             ; display on, full brightness

main:
@wait_vbl:
    lda HVBJOY
    bpl @wait_vbl
@wait_pad:
    lda HVBJOY
    and #$01
    bne @wait_pad

    rep #$20
    .a16
    lda JOY1L
    tax
    eor pad_old
    and JOY1L               ; newly pressed
    stx pad_old
    bit #$0090 | $0100      ; A, R, Right
    bne @next16
    bit #$0020 | $8000 | $0200  ; L, B, Left
    bne @prev16
    sep #$20
    .a8
    bra @wait_end
@prev16:
    .a16
    sep #$20
    .a8
    lda page
    bne @dec
    lda #NUM_PAGES
@dec:
    dec a
    bra @set
@next16:
    .a16
    sep #$20
    .a8
    lda page
    inc a
    cmp #NUM_PAGES
    bcc @set
    lda #0
@set:
    sta page
    lda #$80
    sta INIDISP
    jsr load_page
    lda #$0F
    sta INIDISP

@wait_end:
    lda HVBJOY
    bmi @wait_end           ; wait for vblank to finish
    bra main

; Upload the tilemap and palette for the current page. Call in forced blank.
load_page:
    ldx #MAP_VRAM
    stx VMADDL
    stz CGADD
    rep #$20
    .a16
    lda page
    and #$00FF
    asl a
    tax
    lda page_addr,x
    tax                     ; X = tilemap address
    sep #$20
    .a8
    lda #$01
    sta DMAP0
    lda #$18
    sta BBAD0
    stx A1T0L
    stz A1B0
    ldy #$0800
    sty DAS0L
    lda #$01
    sta MDMAEN
    stz DMAP0
    lda #$22
    sta BBAD0               ; A1T0 now points at the palette
    ldy #$0100
    sty DAS0L
    lda #$01
    sta MDMAEN
    rts

nmi:
irq:
    rti

.segment "HEADER"
    .byte "COLOUR SMEAR TEST    "   ; 21 bytes
    .byte $20                       ; LoROM, slow
    .byte $00                       ; ROM only
    .byte $05                       ; 32 KB
    .byte $00                       ; no SRAM
    .byte $01                       ; North America
    .byte $00                       ; developer
    .byte $00                       ; version
    .word $FFFF, $0000              ; checksum complement / checksum (fixed by build.sh)

.segment "VECTORS"
    .word 0, 0                      ; $FFE0 native
    .word irq, irq, irq, nmi, 0, irq   ; COP BRK ABORT NMI - IRQ
    .word 0, 0                      ; $FFF0 emulation
    .word irq, 0, irq, irq, reset, irq ; COP - ABORT NMI RESET IRQ/BRK
