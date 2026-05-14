# Droop Control Design

Standard P-ω / Q-V droop and its tuning rules.

## Equations (single inverter, dq frame)

Phase synthesis:
```
dθ/dt   = ω
ω       = ω_n − m_p · (P_filt − P_ref)
|V_ref| = V_peak − n_q · (Q_filt − Q_ref)
```

Power measurement (first-order LPF, the only "inertia" in droop):
```
τ_p · dP_filt/dt = P_inst − P_filt          τ_p = 1 / (2π · f_pwr_filt)
τ_p · dQ_filt/dt = Q_inst − Q_filt
P_inst = 1.5 · (V_d · I_d + V_q · I_q)
Q_inst = 1.5 · (V_q · I_d − V_d · I_q)
```

dq → abc voltage reference, then divide by `V_dc/2` to get the modulation index for a 2-level PWM block.

## Slope sizing

Express droop in percent of rated:
```
m_p = (Δω% / 100) · ω_n / S_rated     [rad/s per W]
n_q = (ΔV% / 100) · V_peak / S_rated  [V per VAR]
```

Typical values:
- `Δω% = 1` (matches synchronous-generator practice; tighter sharing, but slower swing)
- `ΔV% = 5` (relaxed because Q-sharing is naturally worse than P-sharing)

Baseline plant (60 Hz, 480 V LL, 10 kVA) used throughout these docs:
- `m_p = 0.01 · 2π·60 / 10000 ≈ 3.77e-5 rad/s/W`
- `n_q = 0.05 · 391.9 / 10000 ≈ 1.96e-3 V/VAR`

## Swing dynamics from the power LPF

The closed-loop P-θ dynamics around a stiff grid:
```
τ_p · d²θ/dt² + dθ/dt + m_p · (∂P/∂θ) · θ = m_p · P_ref
```

with `∂P/∂θ ≈ 1.5 · V_peak² / X_total` for an inductive coupling and `X_total = ω_n · (L_f + L_2 + L_g)`. The factor 1.5 comes from amplitude-invariant Park three-phase power (`P = 1.5·V_d·I_d` and `P = 1.5·V_peak²·sinδ/X` at the operating point). Keep this consistent with [inner-loops-and-lcl.md](inner-loops-and-lcl.md) and `gfm_smallsignal.m` — all three must use the same convention.

The undamped natural frequency and damping:
```
ω_swing = sqrt( m_p · (∂P/∂θ) / τ_p )
ζ_swing = 1 / (2 · sqrt( m_p · (∂P/∂θ) · τ_p ))
```

Design from `(ω_swing, ζ_swing)`:
```
m_p     given (% droop spec)
τ_p     = 1 / (2 · ζ_swing · ω_swing)
f_pwr_filt = 1 / (2π · τ_p)
```

Repo defaults: `f_pwr_filt = 5 Hz` → `τ_p ≈ 31.8 ms`. With repo's `m_p ≈ 3.77e-5` and `X_total ≈ 2.26 Ω` (i.e. `∂P/∂θ ≈ 1.5 · V_peak² / X_total ≈ 101.9 kW/rad`):
- `ω_swing ≈ sqrt(3.77e-5 · 101900 / 0.0318) ≈ 11.0 rad/s` (≈ 1.75 Hz)
- `ζ_swing ≈ 1 / (2 · sqrt(3.77e-5 · 101900 · 0.0318)) ≈ 1.43`

Overdamped, slow swing — conservative repo defaults. If you want an underdamped swing (ζ ≈ 0.5–0.7) for a faster step response, increase `f_pwr_filt` toward the bandwidth-ladder upper bound (see below). At `f_pwr_filt = 1 Hz` (τ_p ≈ 159 ms), the same plant gives ζ ≈ 0.64.

## Bandwidth ladder (necessary, not sufficient)

```
f_pwr_filt   ≪  f_outer_v   ≪  f_inner_i   ≪  f_sw / 2
   5 Hz          ~100 Hz         ~1 kHz         5 kHz
```

Inversions of this ladder cause:
- `f_inner_i ≥ f_sw/2` → inner loop chases PWM ripple
- `f_outer_v ≥ f_inner_i` → V loop fights its own current command
- `f_pwr_filt ≥ f_outer_v` → droop becomes oscillatory (no time-scale separation from inner loops)

The repo's outer V/inner I PI loops are skipped in the baseline droop variant (controller produces `m_abc` directly from `V_ref`). For tighter operating points, add them per `inner-loops-and-lcl.md`.

## Q-sharing under mismatched line impedance

For two droop GFMs with droop slopes `n_q1 = n_q2 = n_q` and line impedances `X_1 ≠ X_2` to the PCC:
```
Q_1 − Q_2  ≈  (V² / n_q) · (1/X_1 − 1/X_2) / 2   (steady state)
```

Even small `X` differences (a few percent) move Q-sharing by tens of percent. Mitigations, in order:
1. **Virtual impedance** — add `Z_v · i_d/q` subtraction in the V reference, matched across units (see `virtual-impedance.md`). This is the right fix.
2. **Tighter `n_q`** — reduces sharing error proportionally but at the cost of larger V deviation at full Q.
3. **Secondary control** — slow integral term that pushes Q to its setpoint. Adds an outer time scale, breaks the inertia abstraction.

## Q-axis sign convention pitfall

The repo uses amplitude-invariant Park with `Q_inst = 1.5 · (V_q · I_d − V_d · I_q)` (lagging current → Q > 0). If a paper or model uses the *other* sign convention, `n_q` flips polarity and the system goes unstable on the first Q deviation. Verify the sign of `Q_inst` in any new variant against this expression before tuning.

## When droop is the wrong choice

- Need RoCoF (`dω/dt`) bounds — `m_p · S_rated · f_pwr_filt` is the only "inertia" knob, and it is small. Use VSG.
- Need formal sync guarantees independent of topology — use dVOC.
- Operating at SCR < 2 — droop's reactive coupling becomes a P-V coupling and tuning gets unstable. Use PSC.

## Worked example (baseline 60 Hz / 480 V / 10 kVA plant)

Specs:
- 60 Hz, 480 V LL, 10 kVA, V_dc = 800 V
- LCL: L_1 = 4 mH, R_1 = 50 mΩ, C_f = 5 µF, R_d = 5 Ω, L_2 = 1 mH, R_2 = 50 mΩ
- Grid Z: L_g = 1 mH, R_g = 0.1 Ω → SCR ≈ V²/(ω · L_g · S) ≈ 1700 (stiff grid)
- Droop: 1 % ω at rated P, 5 % V at rated Q
- Resulting swing: `f_swing ≈ 1.75 Hz`, `ζ ≈ 1.43` (overdamped — conservative)

Result (exact formulas):
```matlab
p.m_p        = 0.01 * 2*pi*60 / 10e3;        % 3.7699e-5 rad/s/W
p.n_q        = 0.05 * sqrt(2)*480/sqrt(3) / 10e3;  % 1.9596e-3 V/VAR
p.f_pwr_filt = 5;                            % Hz  ->  ζ ≈ 1.43 at K_θ = 1.5·V²/X
```

## Cross-references

- Family overview and when to pick droop: [control-law-taxonomy](control-law-taxonomy.md).
- Inner V/I PI gains layered on top: [inner-loops-and-lcl](inner-loops-and-lcl.md).
- Q-sharing fix: [virtual-impedance](virtual-impedance.md), [multi-unit-sharing](multi-unit-sharing.md).
- VSG mapping (`D = 1/m_p`): [vsg-synchronverter-design](vsg-synchronverter-design.md).
- IEEE sources: [bibliography](bibliography.md).
