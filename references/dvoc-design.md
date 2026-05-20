# dVOC Design

Dispatchable Virtual Oscillator Control. Nonlinear oscillator with a stable limit cycle in αβ. Synchronizes by physics, gives global stability guarantees, and reduces to droop on the slow manifold.

## State equations (αβ frame)

State: `v = [v_α; v_β] ∈ ℝ²`. Measured grid current in αβ: `i = [i_α; i_β]`.

```
v̇ = ω_n · J · v + η · R(κ) · (K(v) − i) + η · α · Φ(v) · v
```

where
```
J        = [0 −1; 1  0]                       // 90° rotation generator
R(κ)     = [cos κ  −sin κ; sin κ  cos κ]      // rotation for grid impedance angle
                                              // κ = π/2 for purely inductive line
K(v)     = (2 / (3 · V*²)) · [P*  Q*; −Q*  P*] · v   // dispatch current ref (αβ)
Φ(v)     = (V*² − ‖v‖²) / V*²                  // magnitude regulation toward V*
V*       = V_peak  (rated peak phase voltage)
P*, Q*   = setpoints
η > 0    = synchronization gain
α > 0    = magnitude-regulation gain
```

The controller's job is to integrate this ODE in real time. Output `v` is the inverter voltage reference (use inverse Clarke to get `v_abc`, then `m_abc = v_abc / (V_dc/2)`).

## Why each term

- `ω_n · J · v` — the oscillator rotates at `ω_n` when undriven. This is the "phase clock".
- `η · R(κ) · (K(v) − i)` — synchronization term. Drives `i` toward `K(v)`, which encodes `(P*, Q*)`. The rotation `R(κ)` aligns the actuator with the dominant line impedance angle so the wrong axis isn't excited.
- `η · α · Φ(v) · v` — magnitude regulation. Pushes `‖v‖² → V*²`. Φ is positive when undervolted, negative when over.

## Slow-manifold equivalence to droop

For small deviations around `‖v‖ = V*`, ω ≈ ω_n, P ≈ P*:
```
Δω    ≈ (2η / (3 · V*²)) · (P* − P) // P-ω droop slope, amplitude-invariant power
Δ‖v‖  ≈ (1 / (3 · α · V*)) · (Q* − Q) // Q-V droop slope
```

So to match a target percent-droop `(Δω%, ΔV%)`:
```
m_p_target = (Δω% / 100) · ω_n / S_rated
n_q_target = (ΔV% / 100) · V_peak / S_rated

η = (3/2) · m_p_target · V_peak²      [matches the 2/(3·V*²) dispatch-current convention]
α = 1 / (3 · n_q_target · V_peak)     [units: 1/s]
```

Baseline plant numbers (`gfm_design_from_specs('law','dvoc', ...)`):
- `m_p_eq = 0.01 · ω_n / S_rated ≈ 3.77e-4`
- `n_q_eq = 0.05 · V_peak / S_rated ≈ 1.96e-3`
- `η_droop = 1.5 · m_p_eq · V_peak² ≈ 86.9`
- `α = 1 / (3 · n_q_eq · V_peak) ≈ 0.435`

## η-scaling for paralleled units

Two GFMs sharing a PCC create a diff-mode loop through `2·L_2 + 2·R_2`. At the operating point `Q=0, ‖v‖=V*`, the Φ term contributes no damping. The effective P-ω slope `2η/(3·V*²)` is then competing only with `R_2` for damping the differential current.

`gfm_design_from_specs` de-tunes `η` automatically for the 2-inverter case via `eta_scale`:
```matlab
p.eta_scale = 0.25;
p.eta       = p.eta_scale * 1.5 * m_p_eq * V_peak^2;
```

Rules of thumb:
- 1 unit, stiff grid: full `η` (no scaling).
- 2 units paralleled, stiff grid: `η · 0.25` to `η · 0.5`.
- 2+ units paralleled and/or weak grid: scale further and add an LPF on `i` (cutoff ~500 Hz) inside the controller. The repo does this.

## κ (rotation angle)

`κ = π/2` for inductive lines (R/X → 0). For resistive/mixed lines:
```
κ = atan2(X_line, R_line)
```

For a typical 60 Hz LCL with `X = ω · L_2 ≈ 0.377 Ω` and `R_2 = 50 mΩ`: `κ ≈ atan(0.377/0.05) ≈ 1.44 rad ≈ 82.4°`. Close enough to π/2 that the default holds.

If `R_line / X_line > 0.3` (low-voltage / resistive feeders), recompute `κ` — otherwise P-Q coupling worsens.

## Discrete-time integration pitfall

Forward Euler on `ω_n · J · v` *inflates* `‖v‖²` by `(1 + (ω_n · Ts)²)` per step. With `ω_n = 377`, `Ts = 1e-4` → 0.14 % growth per step → divergence in tens of cycles.

Fix (the repo does this):
```
% Replace forward Euler on the oscillator term with an exact rotation:
v_rot = [cos(ω_n·Ts) −sin(ω_n·Ts); sin(ω_n·Ts) cos(ω_n·Ts)] · v
v_new = v_rot + Ts · (η · R(κ) · (K(v) − i) + η · α · Φ(v) · v)
```

Magnitude-preserving on the unforced rotation; Euler only on the bounded control terms.

## Initialization

Start at rated magnitude, zero phase, to avoid a startup transient through the LCL:
```
v_α(0) = +V_peak;   v_β(0) = 0
```

This is `‖v‖² = V*²` → `Φ = 0` → no initial magnitude correction, and the inverter phasor is aligned with a `cos(ω_n t)` grid at `t = 0`. The oscillator begins at the right limit cycle, aligned with the grid.

**Saddle-point warning.** `v_α(0) = −V_peak, v_β(0) = 0` is 180° from a cosine grid. With the current-feedback term active it is a *saddle* of the closed-loop synchronization dynamics: the radial direction stabilizes quickly but the angular direction escapes only when the discrete integration introduces enough numerical noise (or an external perturbation arrives). The system can sit near 180° for hundreds of ms and then escape suddenly. Symptoms:

- Pre-disturbance window statistics are noise (δ near ±180°, P/Q ringing).
- Post-disturbance settles cleanly because the disturbance kicks the state off the saddle.

If a third-party reference implementation hardcodes `−V_peak` (as `template/dvoc_basic.slx` does), flip the sign before using it in a phase-jump / load-step scenario. Reproducing the reference's startup waveform is *not* the same scenario as testing post-event recovery from a settled state.

## Form variants: Phi-form vs Andronov-Hopf-form

The same control law appears in two algebraic shapes in the literature. They are equivalent under a redefinition of constants, but they read very differently when ported between codebases:

**Phi-form** (this reference, dVOC paper, Colombino/Groß/Dörfler):
```
v̇ = ω_n·J·v + η·R(κ)·(K(v) − i) + η·α·Φ(v)·v
Φ(v) = (V*² − ‖v‖²) / V*²
```
Autonomous limit cycle: `‖v‖ = V*`. Set `V* = V_peak` directly.

**Andronov-Hopf form** (C-code implementations, Johnson/Dhople 2014, some lab reference models):
```
ẋ = 2ksy·x − ω_n·y − (ksy/kv²)·(x²+y²)·x − (kv·ki/Cap)·u₁
ẏ = ω_n·x + 2ksy·y − (ksy/kv²)·(x²+y²)·y − (kv·ki/Cap)·u₂
```
Autonomous limit cycle: `‖(x,y)‖ = √2·kv` (the factor-of-2 in front of `ksy` doubles the equilibrium of `2 − norm²/kv²`).

**The trap.** A comment that says "`kv = Vnom = V_peak`" sounds right but produces a limit cycle at `√2·V_peak ≈ 1.41·V_peak`, which is then dragged toward the grid voltage by the current feedback. If you assume Phi-form semantics (limit cycle = `kv`) when the code is Hopf-form, your predicted amplitude is off by `√2` and your dispatch loop sits at the wrong operating point.

Equivalence map:
```
η      ↔ 2·ksy
V*     ↔ √2·kv
K(P*,Q*)v − i  ↔ −(1/η)·(kv·ki/Cap)·[u₁; u₂] with (u₁,u₂) = (i_β_ref − i_β, i_α − i_α_ref)
                  (this u-form implicitly chooses κ = π/2)
```

When reading a reference implementation:
- Run the autonomous law (set `P*=Q*=0`, disconnect grid, integrate) and read the steady `‖v‖`. If it equals the `kv`/`Vnom` constant, it's Phi-form. If it equals `√2·kv`, it's Hopf-form.
- Cross-check against the radial-gain literal: a `2·ksy·x` term *without* a matching `2/V*²` in the squared-norm factor is the giveaway.
- Some implementations expose `Vnom = V_peak / √2` so the Hopf limit cycle lands at `V_peak`; others expose `Vnom = V_peak` and accept the `√2·V_peak` limit cycle as the design target. Both are valid; just don't mix them.

## Current feedback LPF

`i` (the measured grid-side current) carries PWM ripple. Without an LPF, the ripple enters the dispatch loop and the oscillator chases it. Typical fix: a first-order LPF at 500 Hz inside the controller code:
```
α_i = 2π · 500 · Ts / (1 + 2π · 500 · Ts)
i_αf ← i_αf + α_i · (i_α − i_αf)
i_βf ← i_βf + α_i · (i_β − i_βf)
```

Set the cutoff above the swing frequency (~tens of Hz) but well below `f_sw/2`.

## Stability red flags

- `η` too large → diff-mode oscillation between paralleled units. Scale down (`eta_scale`) or add the current LPF.
- `α` too large → magnitude overshoot on startup or after a grid voltage step. Limit to 1 – 10 typical.
- κ wrong sign or wrong magnitude → P feedback ends up on the Q axis, system goes unstable on first power deviation.
- Forward Euler on the rotation → drift in `‖v‖`, eventual divergence.

## When dVOC is the wrong choice

- Need explicit `H` for inertia spec — use VSG. dVOC has no analogue of `H`.
- Mixed R/X line with unknown `κ` and no online adaptation — droop or PSC degrades gracefully; dVOC does not.
- Hard real-time on a low-end controller — dVOC's per-step trig and matrix ops are heavier than droop. Profile first.

## Worked example (baseline plant, two paralleled dVOC units)

Specs:
- Same plant as droop/VSG baselines.
- Match 1 % ω, 5 % V droop slopes at rated.
- 2 inverters paralleled.

```matlab
m_p_eq      = 0.01 * p.w_n / p.S_rated;        % 3.77e-4
n_q_eq      = 0.05 * p.V_peak / p.S_rated;     % 1.96e-3
p.kappa     = pi/2;                            % inductive grid
p.eta_scale = 0.25;                            % de-tune for 2-unit parallel
p.eta       = p.eta_scale * 1.5 * m_p_eq * p.V_peak^2;   % ≈ 21.7
p.alpha     = 1 / (3 * n_q_eq * p.V_peak);     % ≈ 0.435
```

## Cross-references

- Implementation conventions for Simulink/switching models:
  [dvoc-implementation-conventions](dvoc-implementation-conventions.md).
- Family overview: [control-law-taxonomy](control-law-taxonomy.md).
- Droop slope formulas it matches: [droop-design](droop-design.md).
- Sharing under mismatched line Z: [multi-unit-sharing](multi-unit-sharing.md).
- IEEE sources (Colombino/Groß/Dörfler 2019, Johnson/Dhople/Krein 2014): [bibliography](bibliography.md).
