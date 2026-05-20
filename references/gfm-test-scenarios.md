# GFM Test Scenarios

This note lists simulation scenarios that should be run outside this skill
after a parameter design is handed to a Simulink or EMT model. The skill does
not call `sim()` and does not turn these scenarios into evidence by itself.

## Depth tiers — work through them in order

GFM validation has a natural ordering. Going to large-signal tests before the steady-state and small-signal tiers pass is wasted simulation time, because almost every large-signal failure has a tier-1 or tier-2 root cause that's faster to find at the simpler tier.

### Tier 1 — Steady-state and bring-up (mandatory first)

Goal: confirm the inverter builds up voltage and frequency, settles cleanly, and tracks zero or small setpoints in a stiff-grid configuration. The amplitude, sign, and convention audits live here.

| Scenario | What it proves |
|---|---|
| Cold start, `P*=Q*=0`, stiff grid | The chart, PWM, bridge, and filter are wired correctly. `|v_inv| ≈ |v_grid|` in steady state. |
| Steady non-zero `P*` only | Active-power dispatch in W is connected to the chart correctly. Current settles. |
| Steady non-zero `Q*` only | Reactive-power dispatch direction is correct. Voltage holds. |
| Nominal load on a stiff grid | Combined `P/Q` dispatch matches `gfm_predict_steady_state`. |

Do not advance to Tier 2 until every Tier 1 case settles with the expected amplitudes and signs. A `sqrt(2)` / `sqrt(3)` mismatch or a flipped sign at this tier is *always* a unit/convention bug, never a tuning bug — read `simulink-modeling-conventions.md` and `dvoc-implementation-conventions.md`.

### Tier 2 — Small-signal disturbances

Goal: confirm the controller's linearized response matches design predictions. Disturbances are small enough that the limit cycle is never far from its equilibrium and the linearization holds.

| Scenario | What it proves |
|---|---|
| Small `P*` step (±10–20%) | P-ω droop slope, power-filter LPF cutoff, swing damping (VSG `H`/`D`, dVOC `eta`). |
| Small `Q*` step (±10–20%) | Q-V droop slope, voltage settling. |
| Small load step | Sharing among multiple units, line-impedance contribution. |
| Small `f_grid` ramp / RoCoF (mHz/s) | Frequency tracking and droop response. |
| SCR change (e.g. SCR 10 → SCR 5, both modest values) | Damping under modest grid stiffness changes. |
| Modest `V_grid` step (±5–10%) | Voltage settling, modulation headroom margin. |

These are appropriate for comparing against `gfm_smallsignal(p)` poles and `gfm_predict_steady_state` numbers. Linear predictions stay valid here.

### Tier 3 — Large-signal transients (last)

Goal: stress the controller into regions where the linearization fails and the limit-cycle dynamics, saturations, and protection envelope dominate. Use only after Tier 1 and Tier 2 both pass.

| Scenario | What it proves |
|---|---|
| Phase jump (±15° / ±30° / ±45° / larger) | Re-synchronization from a large angular displacement; saddle/limit-cycle global behavior of the oscillator. |
| Step SCR change spanning weak-strong boundary (e.g. SCR 20 → SCR 1.5) | Stability across the weak-grid threshold, voltage-source stiffness vs grid impedance. |
| LVRT / ZVRT (deep voltage sag, possibly with fault impedance) | Current limit engages and exits, sequence behavior, recovery shape. |
| HVRT (sustained overvoltage) | Modulation ceiling, anti-windup behavior, voltage-source stiffness from above. |
| Unbalanced fault (SLG, LL, LLG) | Per-phase or sequence current limiting, negative-sequence response. |
| Large load step or full load rejection | Energy reserve, swing-equation damping margin, current peak in worst case. |
| Islanding / re-synchronization with measurable phase offset | Hard-grid disconnect transient, pre-sync logic, breaker-close transient. |
| Frequency step (large, e.g. ±0.5 Hz) | Saturation of frequency droop, possible decoupling from the linear prediction. |

Linear predictions from `gfm_predict_steady_state` and `gfm_smallsignal` are **not** valid during these scenarios. Compare only the *post-event re-settled* window (with the same tier-1 amplitude checks) to confirm the controller returned to a sensible operating point. The during-event behavior is judged against the scenario contract: protection envelope, recovery timing, sequence behavior — not against a small-signal prediction.

Common Tier 3 trap (specific to dVOC and other oscillator-based GFMs): the pre-event window must be **settled** before the disturbance arrives, otherwise the "baseline" row of the report catches a slow transient (often a saddle-point escape) and the disturbance response is contaminated. See the validation skill's `references/pre-flight-convention-audit.md` and `dvoc-design.md` Initialization warning.

## Scenario groups (cross-reference to depth tiers)

| Group | Scenarios | Depth tier | Why it matters |
|---|---|---|---|
| Nominal operation | enable, small P step, small Q step | Tier 1–2 | checks signs, droop slopes, power filters, settling |
| Grid-strength sweep | small SCR change | Tier 2 | catches weak-grid and strong-grid interactions |
| Grid-strength sweep | SCR 2/5/10/20/50, X/R sweep, weak→strong jump | Tier 3 | stresses voltage-source stiffness and decoupling |
| LVRT/FRT | 3-phase sag, SLG, LL, fault clearing | Tier 3 | checks current limit, sequence behavior, recovery |
| Frequency events | small frequency ramp | Tier 2 | droop/VSG frequency support |
| Frequency events | large step, RoCoF | Tier 3 | saturation and limiter interaction |
| Voltage events | small voltage step | Tier 2 | modulation headroom |
| Voltage events | phase-angle jump, HVRT | Tier 3 | synchronizing stiffness, large-signal recovery |
| Multi-unit sharing | balanced small steps | Tier 2 | P/Q sharing |
| Multi-unit sharing | unequal line impedance under load, one unit limiting | Tier 3 | saturation breakdown |
| Plant energy limits | DC-link sag, BESS power limit, PV curtailment | Tier 3 | source constraint and recovery |
| Connection sequence | pre-sync, breaker close, islanding, resync | Tier 3 | hard-grid transient and state initialization |

## Minimum logged channels

Log the following for every scenario:

```text
v_pcc_abc_V, v_pcc_posseq_pu, v_pcc_negseq_pu
i_grid_abc_A, i_peak_per_phase_A, i_posseq_A, i_negseq_A
p_inst_W, q_inst_var, P_filt_W, Q_filt_var
theta_ctrl_rad, omega_ctrl_radps, freq_ctrl_Hz
m_abc_pu, modulation_margin_pu
limiter_active, limiter_mode, anti_windup_active
V_dc_V, source_power_W, breaker_status
```

For multi-unit cases, log these per inverter and at the plant/PCC level.

## Pass/fail style checks

Use numeric checks where the user provides limits:

- `max(abs(i_phase)) <= p.I_abs_max_peak`.
- Time above `p.I_short_peak` is less than `p.t_short_limit`.
- `max(abs(m_abc)) <= p.m_max`.
- Nominal operating point stays below `p.I_cont_peak`.
- After a disturbance, limiter exits and stays exited.
- P/Q/V/frequency settle within the project tolerance.
- No controller state keeps ramping while a command is saturated.

If the user has not provided limits, do not invent pass/fail thresholds. Report
the observed maxima and mark the case as "needs project limits".

## Mapping scenarios to references

| Scenario group | Local reference |
|---|---|
| LCL resonance and inner loops | [inner-loops-and-lcl](inner-loops-and-lcl.md) |
| Current limiting and anti-windup | [current-limiting-and-protection](current-limiting-and-protection.md) |
| LVRT/FRT | [lvrt-and-fault-ride-through](lvrt-and-fault-ride-through.md) |
| Strong-grid checks | [strong-grid-stability](strong-grid-stability.md) |
| Multi-unit sharing | [multi-unit-sharing](multi-unit-sharing.md) |
| Standards boundary | [standards-and-grid-codes](standards-and-grid-codes.md) |

## Source anchors

- AEMO, *Voluntary Specification for Grid-Forming Inverters: Core Requirements
  Test Framework*, January 2024:
  https://www.aemo.com.au/-/media/files/initiatives/engineering-framework/2023/grid-forming-inverters-jan-2024.pdf
- UNIFI Consortium, *Specifications for Grid-Forming Inverter-Based Resources,
  Version 2*, NREL/TP-5D00-89269, 2024:
  https://www.nrel.gov/docs/fy24osti/89269.pdf
- NERC, *Grid Forming Functional Specifications for BPS-Connected Battery
  Energy Storage Systems*, White Paper, September 2023:
  https://www.nerc.com/globalassets/our-work/reports/white-papers/white_paper_gfm_functional_specification.pdf
- PNNL/WECC REGFM_A1 and REGFM_B1 public model work, 2024:
  https://www.pnnl.gov/publications/new-grid-forming-inverter-models-help-utilities-plan-renewable-future
- Local references listed above.
