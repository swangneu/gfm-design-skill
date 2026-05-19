---
name: gfm-design
description: "Use when designing, choosing, or tuning a grid-forming inverter control law for a Simulink/Simscape model, or when a gfm-validation report shows design assumptions or controller parameters need revision. Covers droop, VSG/synchronverter, dVOC, PSC, virtual impedance, inner V/I loops on an LCL, multi-unit P/Q sharing, nominal current/protection envelope checks, and validation-feedback retuning. Produces a populated `gfm_params.m` parameter struct plus analytical predictions. Out of scope: running sim(), certification/grid-code compliance proof, bridge/PWM correctness, grid-following controllers."
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
record protection envelope (current limits, modulation headroom, grid-code assumptions)
   |
   v
populate gfm_params.m  (analytical formulas + bandwidth ladder)
   |
   v
predict steady-state, current headroom, and small-signal behavior  (gfm_predict_steady_state + gfm_smallsignal)
   |
   v
hand the parameter struct off to the user's Simulink model — manual sim review closes the loop
```

The skill never invokes `sim()`. Stop using it once a model exists and the question becomes "does the sim match the design".

Companion skill: use `$gfm-validation` for simulation-facing work after this skill produces a design. `gfm-validation` runs or inspects Simulink logs, compares them against `gfm_predict_steady_state`, and writes validation reports. Keep controller retuning and first-pass parameter design here; keep model execution and log comparison there.

## When to use this skill

Use when the user:

- Asks to design or tune a GFM controller from specs
- Wants to choose between droop / VSG / dVOC / PSC for a new model
- Asks to size droop coefficients, virtual inertia, voltage-loop gains, or dVOC `eta`/`alpha`
- Modifies `gfm_params.m` and wants the dependent gains recomputed consistently
- Provides a `gfm-validation` report and asks whether design assumptions or controller parameters should change

Do NOT use when:

- Simulation is already done and the user is only asking to extract logs, compare signals, or judge pass/fail results → use `$gfm-validation`
- Simulation is already done and the user is debugging raw waveforms without asking for design changes → use `$gfm-validation` or manual sim review
- The question is about PWM correctness, bridge gate ordering, sector tables → out of scope
- The controller is grid-following (PLL-based, current-source) → out of scope

## Resource map

References are organized by scope. Read essential ones for every design; read plus ones only when the scenario calls for them.

### Essential — GFM-general (any control family)

| Reference | Purpose |
|---|---|
| `references/control-law-taxonomy.md` | Decision tree across droop / VSG / dVOC / PSC. Pick the law before touching gains. |
| `references/gfm-test-scenarios.md` | Steady-state → small-signal → large-signal tier ordering and the scenario matrix. Use to bound the work before designing. |
| `references/validation-feedback-loop.md` | Triage `gfm-validation` reports; decide whether to retune, change assumptions, or fix model/logging issues. |

### Essential — Control-law-specific (read only the one you chose)

| Reference | Use when |
|---|---|
| `references/droop-design.md` | Control law is droop / P-ω, Q-V. |
| `references/vsg-synchronverter-design.md` | Control law is VSG / synchronverter with an explicit `H`. |
| `references/dvoc-design.md` | Control law is dVOC. Includes the Phi-form vs Andronov-Hopf-form ambiguity and saddle-IC warning. |
| `references/psc-design.md` | Control law is Harnefors-style power-synchronization control. |

### Essential — Simulation and implementation

These are independent of which control family you chose. Read both for any handoff to Simulink/SPS.

| Reference | Purpose |
|---|---|
| `references/simulink-modeling-conventions.md` | Topology, signal names, units, sample times, SPS source unit conventions (LL RMS vs LL peak), `Yg`/`Yn`/`Y` neutral-pin behavior, MATLAB Function chart-literal patching. |
| `references/verified-baseline-workflow.md` | Clone-and-patch a known-good `.slx` instead of rebuilding from specs; the safer path when a verified reference model already exists. |
| `references/time-step-coordination.md` | Four-rate ladder (power / PWM / controller / measurement), forcing a MATLAB Function block to discrete sample time matching the algorithm's hardcoded `dt`, S-Function Builder caveats, and a port-from-C recipe. |

### Plus — Read when the scenario demands it

| Reference | Read when |
|---|---|
| `references/inner-loops-and-lcl.md` | Cascaded V/I PI loops on dq are in the model; LCL resonance window matters. |
| `references/virtual-impedance.md` | Q-sharing under line-Z mismatch, or fault-current limiting via virtual impedance. |
| `references/current-limiting-and-protection.md` | Current ratings, limiter modes, anti-windup, fault/recovery checklist. |
| `references/lvrt-and-fault-ride-through.md` | LVRT/FRT or ZVRT in scope (Tier-3 large-signal). |
| `references/strong-grid-stability.md` | High-SCR / infinite-bus stability, pre-sync, voltage-source stiffness (Tier-3 large-signal). |
| `references/multi-unit-sharing.md` | Two or more inverters in parallel; sharing math, line-Z mismatch, secondary control. |
| `references/standards-and-grid-codes.md` | Reference IEEE 1547/2800, UNIFI, or site grid-code assumptions (without claiming compliance). |
| `references/recent-gfm-requirements.md` | Current research / specification directions beyond standards. |

### Plus — Control-law implementation extras

| Reference | Read when |
|---|---|
| `references/dvoc-implementation-conventions.md` | Implementing or porting dVOC into a switching/SPS model: form-variant cross-check, hardcoded chart literals (`P`, `Q`, `Vnom`, IC), sign and PWM validation recipe. |

### Citations

| Reference | Purpose |
|---|---|
| `references/bibliography.md` | IEEE Transactions citations, organized by family. |

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

0. **Check for a verified baseline.** If the user already has a Simulink model that passes its own basic test and the task is "change one thing" (new disturbance, new setpoint, new logging) rather than "design a controller from specs", **stop here and use `references/verified-baseline-workflow.md`**. Rebuilding from scratch when a verified baseline exists is a known way to inject `sqrt(2)`/`sqrt(3)`, sample-time, and convention errors that the baseline already handled correctly.
1. **Confirm scope**: single inverter or multi-unit? Grid-connected or islanded? SCR (X/R)? LVRT/FRT or strong-grid connection concern? — these gate the choice of control law more than tuning does.
2. **Pick a control law** using `references/control-law-taxonomy.md`. Record the *why* (a sentence) so it lands in the `gfm_params.m` header.
3. **Set the bandwidth ladder** before any gain math: `f_pwr_filt ≪ f_outer_v ≪ f_inner_i ≪ f_sw/2`, and `m_p · S_rated · f_pwr_filt ≪ f_n`. Reject specs that violate this — they will not be fixable by tuning.
4. **Record the protection envelope** before handoff math: continuous/short-time current, modulation ceiling, current-limiter mode, anti-windup expectation, and applicable standard/grid-code target. If the user does not provide these, label the output as a nominal controller design only. Read `references/current-limiting-and-protection.md` and `references/standards-and-grid-codes.md` for abnormal-event work.
5. **If LVRT/FRT is in scope**, record voltage-time curves, voltage measurement basis, current-priority rule, negative-sequence/per-phase behavior, momentary-cessation assumption, and current-limit exit rule. Read `references/lvrt-and-fault-ride-through.md`.
6. **If high SCR / strong grid is in scope**, check voltage-source stiffness, pre-synchronization assumptions, virtual impedance, damping, and SCR sweep expectations. Read `references/strong-grid-stability.md`.
7. **Compute the law-specific gains** via the matching reference + `gfm_design_from_specs.m`. The function returns a struct with the field names a `build_*.m` Simulink builder would expect. For dVOC handoff into a Simulink or switching model, read `references/dvoc-implementation-conventions.md` before declaring a gain or tracking issue.
8. **Predict steady state** with `gfm_predict_steady_state.m`. Confirm `P_total` matches the requested load and inspect frequency/voltage/current headroom before handing off. If any unit is current-limited or modulation-limited, the linear sharing prediction is invalid.
9. **(Optional) Linearized check**: `gfm_smallsignal(p)` for a pole/Bode quick-look. All poles in the LHP is the minimum bar; any RHP pole means the design is unstable. For strong-grid work, sweep `L_g` / SCR rather than checking only one grid strength.
10. **Hand off**. Give the user the populated `p` struct and a short rationale; tell them to plug it into their Simulink model and run manual sim review. If the user asks for model-building guidance, cite `references/simulink-modeling-conventions.md` and `references/gfm-test-scenarios.md`. Do NOT claim the design is verified by this skill alone — the skill only produces a *design*, not evidence.

## Validation feedback loop

When the user returns with a `gfm-validation` report, read `references/validation-feedback-loop.md` before changing parameters. Triage findings in this order:

1. **Measurement/logging issue**: unit mismatch, sign convention, wrong PCC boundary, or bad settled window. Send the user back to `$gfm-validation` or model logging fixes; do not retune.
2. **Scenario outside assumptions**: current limiting, modulation saturation, LVRT/FRT, unbalanced fault, high-SCR stress, or a grid impedance not represented in `p`. Update assumptions and protection notes before retuning.
3. **Design mismatch**: prediction and logs are measured correctly but final P/Q/f/V, damping, sharing, or current headroom miss the target. Re-enter this skill's design workflow with the validation metrics as new specs.
4. **Model implementation mismatch**: controller interface, Park convention, limiter behavior, or inner-loop realization differs from the parameter-struct conventions. State the mismatch and either adapt the handoff assumptions or ask the user to align the model.

Never treat a failed validation report as automatic proof that droop/VSG/dVOC/PSC gains are wrong. First prove the simulation case matches the design assumptions.

## Parameter-struct conventions

`gfm_design_from_specs.m` returns a struct in a schema that a typical Simulink GFM model can consume directly. The conventions below describe what each field assumes about the Simulink target; deviate only with reason.

- Plant topology assumed: `DC bus → Universal Bridge → L_f (RL) → Cf-Rd shunt to Yg → L_2 (RL) → VI Meas → Grid Z → Three-Phase Source (Yg)`.
- Controller intended as a `MATLAB Function` block, codegen-compatible, sampled at `p.Ts_ctrl`. It owns *all* state (no inner V/I loops as separate blocks).
- Controller output: `m_abc ∈ [-1, 1]` direct to a `PWM Generator (2-Level)` with `ModulatingSignals='off'` (external modulation). No SVPWM, no dq-frame outputs.
- Protection fields (`I_cont_peak`, `I_limit_peak`, `I_short_peak`, `t_short_limit`, `m_max`, `current_limit_mode`) are design-screening assumptions. They do not implement protection unless the user's controller consumes them.
- LVRT/FRT fields (if present) are assumptions for a future simulation or HIL test harness: voltage-time curve, measurement basis, current-priority rule, sequence/per-phase behavior, and recovery logic.
- Strong-grid fields (if present) are stress-case assumptions: SCR/X/R sweep range, virtual impedance, pre-synchronization thresholds, and high-SCR damping checks.
- Discrete power system: `powergui` in `Discrete` mode, `Ts = p.Ts_power = 1e-6`. Solver `ode23tb` with `MaxStep = 1e-4`.
- `gfm_params()` should `assignin('base','p',p)` so block parameters like `'p.V_dc'` resolve at compile time.

A Simulink model that violates these conventions will still accept the `p` struct, but the user must adapt the controller block to match the assumed interface (peak phase voltages, instantaneous P/Q from amplitude-invariant Park, etc.).

## Output expectations

When the design phase ends, produce:

1. A populated `gfm_params.m` (printed inline, or written to disk on user request).
2. A short rationale: chosen law + one sentence why, the bandwidth ladder values, predicted steady-state P/Q/current headroom from `gfm_predict_steady_state`.
3. A protection/grid-code assumptions note: current limits used, limiter mode, modulation headroom, and whether IEEE/UNIFI/site requirements are known or still missing.
4. LVRT/FRT and strong-grid notes when relevant: what was assumed, what remains untested, and which scenarios must be run outside the skill.
5. (Optional) Small-signal pole locations from `gfm_smallsignal` if stability margin matters.

Ground non-obvious recommendations in a local reference doc and, where possible, the primary source listed in `references/bibliography.md`. If a recommendation is only an engineering heuristic, say so explicitly.

Do not pretend to have run simulations or compliance tests. The skill never invokes `sim()` — simulation and grid-code evidence come from the user running MATLAB+Simulink, EMT/HIL cases, and project-specific review.
