# Multi-Unit P/Q Sharing

How droop / VSG / dVOC / PSC distribute power across paralleled units, and when the math says you need virtual impedance or secondary control.

## P-sharing (the easy case)

With matched droop slopes `m_p_i` and a common bus frequency `ω`, the steady-state active power per unit is:
```
P_i  =  P_ref_i  +  (ω_n − ω) / m_p_i
```

Sum over `N` units:
```
P_total  =  Σ P_ref_i  +  (ω_n − ω) · Σ 1/m_p_i
        =  P_load  (steady state)
```

Let `Δω = ω_n − ω` (frequency drop from rated). Solving:
```
Δω  =  (P_load − Σ P_ref_i) / Σ 1/m_p_i
```

and each unit takes:
```
P_i  =  P_ref_i  +  (Δω / m_p_i)
```

Check: under overload (`P_load > Σ P_ref`), `Δω > 0`, frequency drops below rated, and each unit picks up *more* than its setpoint. That matches the physical droop behavior — every doubt about a sign in this file resolves to this check.

For matched `m_p`: each unit's share of *load mismatch* is proportional to `1/m_p_i` (= proportional to `S_rated_i` if you sized droop per unit). **P-sharing is good** because frequency is a global variable — every unit sees the same `ω` regardless of line impedance.

## Q-sharing (the hard case)

Voltage is *local*. Each unit sees a different `V_pcc_i` because of the drop across its line impedance:
```
V_pcc_i  ≈  |V_inv_i|  −  X_i · Q_i / |V_inv_i|       (inductive line, |V| ≈ rated)
```

Q-V droop sets `|V_inv_i| = V_peak − n_q_i · Q_i`. Solving for `Q_i` with a common PCC voltage `V_pcc`:
```
Q_i  =  (V_peak − V_pcc) / (n_q_i  +  X_i · V_peak / |V_inv|²)
     ≈  (V_peak − V_pcc) / (n_q_i  +  X_i / V_peak)
```

The line term `X_i / V_peak` appears alongside the droop slope. If `X_i / V_peak` is comparable to `n_q_i`, Q-sharing is line-dominated, not droop-dominated.

For the repo's plant: `n_q = 0.05 · V_peak / S_rated ≈ 1.96e-3 V/VAR`. Line term: `X_2 / V_peak = ω · 1e-3 / 392 ≈ 9.6e-4 Ω/V ≈ same order`. So a small line mismatch is comparable in magnitude to the droop slope — Q-sharing will be sensitive.

### Sharing-error formula

Define mismatch `Δ_i = X_i − X_avg`. Linearizing:
```
Q_i_actual − Q_i_ideal  ≈  −(Δ_i / V_peak) · (Q_i_ideal − V_peak² / X_avg) / (n_q + X_avg/V_peak)
```

In practice: 10 % `X` mismatch → 20–30 % Q-sharing error.

## When P-sharing also breaks

P-sharing breaks down when:

1. **Frequency is not common** — different inverters use different local references (e.g. PLL-based GFL units mixed in). Doesn't happen in pure-GFM clusters.
2. **Resistive lines** (R/X > 0.5) — droop's P-ω and Q-V coupling rotates. P sees the R, ω sees R/X-mixed. Use virtual impedance to rotate back.
3. **Saturation** — one unit hits its `m_abc` limit or its current limit. The remaining units pick up the load through their droop. This is *intentional* but breaks the linear sharing math.

When saturation or current limiting is expected, switch from this analytical
sharing model to the protection-envelope workflow in
[current-limiting-and-protection](current-limiting-and-protection.md) and EMT
simulation.

## Mitigations (in order of preference)

### 1. Match line impedances by adding virtual `L_v`
See [virtual-impedance](virtual-impedance.md). Doesn't change steady-state V at rated Q; mostly cosmetic for the inverter's local point but globally improves sharing.

### 2. Tighten `n_q` (steeper Q-V slope)
```
Sharing error  ≈  Δ_i / (V_peak · n_q + X_avg)
```
Doubling `n_q` halves the sharing error — at the cost of doubling the steady-state V deviation at rated Q. Sometimes acceptable.

### 3. Secondary Q control
Adds an outer integral loop on `Q_i − Q_ref_i`. Slow time scale (seconds). Useful in microgrid management but breaks the inertia abstraction in transients.

```
n_q_i_effective(t)  ←  n_q_i_nominal  +  K_sec · ∫(Q_i − Q_ref_i) dt
```

Anti-windup mandatory.

### 4. Communication-based sharing (consensus)
Each unit shares its `Q_i` with neighbors and converges to a consensus value. Adds a comms requirement; gives near-perfect sharing. Out of scope for primary control.

## Predicted vs. simulated sharing

A common surprise: predicted Q-sharing from droop slopes is way off from simulated. Causes, in order of likelihood:

1. Forgot to include the line impedance term `X_i / V_peak` — the droop slope alone overpredicts how much each unit takes.
2. Q sign convention is wrong (`Q = 1.5(V_q I_d − V_d I_q)` vs. the opposite) — sharing inverts.
3. One unit is saturating `m_abc` or hitting an internal voltage limit — sharing collapses to the other unit.
4. Power LPF cutoffs differ between units — transient phase brings up sharing error that decays slowly.

Use `gfm_predict_steady_state.m` to check the *predicted* sharing analytically before sim. If predicted and simulated disagree by more than a few percent, find the cause before tuning — do not paper over the gap by re-tuning droop slopes until the numbers match.

## Worked example (two-unit droop, mismatched lines)

Setup:
- Two units, identical `m_p = 3.77e-4, n_q = 1.96e-3, S_rated = 10 kVA`.
- `P_ref_1 = 5 kW, P_ref_2 = 3 kW`, both `Q_ref = 0`.
- Line: `X_1 = ω · 1 mH = 0.377 Ω`, `X_2 = ω · 1.5 mH = 0.566 Ω` (50% mismatch).
- Load on the AC bus: roughly `P_total = 8 kW`, `Q_total = 5 kVAR`.

Predicted:
```
Δω  = (P_load − P_ref_1 − P_ref_2) / (2 · 1/m_p)
    = (8000 − 8000) / (2 / 3.77e-4)
    = 0          (P-share follows setpoints exactly)
P_1 ≈ 5000 W,  P_2 ≈ 3000 W      // matches P_ref
```

```
With line dominance term ≈ n_q (both 2e-3 ish):
Q_1 / Q_2  ≈  (n_q + X_2/V_peak) / (n_q + X_1/V_peak)
           ≈  (2e-3 + 1.4e-3) / (2e-3 + 0.96e-3)
           ≈  1.15
Q_1 ≈ 2.7 kVAR,  Q_2 ≈ 2.3 kVAR   // ~15% sharing error
```

After adding `L_v = 5 mH` to both:
```
X_total_1 = 0.377 + 1.885 = 2.262 Ω
X_total_2 = 0.566 + 1.885 = 2.451 Ω
Q_1 / Q_2 ≈ (n_q + X_total_2/V_peak) / (n_q + X_total_1/V_peak) ≈ 1.04
Q_1 ≈ 2.6 kVAR,  Q_2 ≈ 2.4 kVAR    // ~4% sharing error
```

The validation skill computes this from sim logs (`gfm_check_sharing.m`).

## Cross-references

- Virtual impedance fix: [virtual-impedance](virtual-impedance.md).
- Droop family math: [droop-design](droop-design.md).
- VSG/dVOC sharing inherit droop's analysis on the slow manifold: [vsg-synchronverter-design](vsg-synchronverter-design.md), [dvoc-design](dvoc-design.md).
