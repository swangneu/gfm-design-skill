---
name: gfm-design
description: Use when designing, choosing, or tuning a grid-forming inverter control law for a Simulink/Simscape model. Covers droop, VSG/synchronverter, dVOC, PSC, virtual impedance, inner V/I loops on an LCL, and multi-unit P/Q sharing. Produces a populated `gfm_params.m` parameter struct plus analytical predictions (steady-state ω/V/P/Q, small-signal poles) for the user to drop into their own Simulink model. Out of scope: post-simulation validation (manual sim review), bridge/PWM correctness, grid-following controllers.
---

# GFM Design

## Overview

Forward-design workflow for grid-forming inverters:

```
specs (S, V, f_n, LCL, droop %, swing dynamics)
   |
   v
choose control law (droop / VSG / dVOC / PSC)
   |
   v
populate gfm_params.m  (analytical formulas + bandwidth ladder)
   |
   v
predict steady-state and small-signal behavior  (gfm_predict_steady_state + gfm_smallsignal)
   |
   v
hand the parameter struct off to the user's Simulink model — manual sim review closes the loop
```

The skill never invokes `sim()`. Stop using it once a model exists and the question becomes "does the sim match the design".

## When to use this skill

Use when the user:

- Asks to design or tune a GFM controller from specs
- Wants to choose between droop / VSG / dVOC / PSC for a new model
- Asks to size droop coefficients, virtual inertia, voltage-loop gains, or dVOC `eta`/`alpha`
- Modifies `gfm_params.m` and wants the dependent gains recomputed consistently

Do NOT use when:

- Simulation is already done and the user is debugging waveforms or sharing → manual sim review
- The question is about PWM correctness, bridge gate ordering, sector tables → out of scope
- The controller is grid-following (PLL-based, current-source) → out of scope

## Resource map

References (read on demand — they are self-contained, not just citations):

- `references/control-law-taxonomy.md` — decision tree across the three IEEE-recognized families, when to pick which.
- `references/droop-design.md` — P-ω / Q-V droop math, LPF cutoff, the `m_p = %·ωn/S` form.
- `references/vsg-synchronverter-design.md` — swing-eq mapping (J, D, H), Q-V option, synchronverter variant, equivalence to droop+LPF.
- `references/dvoc-design.md` — α-β oscillator, η/α/κ gains, voltage circle, slow-manifold droop equivalence.
- `references/psc-design.md` — Harnefors-style power-synchronization control.
- `references/inner-loops-and-lcl.md` — cascaded V-outer + I-inner PI on dq, bandwidth ladder, LCL resonance window, active vs. passive damping.
- `references/virtual-impedance.md` — cross-cutting Q-sharing fix, fault-current limiting hook.
- `references/multi-unit-sharing.md` — predicted P/Q sharing math, line-Z mismatch, when to add secondary control.
- `references/bibliography.md` — IEEE Transactions citations, organized by family.

Scripts (`scripts/`) — add the folder to MATLAB path before calling. All standalone (MATLAB ≥ R2024b; `gfm_smallsignal` also needs Control System Toolbox):

| Script | Purpose |
|---|---|
| `gfm_design_from_specs.m` | Specs → populated `p` struct (parameter schema for any GFM model). |
| `gfm_predict_steady_state.m` | Given `p`, predict ω_pcc, V_pcc, per-inverter P/Q analytically (no sim). |
| `gfm_inner_loop_tuning.m` | Bandwidth-driven Kp/Ki for V and I PI loops given L_f, R_f. |
| `gfm_smallsignal.m` | Linearize droop/VSG/dVOC/PSC → A,B,C,D for pole/Bode quick-look. |
| `test_gfm_design.m` | Smoke harness exercising the four scripts above. |

## Workflow

Follow these steps in order. Skipping ahead invalidates downstream choices.

1. **Confirm scope**: single inverter or multi-unit? Grid-connected or islanded? SCR (X/R)? — these gate the choice of control law more than tuning does.
2. **Pick a control law** using `references/control-law-taxonomy.md`. Record the *why* (a sentence) so it lands in the `gfm_params.m` header.
3. **Set the bandwidth ladder** before any gain math: `f_pwr_filt ≪ f_outer_v ≪ f_inner_i ≪ f_sw/2`, and `m_p · S_rated · f_pwr_filt ≪ f_n`. Reject specs that violate this — they will not be fixable by tuning.
4. **Compute the law-specific gains** via the matching reference + `gfm_design_from_specs.m`. The function returns a struct with the field names a `build_*.m` Simulink builder would expect.
5. **Predict steady state** with `gfm_predict_steady_state.m`. If predicted `P_total ≠ Σ P_ref_i`, the droops or line-Z assumptions are inconsistent — fix before handing off.
6. **(Optional) Linearized check**: `gfm_smallsignal(p)` for a pole/Bode quick-look. All poles in the LHP is the minimum bar; any RHP pole means the design is unstable.
7. **Hand off**. Give the user the populated `p` struct and a short rationale; tell them to plug it into their Simulink model and run manual sim review. Do NOT claim the design is verified by this skill alone — the skill only produces a *design*, not evidence.

## Parameter-struct conventions

`gfm_design_from_specs.m` returns a struct in a schema that a typical Simulink GFM model can consume directly. The conventions below describe what each field assumes about the Simulink target; deviate only with reason.

- Plant topology assumed: `DC bus → Universal Bridge → L_f (RL) → Cf-Rd shunt to Yg → L_2 (RL) → VI Meas → Grid Z → Three-Phase Source (Yg)`.
- Controller intended as a `MATLAB Function` block, codegen-compatible, sampled at `p.Ts_ctrl`. It owns *all* state (no inner V/I loops as separate blocks).
- Controller output: `m_abc ∈ [-1, 1]` direct to a `PWM Generator (2-Level)` with `ModulatingSignals='off'` (external modulation). No SVPWM, no dq-frame outputs.
- Discrete power system: `powergui` in `Discrete` mode, `Ts = p.Ts_power = 1e-6`. Solver `ode23tb` with `MaxStep = 1e-4`.
- `gfm_params()` should `assignin('base','p',p)` so block parameters like `'p.V_dc'` resolve at compile time.

A Simulink model that violates these conventions will still accept the `p` struct, but the user must adapt the controller block to match the assumed interface (peak phase voltages, instantaneous P/Q from amplitude-invariant Park, etc.).

## Output expectations

When the design phase ends, produce:

1. A populated `gfm_params.m` (printed inline, or written to disk on user request).
2. A short rationale: chosen law + one sentence why, the bandwidth ladder values, predicted steady-state P/Q from `gfm_predict_steady_state`.
3. (Optional) Small-signal pole locations from `gfm_smallsignal` if stability margin matters.

Do not pretend to have run simulations. The skill never invokes `sim()` — simulation evidence comes from the user running MATLAB+Simulink and inspecting numerics/plots.
