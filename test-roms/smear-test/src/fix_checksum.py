#!/usr/bin/env python3
"""Write the internal LoROM checksum into a 32 KB SNES ROM."""
import sys
p = sys.argv[1]
rom = bytearray(open(p, "rb").read())
rom[0x7FDC:0x7FE0] = b"\xFF\xFF\x00\x00"
s = sum(rom) & 0xFFFF
rom[0x7FDC:0x7FDE] = (s ^ 0xFFFF).to_bytes(2, "little")
rom[0x7FDE:0x7FE0] = s.to_bytes(2, "little")
open(p, "wb").write(rom)
print(f"checksum {s:04X}")
