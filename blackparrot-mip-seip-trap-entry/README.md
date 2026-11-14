# mip.SEIP reads 0 in the first instruction of a trap handler

black-parrot 909619a6, `e_bp_unicore_cfg`, bp_tethered Verilator testbench.

The program raises the S-mode external interrupt line through the CLINT (0x30c008), leaves interrupts
disabled, and reads `mip` three times: in straight-line code, as the first instruction of a trap
handler entered by `ecall`, and as the second instruction of that handler. All three should read
SEIP (bit 9) = 1.

Observed (`run.log`):

```
0000000000000280
0000000000000080
0000000000000280
[BSG-FAIL]
```

Expected:

```
0000000000000280
0000000000000280
0000000000000280
[BSG-PASS]
```

The same stale read happens for a `csrr mip` placed directly after the exit of a long loop.

Run: `BLACKPARROT_SIM=<path to simsc> ./run.sh`
