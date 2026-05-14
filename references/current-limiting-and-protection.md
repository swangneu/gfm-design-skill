# Current Limiting and Protection Envelope

This reference defines the protection assumptions that must accompany any
grid-forming control design. It is not a protection relay guide and it is not
evidence of grid-code compliance. Use it to keep the nominal GFM design inside
the converter ratings before EMT simulation, HIL, and independent review.

## Rating fields

Record these values in `gfm_params.m` whenever the user provides device limits:

```matlab
p.I_rated_peak      % peak phase current at S_rated and V_LL_rms
p.I_cont_peak       % continuous peak phase current limit
p.I_limit_peak      % software current-limiter pickup
p.I_short_peak      % short-time current capability
p.t_short_limit     % allowed duration at I_short_peak
p.I_abs_max_peak    % absolute do-not-exceed current
p.m_max             % usable modulation-index ceiling, <= 1
p.current_limit_mode
```

The default `gfm_design_from_specs.m` values are placeholders for design-space
screening: `I_cont_peak = 1.0 pu`, `I_limit_peak = 1.2 pu`, `I_short_peak =
1.5 pu`, `t_short_limit = 2 s`, `I_abs_max_peak = I_short_peak`, and
`m_max = 0.98`. Replace them with device data before relying on any overload
or fault behavior.

Rated peak phase current follows the same convention as the rest of the skill:

```matlab
I_rated_peak = S_rated * sqrt(2) / (sqrt(3) * V_LL_rms)
```

For a predicted operating point:

```matlab
I_peak_est = sqrt(P^2 + Q^2) * sqrt(2) / (sqrt(3) * V_LL_rms)
```

Use the lower of nominal `V_LL_rms` and predicted PCC voltage when screening
undervoltage events, because voltage sag raises current for the same apparent
power.

## Priority order during abnormal events

For faults, phase jumps, voltage steps, and frequency events, use this priority
order:

1. Self-protection: do not exceed current, energy, DC-link, thermal, or
   modulation limits.
2. System stability: preserve GFM behavior and predictable voltage/frequency
   support as far as the hardware limits allow.
3. Setpoint optimality: return to active/reactive power setpoints after the
   event only after protection and stability objectives are satisfied.

This matches the UNIFI GFM specification direction and is consistent with the
current-limiting literature: the limiter is part of the GFM dynamic behavior,
not a cosmetic output clamp.

## Limiter modes

Choose and document one limiter mode before simulating severe disturbances.

| Mode | Use when | Main risk |
|---|---|---|
| `none` | Nominal design, stiff grid, no fault claims | No current protection in the controller model |
| `virtual_impedance` | Need GFM-like voltage source behavior under faults | Voltage support depends strongly on `R_v(|i|)` tuning |
| `voltage_reference_scaling` | Direct-voltage controller with no inner current loop | May weaken phase/voltage stiffness abruptly |
| `current_reference_saturation` | Cascaded V/I controller with explicit current reference | Can destabilize or desynchronize the outer GFM loop if anti-windup is weak |
| `mode_switch` | Product-style behavior with separate normal/fault controls | Switching transients and recovery logic dominate behavior |

For d-q current limiting, clamp the vector magnitude, not each axis
independently, unless phase-priority behavior is explicitly intended:

```matlab
scale = min(1, I_limit_peak / max(norm([i_d_ref, i_q_ref]), eps));
i_d_ref = scale * i_d_ref;
i_q_ref = scale * i_q_ref;
```

For three-phase unbalanced faults, a positive-sequence-only limiter is not
enough. Decide whether the controller regulates balanced internal voltage,
injects negative-sequence current, or limits per-phase current first. This
choice is site- and product-specific and must be validated in EMT simulation.

## Anti-windup requirements

Any limiter that clips voltage or current must feed back to integrators:

- Inner current PI: freeze or back-calculate when `v_inv_ref` saturates.
- Outer voltage PI: freeze or back-calculate when `i_ref` is clipped.
- Droop/VSG/dVOC/PSC power states: prevent setpoint-tracking integrators or
  secondary loops from integrating through a current-limited fault.
- Synchronverter flux/voltage integrators: clamp internal energy states and
  provide a defined reset or soft-recovery path.

If anti-windup is absent, the post-fault recovery may be worse than the fault
itself, even when all nominal small-signal poles are stable.

## Design checks before handoff

Run these checks before giving the user a parameter struct:

1. Continuous loading: `sqrt(P_ref^2 + Q_ref^2) <= S_rated` for every unit,
   unless an overload case is intentionally being designed.
2. Predicted current: `gfm_predict_steady_state` should keep `I_peak_est <=
   I_cont_peak` for nominal load.
3. Short-time headroom: disturbance cases should not require more than
   `I_short_peak` for longer than `t_short_limit`.
4. Modulation headroom: `V_ref_peak / (V_dc/2) <= m_max`.
5. Sharing validity: if any unit is current-limited or modulation-limited, the
   linear P/Q sharing formulas no longer apply.
6. Recovery: after a limited event, the design must specify how references,
   filters, and integrators return to nominal operation.

## EMT cases to run outside this skill

This skill does not run `sim()`. A credible validation pass should include:

- Nominal setpoint step and load step.
- Three-phase bolted fault and cleared fault.
- Single-line-to-ground or line-to-line fault with per-phase current limits.
- Voltage magnitude step and positive-sequence phase jump.
- Frequency excursion and ROCOF event.
- DC-link or source power limit event for BESS/PV/HVDC sources.
- Multi-unit case where one unit reaches a limit before the others.

## Cross-references

- Standards map: [standards-and-grid-codes](standards-and-grid-codes.md).
- Virtual-impedance limiter hook: [virtual-impedance](virtual-impedance.md).
- Inner-loop current-reference limiting: [inner-loops-and-lcl](inner-loops-and-lcl.md).
- Sharing breakdown under saturation: [multi-unit-sharing](multi-unit-sharing.md).
