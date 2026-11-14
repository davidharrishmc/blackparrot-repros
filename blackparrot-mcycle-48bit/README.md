# mcycle and minstret keep only 48 bits

black-parrot 909619a6, `e_bp_unicore_cfg`, bp_tethered Verilator testbench.

The program stops both counters with `mcountinhibit`, writes all ones to `mcycle` and
`minstret`, and reads them back.

Observed (`run.log`):

```
0000ffffffffffff
0000ffffffffffff
[BSG-FAIL]
```

Expected:

```
ffffffffffffffff
ffffffffffffffff
[BSG-PASS]
```

The counters are stored as `bp_mcounter_s`, 48 bits
(https://github.com/black-parrot/black-parrot/blob/909619a68f3541a4cd0973767daf2a561d1f8c95/bp_common/src/include/bp_common_rv64_csr_defines.svh#L617,
https://github.com/black-parrot/black-parrot/blob/909619a68f3541a4cd0973767daf2a561d1f8c95/bp_common/src/include/bp_common_rv64_csr_defines.svh#L999-L1000).

Run: `BLACKPARROT_SIM=<path to simsc> ./run.sh`
