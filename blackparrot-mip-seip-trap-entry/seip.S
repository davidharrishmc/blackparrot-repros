# BlackParrot: a csrr of mip that is the first instruction of a trap handler reads SEIP = 0
# while the S-mode external interrupt line is high. The next csrr of mip reads SEIP = 1.
# Priv spec 1.11, 3.1.9: when mip is read with a CSR instruction, the SEIP bit returned is the
# logical-OR of the software-writable bit and the interrupt signal from the interrupt controller.
# Bare-metal M-mode at 0x8000_0000 in the bp_tethered testbench (e_bp_unicore_cfg).
# Prints three mip reads, each expected to have bit 9 set, and passes only if all three do.
  .section .text.init
  .globl _start
_start:
  li    t0, 0x30c008        # CLINT: S-mode external interrupt line (s_external_irq_o)
  li    t1, 1
  sd    t1, 0(t0)           # raise the line; interrupts stay disabled (mstatus.MIE = 0, mie = 0)
  fence
  la    t0, handler
  csrw  mtvec, t0
  li    t2, 1000            # let the line settle
1: addi t2, t2, -1
  bnez  t2, 1b
  nop
  csrr  a0, mip             # read 1: in straight-line code
  ecall                     # enter the handler
  li    t0, 0x105000        # host putint: prints a dword in hex
  li    t1, 0x101000        # host putchar
  li    t2, 10
  sd    a0, 0(t0)
  sb    t2, 0(t1)
  sd    a1, 0(t0)
  sb    t2, 0(t1)
  sd    a2, 0(t0)
  sb    t2, 0(t1)
  and   a0, a0, a1
  and   a0, a0, a2
  andi  a0, a0, 0x200
  li    t0, 0x102000        # host finish: 0 = pass, nonzero = fail
  beqz  a0, fail
  sd    x0, 0(t0)
2: j 2b
fail:
  li    t1, 1
  sd    t1, 0(t0)
3: j 3b

  .align 6
handler:
  csrr  a1, mip             # read 2: first instruction of the trap handler
  csrr  a2, mip             # read 3: second instruction of the trap handler
  csrr  t0, mepc
  addi  t0, t0, 4
  csrw  mepc, t0
  mret
