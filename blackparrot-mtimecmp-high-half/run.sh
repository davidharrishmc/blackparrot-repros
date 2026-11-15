#!/bin/bash
# Build and run this reproducer on BlackParrot's bp_tethered Verilator testbench, and with
# SPIKE=1 on Spike instead.
# BLACKPARROT_SIM: the simsc of black-parrot 909619a6 or 18bad897 built with
#   make -C bp_top/verilator build.verilator CFG=e_bp_unicore_cfg
# Needs riscv64-unknown-elf-gcc and objcopy on PATH (and spike for SPIKE=1).
set -e
cd "$(dirname "$0")"
SRC=$(ls *.S); ELF=${SRC%.S}.elf
CC="riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64 -nostdlib -nostartfiles -static -Wl,-Ttext=0x80000000"
if [ -n "${SPIKE:-}" ]; then
  $CC -Wl,-n -DSPIKE -o spike-$ELF $SRC
  if spike --isa=rv64gc spike-$ELF; then echo "spike: PASS"; else echo "spike: FAIL"; fi | tee spike.log
  exit
fi
$CC -o $ELF $SRC
riscv64-unknown-elf-objcopy -O binary $ELF prog.bin
riscv64-unknown-elf-objcopy -I binary -O verilog prog.bin prog.mem
"${BLACKPARROT_SIM:?set BLACKPARROT_SIM to the bp_tethered simsc}" +init_mem=prog.mem +elf_file=$PWD/$ELF 2>&1 \
  | sed "s|$HOME|~|g" | tee run.log | grep -E '^[0-9a-f]{16}$|BSG-PASS|BSG-FAIL'
