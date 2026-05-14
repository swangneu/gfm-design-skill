# Power Synchronization Control (PSC)

Harnefors's family. Direct P → Δω synchronization with no measurement LPF, plus an outer voltage loop for magnitude. Tightest GFM under weak-grid / low-SCR conditions; commonly cited for HVDC stations and wind farms.

## State equations

```
dθ/dt   = ω_n + k_p · (P_ref − P)        // direct P-θ feedback, no LPF
v_ref^{dq}  determined by an outer V loop  (PI on |V| or on V_d/V_q)
v_ref^{abc} = dq → abc(v_ref^{dq}, θ)
m_abc       = v_ref^{abc} / (V_dc / 2)
```

The defining choice: **no power LPF**. P feeds the phase integrator directly. This is what gives PSC its speed in weak grids — at low SCR, droop's `f_pwr_filt` cutoff becomes a stability bottleneck because the LCL pole moves into the swing-loop bandwidth.

## Gain selection

The sync-loop gain `k_p` [rad/s/W] plays the same steady-state role as droop's `m_p`:
```
k_p_target = (Δω% / 100) · ω_n / S_rated
```

For 1 % ω droop on the repo plant: `k_p ≈ 3.77e-4 rad/s/W`.

But because PSC has no LPF, the open-loop P-θ transfer has *one* less pole than droop. The plant is roughly:
```
K_θ = ∂P/∂θ ≈ 1.5 · V_d · V_pcc / X_total   (W/rad, linearized)
```

so the open-loop has a single pole at the origin (the phase integrator) and a high-frequency lag from the LCL. The closed-loop crossover is approximately:
```
ω_c_sync ≈ k_p · K_θ
```

For the repo plant with `K_θ ≈ 102 kW/rad`: `ω_c_sync ≈ 3.77e-4 · 101900 ≈ 38.4 rad/s` (~ 6.1 Hz) at `k_p` matched to droop. Same order as droop's swing — at matched gain, PSC is not faster.

PSC's real advantage shows in **weak grids**: droop's power LPF places a pole at `−1/τ_p` that limits how high `m_p` can be pushed before the LPF pole and the LCL/grid coupling pole collide and erode phase margin. PSC has no LPF in the sync loop, so `k_p` can be raised 5–10× above the matched-droop value before its own margin limits bite (the dominant high-frequency limit becomes the LCL resonance, not a sync-internal pole). Aim for phase margin ≥ 45° at the resulting `ω_c_sync`, and add virtual-resistance damping if needed.

## Damping

PSC is structurally undamped at the sync loop (no LPF, no inertia). Three options:

1. **Virtual resistance** (Harnefors's choice): subtract `R_v · i_d/q` from `v_ref^{dq}` inside the controller. Acts as series damping. Pick `R_v` to give a phase margin ≥ 45° at `ω_c_sync`.
2. **High-pass damping**: subtract `(s · R_HP / (s + ω_HP)) · P` from the sync loop. Damps without affecting DC sharing.
3. **Inner current loop with active damping**: full cascaded control; loses some of PSC's simplicity.

For the repo plant, virtual resistance of `R_v ≈ 0.1 · X_total / (ω_n · L_f) ≈ a few hundred mΩ` is typical.

## Outer voltage loop

PSC doesn't have a Q-V droop built in. The magnitude reference is held by an outer loop, usually:
```
v_d_ref = V_peak                  // q-axis stays zero
v_q_ref = 0
```
plus a PI on `|V_pcc|` if Q-V regulation is needed. For pure GFM behavior in a stiff grid, just set `|v_ref| = V_peak` and let line drop happen.

For Q-V droop overlay, mimic the droop variant: `|v_ref| = V_peak − n_q · (Q − Q_ref)`.

## Pick PSC when

- SCR < 2 (weak grid) — droop becomes unstable, PSC remains stable.
- HVDC station or wind farm aggregation — historical reason: PSC matured in that domain.
- Need fast P tracking and the inertia abstraction isn't required.

## Avoid PSC when

- Need explicit `H` (inertia spec). Use VSG.
- Need formal Lyapunov sync proof. Use dVOC.
- Operating at SCR > 5 (stiff grid) — droop is simpler with no real downside.

## Comparison to droop in equations

```
Droop : ω = ω_n − m_p · P_filt(s)                            // P_filt = P / (1 + τ_p · s)
PSC   : ω = ω_n + k_p · (P_ref − P)                          // direct, no filter
```

If you set `k_p = m_p` and drop the LPF, droop becomes PSC. The sign convention difference (PSC uses `k_p · (P_ref − P)`, droop uses `−m_p · (P − P_ref)`) is the same thing written two ways.

## Worked example (PSC on the repo plant)

Specs:
- 60 Hz, 480 V LL, 10 kVA. Stiff grid (`L_g = 1 mH`, SCR ≈ 1700) — PSC isn't strictly needed but the design path still works.
- 1 % ω-droop equivalent.
- Phase margin target ≥ 45° at `ω_c_sync`.

```matlab
p.k_p   = 0.01 * p.w_n / p.S_rated;          % 3.77e-4 rad/s/W (matches droop slope)
p.R_v   = 0.5;                               % virtual resistance, Ω (tune)
p.V_ref = p.V_peak;                          % outer V-loop setpoint
p.Q_ref = 0;
% If Q-V droop overlay desired:
p.n_q   = 0.05 * p.V_peak / p.S_rated;
```

Plug the resulting `p` struct into a Simulink GFM model whose controller implements the PSC equations at the top of this doc.

## Cross-references

- Family overview: [control-law-taxonomy](control-law-taxonomy.md).
- Compared to droop: [droop-design](droop-design.md).
- Inner-loop options for damping: [inner-loops-and-lcl](inner-loops-and-lcl.md).
- IEEE source (Zhang/Harnefors/Nee 2010): [bibliography](bibliography.md).
