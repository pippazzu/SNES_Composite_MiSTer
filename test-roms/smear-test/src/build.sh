#!/bin/sh
# Needs cc65 (ca65/ld65) and Python 3.
set -e
cd "$(dirname "$0")"
python3 gen_data.py data.bin
ca65 smeartest.s -o smeartest.o
ld65 -C lorom.cfg smeartest.o -o smeartest.sfc
python3 fix_checksum.py smeartest.sfc
