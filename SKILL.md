---
name: gfm-design
description: Use when designing, choosing, or tuning a grid-forming inverter control law in this Simulink/Simscape repo. Covers droop, VSG/synchronverter, dVOC, PSC, virtual impedance, inner V/I loops on an LCL, and multi-unit P/Q sharing. Generates a complete variant scaffold (gfm_params.m + build_*.m + run_*.m) that matches the repo's existing pattern. Out of scope: validation of an already-simulated model (use `gfm-validation`), bridge/PWM correctness (use `three-phase-grid-inverter`), grid-following controllers.
---

# GFM Design

## Overview

This skill is the **forward-design** workflow for grid-forming inverters in this repo:

```
specs (S, V, f_n, LCL, droop %, swing dynamics)
   |
   v
choose control law (droop / VSG / dVOC / PSC)
   |
   v
populate gfm_params.m (analytical formulas + bandwidth ladder)
   |
   v
generate full variant scaffold (params + build + run + .slx)
   |
   v
hand off to user for sim (then use `gfm-validation`)
```

It is **paired** with `gfm-validation`, which closes the loop after simulation. Stop and switch skills once a model exists and the question becomes "does the sim match the design".

## When to use this skill

Use when the user:

- Asks to design or tune a GFM controller from specs
- Wants to choose between droop / VSG / dVOC / PSC for a new model
- Asks to size droop coefficients, virtual inertia, voltage-loop gains, or dVOC `eta`/`alpha`
- Wants a new variant folder created from an existing one (e.g. "make a `single_vsg` variant")
- Modifies `gfm_params.m` and wants the dependent gains recomputed consistently

Do NOT use when:

- Simulation is already done and the user is debugging waveforms or sharing → `gfm-validation`
- The question is about PWM correctness, bridge gate ordering, sector tables → use a dedicated three-phase-grid-inverter / SVPWM skill if available, or read the waveform-validation literature directly
- The controller is grid-following (PLL-based, current-source) — out of scope

## Resource map

References (read on demand — they are self-contained, not just citations):

- `references/control-law-taxonomy.md` — decision tree across the three IEEE-recognized families, when to pick which.
- `references/droop-design.md` — P-ω / Q-V droop math, LPF cutoff, your `m_p = %·ωn/S` form.
- `references/vsg-synchronverter-design.md` — swing-eq mapping (J, D, H), Q-V option, synchronverter variant, equivalence to droop+LPF.
- `references/dvoc-design.md` — α-β oscillator, η/α/κ gains, voltage circle, slow-manifold droop equivalence.
- `references/psc-design.md` — Harnefors-style power-synchronization control.
- `references/inner-loops-and-lcl.md` — cascaded V-outer + I-inner PI on dq, bandwidth ladder, LCL resonance window, active vs. passive damping.
- `references/virtual-impedance.md` — cross-cutting Q-sharing fix, fault-current limiting hook.
- `references/multi-unit-sharing.md` — predicted P/Q sharing math, line-Z mismatch, when to add secondary control.
- `references/bibliography.md` — IEEE Transactions citations, organized by family.

Scripts (`scripts/`) — add the folder to MATLAB path before calling:

| Script | Purpose |
|---|---|
| `gfm_design_from_specs.m` | Specs → populated `p` struct in the repo's schema. |
| `gfm_predict_steady_state.m` | Given `p`, predict ω_pcc, V_pcc, per-inverter P/Q analytically (no sim). |
| `gfm_inner_loop_tuning.m` | Bandwidth-driven Kp/Ki for V and I PI loops given L_f, R_f. |
| `gfm_smallsignal.m` | Linearize droop/VSG/dVOC + inner loops + LCL → A,B,C,D for pole/Bode quick-look. |
| `gfm_generate_variant.m` | **Main scaffold generator**: writes `<folder>/gfm_params.m`, `<folder>/build_*.m`, `<folder>/run_*_sim.m`. |

## Workflow

Follow these steps in order. Skipping ahead invalidates downstream choices.

1. **Confirm scope**: single inverter or multi-unit? Grid-connected or islanded? SCR (X/R)? — these gate the choice of control law more than tuning does.
2. **Pick a control law** using `references/control-law-taxonomy.md`. Record the *why* (a sentence) so it lands in the generated `gfm_params.m` header.
3. **Set the bandwidth ladder** before any gain math: `f_pwr_filt ≪ f_outer_v ≪ f_inner_i ≪ f_sw/2`, and `m_p · S_rated · f_pwr_filt ≪ f_n`. Reject specs that violate this — they will not be fixable by tuning.
4. **Compute the law-specific gains** via the matching reference + `gfm_design_from_specs.m`. The function returns a struct with the exact field names the existing `build_*.m` files expect.
5. **Predict steady state** with `gfm_predict_steady_state.m` before generating the model. If predicted P_total ≠ Σ P_ref_i, the droops or line-Z assumptions are inconsistent — fix before scaffolding.
6. **Generate the variant**: `gfm_generate_variant('targetFolder', 'law', 'droop|vsg|dvoc|psc', 'topology', 'single|double')`. This writes the three .m files; the user runs `build_*` once to produce the .slx.
7. **Hand off**. Tell the user to run `build_*` then `run_*_sim`, and to use a separate validation skill (or do manual sim review) to check the results. Do NOT claim the design is verified by this skill alone — the skill only produces a *design*, not evidence. Simulation evidence comes from running MATLAB+Simulink and inspecting numerics/plots.

## Constraints from the repo

The scaffold generator preserves these conventions — do not deviate:

- Plant topology is fixed: `DC bus → Universal Bridge → L_f (=L_1, RL) → Cf-Rd shunt to Yg → L_2 (RL) → VI Meas → Grid Z → Three-Phase Source (Yg)`.
- Per-inverter VI block measures the inverter's own current. PCC Meas (double topology) sees aggregate.
- Controller is a `MATLAB Function` block, codegen-compatible, sampled at `p.Ts_ctrl`. It owns *all* state (no inner V/I loops as separate blocks).
- Controller outputs `m_abc ∈ [-1, 1]` directly to a `PWM Generator (2-Level)` with `ModulatingSignals='off'` (external modulation). No SVPWM, no dq-frame outputs.
- Discrete power system: `powergui` in `Discrete` mode, `Ts = p.Ts_power = 1e-6`. Solver `ode23tb` with `MaxStep = 1e-4`.
- Logging convention: `pq_<idx>_log`, `m_<idx>_log`, `I_<idx>_log` (5e-6 sample time for I, `Ts_ctrl` for pq/m). Shared bus: `Vpcc_log`, `Igrid_log`.
- `gfm_params()` must `assignin('base','p',p)` so block params like `'p.V_dc'` resolve.

A scaffold that breaks any of these will fail to compile against the rest of the repo.

## Output expectations

When the design phase ends, produce:

1. A populated `gfm_params.m` (printed inline if user is exploring; written to disk if scaffolding).
2. A short rationale: chosen law + one sentence why, the bandwidth ladder values, predicted steady-state P/Q.
3. Pointer to the validation skill for next steps.

Do not pretend to have run simulations. The skill never invokes `sim()` — that is the validation skill's job.
