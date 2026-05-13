# Virtual Impedance

Not a control law on its own — a modifier applied on top of droop/VSG/dVOC/PSC. The controller subtracts a virtual impedance drop from its voltage reference, making the inverter behave as if it had additional `R_v + jX_v` in series.

## Equation

In the dq frame:
```
v_ref_d  ←  v_ref_d  − R_v · i_d  + ω · L_v · i_q
v_ref_q  ←  v_ref_q  − R_v · i_q  − ω · L_v · i_d
```

In αβ:
```
v_ref_α  ←  v_ref_α  − R_v · i_α  + L_v · di_α/dt
v_ref_β  ←  v_ref_β  − R_v · i_β  + L_v · di_β/dt
```

The differential terms are usually replaced by a high-pass filter to avoid noise amplification:
```
HP(s) = (L_v · s) / (1 + s / ω_HP)         ω_HP > 10× outer-loop bandwidth
```

## Three uses

### 1. Q-sharing under mismatched line impedance

The dominant Q-sharing problem in paralleled droop GFMs is that `n_q · Q_i` depends on `X_line_i`. Adding the same `L_v` to all units swamps the line variation:
```
X_total_i = X_line_i + ω · L_v
```

For `L_v · ω ≫ X_line_variation`, the units see effectively the same line, and `Q_i` converges to `n_q · Q_total · (S_i / Σ S_j)`.

Tuning: `ω · L_v ≈ 0.05 to 0.15 pu` of the rated impedance. For the repo plant (`Z_base = 23 Ω`, `ω_n = 377`): `L_v ≈ 3 to 9 mH`. Note this is *in addition to* the physical `L_2 = 1 mH`.

### 2. Fault-current limiting

During a fault, `i` spikes. If `R_v` is large during the fault, the virtual drop `R_v · i_fault` pulls `v_ref` toward zero, naturally limiting current. Two flavors:

- **Constant `R_v`**: simple, but degrades steady-state V regulation.
- **Adaptive `R_v(|i|)`**: zero below the limit, ramps up above. Preserves steady-state, limits transient. Adaptive form is the modern choice (CPSS journal, IEEE TPEL 2024).

```
R_v(|i|) = R_v0 + K_R · max(|i| − I_limit, 0)
```

### 3. Decoupling P-V / Q-ω in resistive grids

In low-voltage feeders with R/X > 0.5, P and Q couple to ω and V together. Adding `L_v` (or `−R_v`, the "virtual capacitance") rotates the apparent line impedance toward inductive, restoring the droop sign conventions.

Equivalent: rotate the droop slopes by the line angle:
```
[Δω; ΔV] = [cos φ  sin φ; −sin φ  cos φ] · [m_p · ΔP; n_q · ΔQ]
```

where `φ = atan2(R_line, X_line)`. Virtual impedance achieves the same outcome but in plant-space rather than control-space.

## Implementation pitfalls

- **Algebraic loop**: if `v_ref` depends on `i`, and `i` depends on `v_ref` through the LCL, the simulator complains. Fix by inserting a one-step delay on `i` inside the controller, or use the HP-filtered form.
- **Differential `L_v · di/dt`**: pure differentiation amplifies noise. Always pair with HP filter.
- **R_v too large** at steady state: voltage regulation degrades (extra IR drop). Use adaptive form.
- **Algebraic loop with `R_d`**: passive damping `R_d` is *physical*, virtual `R_v` is *signal-space*. They don't conflict but they do add.

## When NOT to add virtual impedance

- Single inverter on a stiff grid — no sharing problem, no need.
- Inner V/I loops already in place with `R_v` baked in — don't double-count.
- Fault behavior is handled by hardware (e.g. crowbar circuit) — virtual impedance becomes redundant.

## Worked example (Q-sharing fix for `double/`)

Setup:
- Two GFMs at PCC, same droop slopes, same `S_rated`.
- Inverter 1 sees `X_1 = ω · 1 mH = 0.377 Ω` to the PCC.
- Inverter 2 sees `X_2 = ω · 1.5 mH = 0.566 Ω` to the PCC (50 % mismatch).
- At `Q_total = 5 kVAR`, without virtual impedance: `Q_1 ≈ 3.0 kVAR, Q_2 ≈ 2.0 kVAR` (33 % sharing error).

Add `L_v = 5 mH` to both:
- `X_total_1 = 0.377 + 1.885 = 2.262 Ω`
- `X_total_2 = 0.566 + 1.885 = 2.451 Ω` (only 8 % mismatch)
- New Q sharing: `Q_1 ≈ 2.6 kVAR, Q_2 ≈ 2.4 kVAR` (8 % sharing error)

Sharing error roughly proportional to the *ratio* of mismatch to total. Larger `L_v` improves sharing but reduces |V| at the PCC.

In `gfm_params.m`:
```matlab
p.R_v   = 0;        % no resistive virtual impedance unless fault limiting
p.L_v   = 5e-3;     % H, common to both GFMs
p.w_HP  = 2*pi*200; % HP cutoff for the differential term
```

The scaffold generator inserts the virtual-impedance subtraction inside the controller code when `p.R_v > 0` or `p.L_v > 0`.

## Cross-references

- Multi-unit sharing math: [multi-unit-sharing](multi-unit-sharing.md).
- Family-specific notes on where to inject the term: [droop-design](droop-design.md), [vsg-synchronverter-design](vsg-synchronverter-design.md), [dvoc-design](dvoc-design.md), [psc-design](psc-design.md).
- IEEE sources (Wang/Beerten/Belmans 2015 TPEL; adaptive form CPSS 2024): [bibliography](bibliography.md).
