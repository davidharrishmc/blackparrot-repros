# Sv39 translation ignores high-order PPN bits of a leaf PTE

black-parrot 909619a6 and 18bad897 (master, 2026-11-15), `e_bp_unicore_cfg`, bp_tethered Verilator testbench.

The program builds Sv39 page tables with 4 KiB leaves and loads through them from M-mode with
`mstatus.MPRV=1`, `MPP=S` (PMP entry 0 grants all memory). VA 0x0 maps page P, whose first dword is
`0x5eed5eed5eed5eed`. VAs 0x1000-0x4000 map P's PPN plus 2^43, 2^38, 2^30 and 2^20, that is, P's
physical address with bit 55, 50, 42 or 32 set. It then loads the same five physical addresses
directly from M-mode with `MPRV=0`. A load that traps prints `fa170000000000cc`, where cc is mcause.

Observed (`run.log`):

```
5eed5eed5eed5eed     VA 0x0    -> P
5eed5eed5eed5eed     VA 0x1000 -> P + 2^55
5eed5eed5eed5eed     VA 0x2000 -> P + 2^50
5eed5eed5eed5eed     VA 0x3000 -> P + 2^42
5eed5eed5eed5eed     VA 0x4000 -> P + 2^32
5eed5eed5eed5eed     PA P
fa17000000000005     PA P + 2^55: load access fault
fa17000000000005     PA P + 2^50: load access fault
fa17000000000005     PA P + 2^42: load access fault
5eed5eed5eed5eed     PA P + 2^32
[BSG-FAIL]
```

The physical loads of P + 2^55, 2^50 and 2^42 raise load access faults, but the same physical
addresses reached through a PTE read P. (P + 2^32 reads P both ways, which is a platform alias, not
a translation issue.)

Expected: each translated load gives the same result as the untranslated load of its physical
address, so the second, third and fourth lines are `fa17000000000005`.

Privileged spec, supervisor.adoc, note after the Sv32 translation algorithm: "The algorithm does not
admit the possibility of ignoring high-order PPN bits for implementations with narrower physical
addresses."

Spike passes the same program (`SPIKE=1 ./run.sh` builds it with `-DSPIKE` and exits through
`tohost`; output in `spike.log`).

Run: `BLACKPARROT_SIM=<path to simsc> ./run.sh`, or `SPIKE=1 ./run.sh` with `spike` on PATH.
