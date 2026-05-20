# dVOC Steady-State Diagnosis: Vstar Matching and Filter Losses

Use this reference when a dVOC simulation reports a steady-state P that
is within a few percent of the dispatch P* but does not match it (e.g.
P_set = 5 kW, P_pcc = 4.66 kW). Two routine contributors explain almost
all such offsets **before any controller retuning**. Treating this as a
gain problem will burn iterations and not converge.

## Pattern signature

- Steady-state |P_pcc| is within ±10% of |P_set|, sign correct.
- Q_pcc is small or matches Q_set, sign correct.
- Voltages and currents balanced, fundamental dominant, no limiter
  activity.

If all of the above hold, the controller is functioning. Diagnose the
offset in the order below before touching gains.

## 1. Vstar–grid voltage mismatch

AHO-dVOC dispatch is voltage-dependent:

```text
i_ref = (2/(3 * Vstar^2)) * [ P* ,  Q* ;
                              -Q*, P*  ] * v
```

At `||v|| = Vstar` the dispatch delivers exactly `(P*, Q*)`. For a stiff
grid (negligible Rg, Lg), `v_pcc ≈ v_grid`, so `||v||` ≈ `V_grid_peak`
(the grid's phase-peak voltage). If the controller's internal `Vstar`
differs from `V_grid_peak`, the delivered active power scales as:

```text
P_pcc ≈ P_set * (V_grid_peak / Vstar)^2
```

| Vstar | V_grid_peak | (V_grid/Vstar)^2 | offset vs P_set |
|---|---|---|---|
| 69.28 V | 100/sqrt(2) = 70.71 V | 1.0417 | +4.2% |
| 70.71 V | 70.71 V | 1.0000 | 0.0% |
| 80 V | 70.71 V | 0.7812 | −21.9% |

**Where Vstar hides in typical handoffs:**

- A Stateflow chart's `Vstar`, `Vnom`, or `kv` constant — commonly
  hardcoded in chart text rather than read from base/Model Workspace.
- A MATLAB Function block local.
- A generated-C-code constant from an AHO oscillator that was designed
  for a different grid voltage than the current one.

**Diagnosis recipe:**

1. Read the actual `Vstar` constant from wherever the controller stores
   it: a Stateflow chart script (`chart.Script` via `sfroot`), a MATLAB
   Function block (right-click → Edit), an S-Function source file, or
   a generated-C-code header. Do not assume the value matches the
   parameter struct — it often does not.
2. Measure the actual grid phase peak from settled-window data:
   ```matlab
   V_grid_peak = sqrt(2) * mean(rms(v_pcc(settled_idx, :)));
   ```
3. Compute predicted offset: `(V_grid_peak / Vstar)^2`.
4. If predicted matches observed (±1%), recommend a `Vstar` patch, not
   a gain retune.

## 2. Filter ohmic losses

The dispatch boundary is at the inverter terminal (upstream of the
filter inductor). Validation typically measures P at PCC (downstream).
The difference is the filter ohmic loss:

```text
P_loss_filter ≈ 3 * Rf * I_rms^2
```

For balanced 3-phase with apparent power |S| = sqrt(P^2 + Q^2):

```text
I_peak  ≈ (2 * |S|) / (3 * V_grid_peak)
I_rms   = I_peak / sqrt(2)
P_loss  ≈ (2 * Rf * |S|^2) / (3 * V_grid_peak^2)
```

At unity power factor `|S| = P_set`. With Q ≠ 0 the loss scales with
the apparent power, not just P, because filter current carries both
P and Q components.

Sanity values for `V_grid_peak = 70.71 V`, `P_set = 5 kW`:

| Rf | I_rms | P_loss | % of P_set |
|---|---|---|---|
| 0.01 Ω | 34 A | 34 W | 0.7% |
| 0.05 Ω | 34 A | 170 W | 3.4% |
| 0.20 Ω | 34 A | 680 W | 13.6% |

Add switching losses (typically 1–3% for Si IGBTs at moderate fsw) if
the model includes a switching bridge rather than an averaged one.

## Combined predicted P_pcc

```text
P_pcc ≈ P_set * (V_grid_peak / Vstar)^2  −  P_loss_filter  −  P_loss_switching
```

If observed `P_pcc` matches this prediction within ~1%, no controller
change is warranted. If residual mismatch remains, return to the
gfm-design retune workflow.

## Hand-off note for gfm_params

When the design produces a parameter struct for a dVOC switching model:

- Set `p.dvoc.Vstar = V_grid_peak` explicitly. Do not use
  `V_LL_RMS_nominal`, do not use `V_phase_RMS`.
- Include `p.filter.R_f` and `p.filter.L_f` so the validation skill can
  predict and subtract the loss analytically.
- If the dVOC implementation is a Stateflow chart or generated-C-code
  module where `Vstar` is baked in, attach a one-line note in the
  parameter handoff:
  > `Vstar in chart is X V (vs grid V_phase_peak = Y V). Patch chart or
  > accept (Y/X)^2 ≈ Z% P offset.`

This converts a "very clear error" pattern from a vague mystery into a
predictable, calculable offset that does not waste validation iterations.
