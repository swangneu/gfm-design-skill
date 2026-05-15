# LVRT and Fault-Ride-Through

Low-voltage ride-through (LVRT) and broader fault-ride-through (FRT) are not
optional add-ons for grid-forming (GFM) design. A GFM inverter behaves as a
controlled voltage source, so a voltage sag naturally creates a large voltage
difference across the filter and grid impedance. Current limiting therefore
changes both protection behavior and synchronizing behavior.

This note defines a design and modeling checklist. It is not grid-code
compliance evidence.

## Why LVRT is different for GFM

Grid-following controls usually ride through by following measured grid angle
and commanding active/reactive current. GFM controls try to preserve an
internal voltage phasor. During a sag this raises four questions:

1. How much voltage-source behavior is preserved while current is limited?
2. Does the limiter keep the inverter synchronized or force a temporary
   current-source mode?
3. How are positive-sequence, negative-sequence, and per-phase currents limited
   during unbalanced faults?
4. What condition allows the controller to leave current-limiting mode after
   fault clearing?

UNIFI frames abnormal-event behavior with the priority order already used by
this repo: self-protection first, system stability second, return to setpoints
third. Recent LVRT reviews make the same point: current limiting is part of the
dynamic behavior, not a cosmetic clamp.

## Parameters to record

Add these assumptions when a user asks for LVRT/FRT behavior:

```matlab
p.lvrt_curve_pu_s          % [V_pu, t_s] breakpoints for low-voltage ride-through
p.hvrt_curve_pu_s          % [V_pu, t_s] breakpoints for high-voltage ride-through
p.vrt_voltage_measurement  % 'pcc_posseq_rms' | 'pcc_ll_rms' | 'min_phase_rms'
p.vrt_measurement_window_s % RMS/sequence measurement window
p.fault_current_priority   % 'reactive' | 'active' | 'balanced' | 'per_phase'
p.negative_sequence_mode   % 'none' | 'limit_only' | 'inject' | 'suppress'
p.momentary_cessation_allowed % true/false/project-specific
p.current_limit_exit_rule  % voltage recovery + hysteresis + dwell time description
p.lvrt_recovery_ramp       % P/Q/V/frequency state recovery rates
```

If these are unknown, the correct label is "nominal controller design only".

## Limiter choices during LVRT

| Limiter mode | GFM behavior during fault | Main risk |
|---|---|---|
| `virtual_impedance` | voltage source behind a larger impedance | tuning sets both current and voltage support; algebraic loop risk |
| `current_reference_saturation` | explicit current-source behavior inside cascaded V/I loops | outer voltage or power states can wind up |
| `voltage_reference_scaling` | reduced voltage-source stiffness | abrupt scaling can weaken synchronizing behavior |
| `mode_switch` | product-like normal/fault control modes | switching transient and recovery dominate the result |

For d-q limiters, clamp vector magnitude unless a phase-priority or
axis-priority requirement is explicit. For unbalanced faults, choose a
sequence-domain or per-phase strategy deliberately; a positive-sequence-only
limiter can miss phase overcurrent.

## Simulink LVRT/FRT test harness

Build LVRT/FRT as a scenario harness, not a manual disturbance hidden in a
source block. Minimum scenarios:

| Scenario | Purpose |
|---|---|
| Three-phase sag to 0.0, 0.2, 0.5, 0.7 pu | symmetric LVRT and current-limit entry |
| Single-line-to-ground fault | per-phase and negative-sequence current behavior |
| Line-to-line fault | unbalanced current and voltage recovery |
| Fault clearing with voltage overshoot | HVRT and limiter exit behavior |
| Phase jump at fault clearing | synchronizing-angle robustness |
| Weak and strong grid variants | limiter behavior across SCR and X/R |
| One unit limiting in a multi-unit plant | sharing breakdown and recovery |

Log at least:

```text
v_pcc_abc, v_pcc_posseq, v_pcc_negseq
i_abc, i_posseq, i_negseq, i_peak_per_phase
P, Q, theta_ctrl, omega_ctrl
m_abc, limiter_active, limiter_mode
V_dc, source_power_limit, breaker_status
```

Checks should include:

- No current exceeds `p.I_abs_max_peak`.
- Short-time current stays within `p.I_short_peak` for no longer than
  `p.t_short_limit`.
- Modulation stays within `p.m_max`.
- The controller does not integrate through a clipped voltage/current command.
- Current-limiting exit has hysteresis and dwell time.
- P/Q recovery ramps do not create a second current-limit event.
- Any claimed negative-sequence or per-phase behavior is visible in logs.

## Fault clearing and limiter exit

Fault clearing is often harder than fault entry. The controller should leave
current-limiting mode only after a documented condition is true, for example:

```text
V_pcc_posseq > V_exit_pu for t_exit_s
and I_peak < I_exit_peak
and modulation_margin > m_margin
and no phase current is above the per-phase limit
```

Use hysteresis between entry and exit thresholds. Reset or softly recover outer
voltage, power, and synchronverter/dVOC states so that stored error does not
cause a post-fault power swing.

## What to avoid saying

Do not claim LVRT compliance from parameter design alone. The strongest
allowable wording is:

> This parameter set records LVRT/FRT assumptions and limiter behavior to be
> validated in EMT simulation, HIL, and project-specific compliance review.

## Source anchors

- IEEE Std 2800-2022 public summary: https://standards.ieee.org/ieee/7003/10453/
  voltage/frequency ride-through, dynamic
  voltage support, negative-sequence current injection, and system protection
  are included in the standard scope.
- UNIFI Consortium, *Specifications for Grid-Forming Inverter-Based Resources,
  Version 2*, NREL/TP-5D00-89269, 2024:
  https://www.nrel.gov/docs/fy24osti/89269.pdf
- AEMO, *Voluntary Specification for Grid-Forming Inverters: Core Requirements
  Test Framework*, January 2024:
  https://www.aemo.com.au/-/media/files/initiatives/engineering-framework/2023/grid-forming-inverters-jan-2024.pdf
- Baeckeland, Chatterjee, Lu, Johnson, Seo, *Overcurrent Limiting in
  Grid-Forming Inverters: A Comprehensive Review and Discussion*, IEEE TPEL,
  39(11):14493-14517, 2024, DOI: 10.1109/TPEL.2024.3430316.
- Ordonez Murillo et al., *Current limiting strategies for grid forming
  inverters under low voltage ride through*, Renewable and Sustainable Energy
  Reviews, 202:114657, 2024, DOI: 10.1016/j.rser.2024.114657.
- Dolado Fernandez et al., *Low-Voltage Ride-Through Algorithm for
  Grid-Forming Converters*, IEEE TPEL, 40(1):303-315, 2025,
  DOI: 10.1109/TPEL.2024.3458193.
- Lyu, Du, Mohiuddin, Nandanoori, Elizondo, *Criteria for Grid-Forming
  Inverters Transitioning Between Current Limiting Mode and Normal Operation*,
  IEEE Transactions on Power Systems, 2024, DOI: 10.1109/TPWRS.2024.3402012.
- *A fault ride-through strategy for grid-forming converters under symmetrical
  and asymmetrical grid faults*, Electric Power Systems Research, 235:110672,
  2024, DOI: 10.1016/j.epsr.2024.110672.
- Local references: [current-limiting-and-protection](current-limiting-and-protection.md), [virtual-impedance](virtual-impedance.md), [inner-loops-and-lcl](inner-loops-and-lcl.md).
