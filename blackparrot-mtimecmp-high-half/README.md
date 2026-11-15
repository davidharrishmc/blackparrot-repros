# 32-bit accesses to the high half of mtimecmp act on the low half

black-parrot 909619a6 and 18bad897 (master, 2026-11-15), `e_bp_unicore_cfg`, bp_tethered Verilator testbench.

The program writes `0x4000000123456789` to `mtimecmp` (0x304000) with `sd`, reads each half with
`lwu`, then writes 7 to the high half with `sw` and reads the register with `ld`. Interrupts are
disabled.

Observed (`run.log`):

```
0000000023456789     lwu 0x304000
0000000023456789     lwu 0x304004
0000000700000007     sw 7 to 0x304004, then ld 0x304000
[BSG-FAIL]
```

Expected:

```
0000000023456789
0000000040000001
0000000723456789
[BSG-PASS]
```

Privileged spec, machine.adoc (`norm:mtime_mtimecmp_rv64_wr`): "For RV64, naturally aligned 64-bit
memory accesses to the `mtime` and `mtimecmp` registers are additionally supported and are atomic."
Naturally aligned 32-bit accesses to each half are the base requirement, on RV64 as on RV32.

Spike passes the same program (`SPIKE=1 ./run.sh` builds it with `-DSPIKE`: Spike's CLINT at
0x2004000, exit through `tohost`; output in `spike.log`).

Run: `BLACKPARROT_SIM=<path to simsc> ./run.sh`, or `SPIKE=1 ./run.sh` with `spike` on PATH.
