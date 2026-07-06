# transform-accelerator

A hardware accelerator for 3D object transform calculations, written in SystemVerilog.  
Designed for affine transforms, quaternion multiplication, and dual quaternion blending —
the core operations needed to move a set of points from local to world coordinates.

This is my university thesis project. The RTL is being developed incrementally;
the sections below reflect what is currently complete and what is planned.

Verification is done with [Reflection](https://github.com/DefinumHunter/reflection),
a five-phase cocotb-based verification framework developed alongside this project.

---

## Architecture

The accelerator is built around a systolic array of MAC units for matrix and quaternion
multiplication, with a CORDIC unit planned for normalization operations (1/√x),
which are required for dual quaternion blending.

Data path uses Q16.16 fixed-point format throughout. Internal precision may differ
between stages; all external interfaces are Q16.16.

Target process: GPDK045. Synthesis and place-and-route with Cadence Genus and Innovus.

---

## RTL modules

| Module | Description | Status |
|--------|-------------|--------|
| `mac_q16` | Q16.16 multiply-accumulate, 4-stage pipeline, Banker's rounding, saturation | Complete, verified |
| `pe_input_mux` | Pre-adder/subtractor input mux, 2-stage pipeline | Complete, verified |
| `pe_mac_wrapper` | Wraps `pe_input_mux` + `mac_q16` into a single processing element | Complete, verified |
| `pe_output_strapping` | Post-adder with bypass and systolic modes | Complete, not yet verified |
| `affine3d_q16` | Top-level systolic chain for affine 3D transforms | In progress |
| CORDIC | 1/√x normalization unit | Planned |

---

## Testbenches

```
tb/
├── tb_mac_q16.sv
├── tb_pe_input_mux.sv
├── tb_pe_mac_wrapper.sv
└── sva/
    └── mac_q16_sva_checker.sv
```

Cocotb test configurations live in the
[Reflection](https://github.com/DefinumHunter/reflection) repo under `sim/Tests/`.

SVA integration into the automated verification flow is planned —
see the Reflection [ROADMAP](https://github.com/DefinumHunter/reflection/blob/master/ROADMAP.md).

---

## Design notes

- Single-responsibility modules: no internal state in datapath units, sequencing is
  handled externally
- All RTL comments in Russian
- Fixed-point arithmetic implemented in plain Python integer arithmetic for the
  golden models — no fixed-point libraries
- Banker's rounding (round half to even) in `mac_q16`
