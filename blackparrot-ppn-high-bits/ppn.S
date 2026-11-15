# BlackParrot: Sv39 address translation ignores high-order PPN bits of a leaf PTE.
# Priv spec, Sv32 algorithm note (supervisor.adoc): "The algorithm does not admit the possibility of
# ignoring high-order PPN bits for implementations with narrower physical addresses." Sv39 PPNs are
# 44 bits (PTE bits 53:10), so a leaf whose PPN selects a physical address beyond memory must give
# an access fault (or other data), not the page that differs only in the high bits.
#
# Runs bare-metal in M-mode at 0x8000_0000. Loads go through Sv39 with mstatus.MPRV=1, MPP=S;
# PMP entry 0 grants S-mode RWX to all memory. Page tables map 4 KiB pages:
#   VA 0x0000 -> page P (first dword = 0x5eed5eed5eed5eed)
#   VA 0x1000 -> P's PPN + 2^43 (PA bit 55)
#   VA 0x2000 -> P's PPN + 2^38 (PA bit 50)
#   VA 0x3000 -> P's PPN + 2^30 (PA bit 42)
#   VA 0x4000 -> P's PPN + 2^20 (PA bit 32)
# For each VA, ld 0(VA) gives the value read, or 0xfa17_0000_0000_00cc if it trapped with mcause cc.
# Then the same five physical addresses are loaded untranslated from M-mode (MPRV=0).
# Pass: VA 0x0 reads the marker, and each aliased VA gives the same result as the untranslated load
# of its physical address (a platform may alias memory, but translation must not drop PPN bits).
# Default build: bp_tethered testbench (e_bp_unicore_cfg), prints the ten values through the host
# putint device. -DSPIKE: exits through tohost (pass = 1).
  .option norvc
  .section .text.init
  .globl _start
_start:
  la    t0, handler
  csrw  mtvec, t0
  li    t0, -1
  csrw  pmpaddr0, t0
  li    t0, 0x1f            # NAPOT, RWX
  csrw  pmpcfg0, t0
  # root[0] -> l1, l1[0] -> l0 (pointers: V only)
  la    t0, l1
  srli  t0, t0, 12
  slli  t0, t0, 10
  ori   t0, t0, 1
  la    t1, root
  sd    t0, 0(t1)
  la    t0, l0
  srli  t0, t0, 12
  slli  t0, t0, 10
  ori   t0, t0, 1
  la    t1, l1
  sd    t0, 0(t1)
  # l0[0..4]: leaves V R W A D (0xc7) with PPN = P's PPN + {0, 2^43, 2^38, 2^30, 2^20}
  la    s0, pg_P
  srli  s0, s0, 12          # P's PPN
  la    s1, l0
  la    s2, offsets
  li    s3, 5
1:
  ld    t0, 0(s2)
  add   t0, t0, s0
  slli  t0, t0, 10
  ori   t0, t0, 0xc7
  sd    t0, 0(s1)
  addi  s1, s1, 8
  addi  s2, s2, 8
  addi  s3, s3, -1
  bnez  s3, 1b
  # satp = Sv39, root
  la    t0, root
  srli  t0, t0, 12
  li    t1, 8
  slli  t1, t1, 60
  or    t0, t0, t1
  csrw  satp, t0
  sfence.vma
  # five loads, results in results[0..4]
  la    s4, results
  li    s5, 0               # VA
  li    s3, 5
2:
  li    t0, 0x1800          # MPP field
  csrc  mstatus, t0
  li    t0, 0x20800         # MPRV | MPP=S
  csrs  mstatus, t0
  li    a0, 0
load:
  ld    a0, 0(s5)           # handler sets a0 = 0xfa17... | mcause and skips this load
  li    t0, 0x20000
  csrc  mstatus, t0         # MPRV off
  sd    a0, 0(s4)
  addi  s4, s4, 8
  li    t0, 0x1000
  add   s5, s5, t0
  addi  s3, s3, -1
  bnez  s3, 2b

  # the same physical addresses, untranslated (M-mode, MPRV=0): results[5..9]
  la    s6, pg_P
  la    s2, offsets
  li    s3, 5
7:
  ld    t0, 0(s2)
  slli  t0, t0, 12
  add   s5, s6, t0          # PA = P + (offset << 12)
  li    a0, 0
  ld    a0, 0(s5)           # handler sets a0 = 0xfa17... | mcause and skips this load
  sd    a0, 0(s4)
  addi  s4, s4, 8
  addi  s2, s2, 8
  addi  s3, s3, -1
  bnez  s3, 7b

  la    s4, results
#ifndef SPIKE
  li    t0, 0x105000        # host putint: prints the dword in hex
  li    t1, 0x101000        # host putchar
  li    t2, 10
  li    s3, 10
3:
  ld    a0, 0(s4)
  sd    a0, 0(t0)
  sb    t2, 0(t1)
  addi  s4, s4, 8
  addi  s3, s3, -1
  bnez  s3, 3b
  la    s4, results
#endif
  # check: VA 0 reads the marker, and each aliased VA gives what an untranslated load of the
  # same physical address gives (the same data, or the same trap)
  la    t0, pg_P
  ld    t1, 0(t0)           # marker
  ld    a0, 0(s4)
  bne   a0, t1, fail
  li    s3, 4
4:
  addi  s4, s4, 8
  ld    a0, 0(s4)           # translated
  ld    a1, 40(s4)          # untranslated, same PA
  bne   a0, a1, fail
  addi  s3, s3, -1
  bnez  s3, 4b
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
6: j 6b

  .align 2
handler:                    # only the loads at `load` and the physical loads may trap
  csrr  a0, mcause
  li    t0, 0xfa17000000000000
  or    a0, a0, t0
  csrr  t0, mepc
  addi  t0, t0, 4
  csrw  mepc, t0
  mret

  .align 3
offsets:
  .dword 0, 1 << 43, 1 << 38, 1 << 30, 1 << 20
results:
  .fill 10, 8, 0

#ifdef SPIKE
  .align 6                  # tohost in the loaded image (RAM at 0x8000_0000)
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
#endif

  .align 12
root: .fill 512, 8, 0
l1:   .fill 512, 8, 0
l0:   .fill 512, 8, 0
pg_P: .dword 0x5eed5eed5eed5eed
  .fill 511, 8, 0
