# GFM Test Scenarios

This note lists simulation scenarios that should be run outside this skill
after a parameter design is handed to a Simulink or EMT model. The skill does
not call `sim()` and does not turn these scenarios into evidence by itself.

## Scenario groups

| Group | Scenarios | Why it matters |
|---|---|---|
| Nominal operation | enable, P step, Q step, load step | checks signs, droop slopes, power filters, settling |
| Grid-strength sweep | SCR 2/5/10/20/50, X/R sweep | catches weak-grid and strong-grid interactions |
| LVRT/FRT | 3-phase sag, SLG, LL, fault clearing | checks current limit, sequence behavior, recovery |
| Frequency events | frequency step, ramp, RoCoF | checks droop/VSG frequency support and limiter interaction |
| Voltage events | voltage step, phase-angle jump, HVRT | checks synchronizing stiffness and modulation headroom |
| Multi-unit sharing | unequal line impedance, one unit limiting | checks P/Q sharing and saturation breakdown |
| Plant energy limits | DC-link sag, BESS power limit, PV curtailment | checks source constraint and recovery behavior |
| Connection sequence | pre-sync, breaker close, islanding, resync | checks hard-grid transient and state initialization |

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
