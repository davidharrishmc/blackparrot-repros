# BlackParrot: 32-bit accesses to the high half of mtimecmp act on the low half.
# Priv spec 1.11, 3.1.10 (machine.adoc, norm:mtime_mtimecmp_rv64_wr): "For RV64, naturally aligned
# 64-bit memory accesses to the mtime and mtimecmp registers are additionally supported and are
# atomic." 32-bit accesses to each half are therefore the base requirement on RV64 too.
# Runs bare-metal in M-mode at 0x8000_0000, interrupts disabled.
# Default build: bp_tethered testbench (e_bp_unicore_cfg), CLINT mtimecmp at 0x304000, prints the
# three values through the host putint device. -DSPIKE: Spike's CLINT (0x2004000), exits through
# tohost (pass = 1).
#ifdef SPIKE
#define MTIMECMP 0x2004000
#else
#define MTIMECMP 0x304000
#endif
  .section .text.init
  .globl _start
_start:
  csrwi mstatus, 0
  csrw  mie, x0
  li    t0, MTIMECMP
  li    t1, 0x4000000123456789
  sd    t1, 0(t0)
  lwu   a0, 0(t0)           # low half:  expect 0x0000000023456789
  lwu   a1, 4(t0)           # high half: expect 0x0000000040000001
  li    t1, 7
  sw    t1, 4(t0)           # write the high half only
  ld    a2, 0(t0)           # expect 0x0000000723456789
#ifndef SPIKE
  li    t0, 0x105000        # host putint: prints the dword in hex
  li    t1, 0x101000        # host putchar
  li    t2, 10
  sd    a0, 0(t0)
  sb    t2, 0(t1)
  sd    a1, 0(t0)
  sb    t2, 0(t1)
  sd    a2, 0(t0)
  sb    t2, 0(t1)
#endif
  li    t0, 0x23456789
  bne   a0, t0, fail
  li    t0, 0x40000001
  bne   a1, t0, fail
  li    t0, 0x0000000723456789
  bne   a2, t0, fail
#ifdef SPIKE
  li    t1, 1
#else
  li    t1, 0
#endif
  j     finish
fail:
#ifdef SPIKE
  li    t1, 3
#else
  li    t1, 1
#endif
finish:
#ifdef SPIKE
  la    t0, tohost
#else
  li    t0, 0x102000        # host finish: 0 = pass, nonzero = fail
#endif
  sd    t1, 0(t0)
1: j 1b

#ifdef SPIKE
  .align 6                  # tohost in the loaded image (RAM at 0x8000_0000)
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
#endif
