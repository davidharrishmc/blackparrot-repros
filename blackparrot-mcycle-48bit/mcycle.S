# BlackParrot: mcycle and minstret keep only 48 bits.
# Priv spec 1.11, 3.1.11: "The mcycle and minstret registers have 64-bit precision on all RV32
# and RV64 systems."
# Runs bare-metal in M-mode at 0x8000_0000 in the bp_tethered testbench (e_bp_unicore_cfg).
  .section .text.init
  .globl _start
_start:
  csrwi mcountinhibit, 5    # stop both counters so the values read back unchanged
  li    t0, -1
  csrw  mcycle, t0
  csrw  minstret, t0
  csrr  a0, mcycle
  csrr  a1, minstret
  li    t0, 0x105000        # host putint: prints the dword in hex
  li    t1, 0x101000        # host putchar
  li    t2, 10
  sd    a0, 0(t0)
  sb    t2, 0(t1)
  sd    a1, 0(t0)
  sb    t2, 0(t1)
  li    t0, 0x102000        # host finish: 0 = pass, nonzero = fail
  not   a0, a0
  not   a1, a1
  or    a0, a0, a1
  bnez  a0, fail
  sd    x0, 0(t0)
2: j 2b
fail:
  li    t1, 1
  sd    t1, 0(t0)
3: j 3b
