# VSG and Synchronverter Design

Virtual synchronous machine family. Adds an explicit swing equation, giving emulated inertia and damping that droop only approximates via its measurement LPF.

## Swing-equation VSG

State equations:
```
J · dω/dt = P_ref − P − D · (ω − ω_n)        // mechanical swing
dθ/dt     = ω                                // phase integration
|V_ref|   = V_peak − K_q · (Q − Q_ref)       // reactive droop, proportional
```

`J` is virtual inertia [W·s²/rad], `D` is virtual damping [W·s/rad], `K_q` is Q-V slope [V/VAR].

## From inertia constant H to J

Power-system convention uses `H` (seconds, energy ratio):
```
H = (1/2) · J · ω_n² / S_rated     [s]
J = 2 · H · S_rated / ω_n²         [W·s²/rad]
```

Typical `H`:
- 2 – 5 s for emulating a small synchronous generator
- 0.5 – 2 s for low-inertia "synthetic inertia" services
- > 5 s is unusual for an inverter (energy buffer becomes a sizing constraint)

Baseline plant with `H = 2.0 s`: `J = 2·2·10000/(2π·60)² ≈ 0.281 W·s²/rad`.

## Equivalence to droop + LPF

Linearizing around the operating point and eliminating ω:
```
(J · s² + D · s) · θ = P_ref − P              (with P depending on θ through the line)
```

vs. droop with LPF:
```
(τ_p · s² + s) · θ = m_p · (P_ref − P)
```

so the equivalences are:
```
m_p_equiv  = 1 / D
τ_p_equiv  = J / D
H_equiv    = (1/2) · J · ω_n² / S = (1/2) · m_p_equiv · D · ω_n² / S  →  same swing dynamics
```

For a fair comparison against the droop baseline, set:
```matlab
m_p_target = 0.01 * w_n / S_rated;     % 1% ω-droop
D_vsg      = 1 / m_p_target;           % matches droop slope
J_vsg      = 2 * H * S_rated / w_n^2;  % choose H separately
```

This is exactly what `gfm_design_from_specs.m` writes into `p.D_vsg` and `p.J_vsg` when `'law','vsg'`.

## Design from desired swing dynamics

Pick `(ω_n_swing, ζ_swing)` for the closed-loop second-order P-θ response. Linearizing around an inductive line with `K_θ = ∂P/∂θ ≈ 1.5 · V_d · V_pcc / X_total`:

```
J · s² + D · s + K_θ = 0
ω_n_swing = sqrt( K_θ / J )
ζ_swing   = D / (2 · sqrt( J · K_θ ))
```

Solve in this order:
1. Choose `H` (or `J`) from system-level inertia spec.
2. Choose `ζ_swing` (typical 0.5 – 0.7).
3. `D = 2 · ζ_swing · sqrt(J · K_θ)`.
4. Check `ω_n_swing` is well below the inner-loop bandwidth.

If the resulting `D` violates a droop spec (e.g. `1/D ≠ m_p_target`), the inertia spec and droop spec are mutually inconsistent — pick one as the binding constraint and document.

## Q-V loop options

Two common choices:

**Option 1 — proportional droop** (`gfm_design_from_specs` default for `'law','vsg'`):
```
|V_ref| = V_peak − K_q · (Q − Q_ref)
K_q     = (ΔV%) · V_peak / S_rated
```
Simple. Steady-state V error proportional to Q deviation.

**Option 2 — synchronverter flux integrator** (Zhong & Weiss):
```
M_f · di_f/dt = (1/K_v) · (Q_ref − Q − D_q · (V_meas − V_ref))
|V_inv|       = ω · M_f · i_f
```
Integral action on V; no steady-state error. `K_v` and `D_q` set Q-V bandwidth and damping. Needs anti-windup.

Default to Option 1 unless the user requires zero steady-state V error.

## Bandwidth ladder (same as droop)

```
ω_n_swing  ≪  ω_outer_v   ≪  ω_inner_i   ≪  ω_sw / 2
```

Note that VSG's effective `ω_n_swing = sqrt(K_θ/J)` can be much *higher* than droop's `1/sqrt(τ_p · m_p · K_θ)` if `H` is small. Recheck the ladder after choosing `H` — small `H` makes VSG behave less like droop.

## Stability red flags

- **Low D, high J** → swing pole pair near the imaginary axis, ringing on every step.
- **D ≫ matched droop value** → loses the inertia abstraction; becomes droop with extra latency.
- **`ω_n_swing` close to LCL resonance** → swing transient excites the LCL. Increase passive damping or move the resonance.
- **Synchronverter without anti-windup** → flux integrator saturates on transient and the controller never recovers.

## Worked example (baseline plant, two paralleled VSGs)

Specs:
- Same plant as droop baseline (60 Hz, 480 V LL, 10 kVA, LCL as before).
- Match droop's 1 % ω slope: `m_p_target = 3.77e-5 rad/s/W`.
- `H = 2 s`.
- Q-V: 5 % proportional droop.

```matlab
p.H_inertia = 2.0;
p.J_vsg     = 2 * p.H_inertia * p.S_rated / p.w_n^2;     % ≈ 0.281 W·s²/rad
m_p_target  = 0.01 * p.w_n / p.S_rated;
p.D_vsg     = 1 / m_p_target;                            % ≈ 2.65e4 W·s/rad
p.K_q       = 0.05 * p.V_peak / p.S_rated;               % ≈ 1.96e-3 V/VAR
```

Resulting swing (with `K_θ ≈ 67.9 kW/rad` from the droop worked example):
- `ω_n_swing = sqrt(67900 / 0.281) ≈ 491 rad/s ≈ 78 Hz`
- `ζ_swing = 26500 / (2 · sqrt(0.281 · 67900)) ≈ 96`

That `ζ` is enormous because `D` matched a *slow* droop. The VSG is essentially first-order P-θ at this `H` — almost identical to droop with a much smaller `τ_p`. If the user wants real second-order swing dynamics, decouple `D` from `m_p_target` and use the `(ω_n_swing, ζ_swing)` design path above.

## Cross-references

- Family overview: [control-law-taxonomy](control-law-taxonomy.md).
- Droop equivalence: [droop-design](droop-design.md).
- Inner-loop layering: [inner-loops-and-lcl](inner-loops-and-lcl.md).
- IEEE sources (D'Arco/Suul/Fosso, Zhong/Weiss, Bevrani/Ise): [bibliography](bibliography.md).
