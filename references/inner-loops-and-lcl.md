# Inner V/I Loops and LCL Design

The control-law (droop/VSG/dVOC/PSC) produces a voltage reference. How that reference becomes inverter terminal voltage is the job of the inner loops + filter. This reference holds for every family.

## Two layering options

**Option A — Direct voltage reference (the repo's current baseline)**

The controller computes `v_abc^ref` and applies it via PWM with no inner regulation. Current emerges through the filter from `(v_inv − v_grid) / Z_LCL`.

Pros: simple, no extra PI tuning, no overcurrent feedback path to mis-tune.
Cons: no current limiting, transient overshoot can exceed device ratings, no active damping for the LCL resonance.

Use when: stiff grid, conservative operating point, passive-damped LCL.

**Option B — Cascaded V (outer) + I (inner) PI on dq**

```
            ┌──────────┐   v_ref_dq    ┌──────────┐   i_ref_dq   ┌──────────┐
P/Q ───────►│ outer    ├──────────────►│ inner    ├─────────────►│ PWM      │
            │ V loop   │               │ I loop   │              │ (m_dq    │
            │ PI       │               │ PI       │              │  → m_abc)│
            └──────────┘               └──────────┘              └──────────┘
                  ▲                          ▲
                  │  v_pcc_dq                │  i_inv_dq
                  └──────────────────────────┘
```

Pros: explicit current limit, active LCL damping, well-defined bandwidth.
Cons: needs careful bandwidth separation, decoupling cross-terms, anti-windup.

Use when: tight current limit, weak grid, active damping required, or fault-ride-through needed.

## Bandwidth ladder

Every family must respect:
```
f_swing      <  f_outer_v  <  f_inner_i  <  f_LCL_res / 2  <  f_sw / 2
~few Hz         ~100 Hz       ~1 kHz        ~1.2 kHz          5 kHz
```

with each layer ≥ 5× faster than the one above it. The repo: `f_swing ≈ 1 Hz`, planned `f_outer_v ≈ 100 Hz`, `f_inner_i ≈ 1 kHz`, `f_LCL_res ≈ 2.5 kHz`, `f_sw = 10 kHz`. Holds.

## Inner current loop (dq frame)

Plant for each axis (decoupling included):
```
v_inv_d  = R_f · i_d + L_f · di_d/dt − ω · L_f · i_q + v_pcc_d
v_inv_q  = R_f · i_q + L_f · di_q/dt + ω · L_f · i_d + v_pcc_q
```

After decoupling (subtracting `±ω · L_f · i_{q,d}` and adding `v_pcc_{d,q}` feed-forward inside the PI block), the per-axis loop is:
```
G_plant(s) = 1 / (L_f · s + R_f)
```

A PI controller `C(s) = K_p + K_i / s` and pole-zero cancellation at `K_i/K_p = R_f/L_f` gives:
```
T(s) = K_p / (L_f · s + K_p)        // first-order, bandwidth = K_p / L_f
```

So the design is:
```
ω_bw_i  = 2π · f_inner_i              (target ~ 1 kHz)
K_p_i   = ω_bw_i · L_f                 // repo: 2π·1000 · 4e-3 ≈ 25.1
K_i_i   = ω_bw_i · R_f                 // repo: 2π·1000 · 0.05 ≈ 0.314
```

The repo already uses these formulas in `single/gfm_params.m`.

## Outer voltage loop

Plant: the capacitor branch `C_f` (with damping `R_d`) sees the current command from the inner loop. Per axis:
```
G_plant_v(s) ≈ (1 / (C_f · s + 1/R_d_eq)) · T_inner(s)
```

For most LCL filters, the C-branch low-frequency impedance is high enough that the dominant pole is at `1/(C_f · R_d_eq)` and the outer loop is approximately:
```
T_v(s) ≈ K_p_v / (1/ω_outer_v + K_p_v · (s / ω_inner_i + 1)^{−1})
```

A reasonable starting point:
```
ω_bw_v  = ω_bw_i / 10                  // 100 Hz target
K_p_v   ≈ ω_bw_v · C_f · V_dc          (depends on per-unit scaling)
K_i_v   ≈ K_p_v · ω_bw_v / 5
```

Repo's `single/gfm_params.m` uses `Kp_v = 0.5, Ki_v = 100` heuristically. For a tighter design pass:
```matlab
% From gfm_inner_loop_tuning.m
[Kp_i, Ki_i, Kp_v, Ki_v] = gfm_inner_loop_tuning(p, 'f_bw_i', 1000, 'f_bw_v', 100);
```

## LCL filter sizing

Per-phase LCL plant (RL on inverter side, C shunt with damping, RL on grid side):

```
Z_1(s) = R_f + L_f · s           // inverter-side (R_f = R_1, L_f = L_1)
Z_c(s) = R_d + 1/(C_f · s)       // shunt branch
Z_2(s) = R_2 + L_2 · s           // grid-side
```

Resonance (undamped, ignoring R):
```
L_eq    = L_f · L_2 / (L_f + L_2)
f_res   = 1 / (2π · sqrt(L_eq · C_f))
```

Design rules of thumb (Liserre/Blaabjerg/Hansen 2005, IEEE TIA):
1. `f_n · 10 < f_res < f_sw / 2`. Below 10·f_n the filter starts to attenuate the fundamental; above f_sw/2 it doesn't attenuate ripple.
2. Capacitor reactive at fundamental ≤ 5 % of S_rated: `C_f ≤ 0.05 · S / (ω_n · V_LL²)`.
3. Total inductance: `L_f + L_2 ≈ 0.05 to 0.15 pu` of base impedance `Z_base = V_LL² / S`.
4. Damping resistor `R_d` in series with `C_f`: `R_d ≈ 1 / (3 · ω_res · C_f)` for ~30% of critical at the resonance pole.

Repo plant:
- `L_eq = 4·1/(4+1) = 0.8 mH`, `f_res = 1/(2π·sqrt(0.8e-3 · 5e-6)) ≈ 2.52 kHz` ✓
- `C_f = 5 µF` → reactive at 60 Hz: `0.5 · ω · C · V_LL² ≈ 217 VAR` = 2.2 % of 10 kVA ✓
- `L_f + L_2 = 5 mH`, `Z_base = 480²/10000 = 23 Ω`, `pu = ω·L/Z_base = 8.2 %` ✓
- `R_d = 5 Ω`, recommended `≈ 1/(3·2π·2520·5e-6) ≈ 4.2 Ω` ✓

All four rules hold. The LCL is properly sized.

## Active LCL damping (instead of R_d)

Passive `R_d` burns power. Active damping injects a damping term inside the inner-loop controller. Two common forms:

1. **Capacitor-current feedback**: subtract `K_AD · i_C^{dq}` from the inner-loop voltage command. `K_AD ≈ ω_res · L_eq / (Q_target)` where `Q_target` ≈ 0.7 critical damping ratio at the resonance.
2. **Notch filter at f_res**: insert a notch in the inner-loop voltage command path. Simpler but less robust to plant variation.

Active damping eliminates the `R_d` losses but adds another tuning knob. The repo uses passive damping for simplicity — keep it unless losses are an explicit concern.

## Decoupling and feed-forward

Inside the inner I loop, the cross-coupling terms `±ω · L_f · i_{q,d}` and the grid-voltage feed-forward `v_pcc_{d,q}` should be added back at the PI output. Without them:
- Cross-coupling causes a P/Q interaction (transient ringing across axes).
- Missing feed-forward forces the I loop to fight grid disturbances at low frequency.

Most published designs include both. The repo's current scaffold leaves them out because the baseline runs with no inner loop. If adding inner loops, include both.

## Worked example (full cascaded inner/outer on repo plant)

```matlab
% Inner current loop (target 1 kHz)
ω_bw_i  = 2*pi*1000;
p.Kp_i  = ω_bw_i * p.L_f;        % ≈ 25.1
p.Ki_i  = ω_bw_i * p.R_f;        % ≈ 0.314 (small — R is tiny)

% Outer voltage loop (target 100 Hz)
ω_bw_v  = 2*pi*100;
p.Kp_v  = ω_bw_v * p.C_f * 100;  % scale factor depends on units; verify on Bode
p.Ki_v  = p.Kp_v * ω_bw_v / 5;

% Decoupling and feed-forward should be inside the controller code.
```

## Cross-references

- LCL diagnostic and waveform checks during sim are out of scope here — pair this skill with a three-phase-grid-inverter / SVPWM skill or do those checks manually (phase/line RMS balance, phase sum, DC offset, sector counts, gate-vs-plant gate equality).
- IEEE LCL design reference (Liserre/Blaabjerg/Hansen 2005): [bibliography](bibliography.md).
- Inner-loop gain computation script: `../scripts/gfm_inner_loop_tuning.m`.
