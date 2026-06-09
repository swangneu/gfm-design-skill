# Validation Feedback Loop

Use this reference when a user brings back a `gfm-validation` report, validation table, or simulation-log comparison and asks what to change in the design.

## Boundary

`gfm-validation` owns running `sim()`, extracting logs, computing pass/fail checks, and writing validation reports. `gfm-design` owns design updates after those results are interpreted.

Do not rerun or reinterpret raw simulations here unless the task is explicitly about retuning or design assumptions. If the user only wants log extraction, plotting, report generation, or pass/fail comparison, send them to `gfm-validation`.

## Triage order

1. **Check the comparison contract**
   - Are P, Q, f, V, current, and modulation measured at the same boundary assumed by the prediction?
   - Are units correct: Hz vs rad/s, line-line RMS vs phase peak, W/VAR signs, peak current vs RMS current?
   - Does the settled window exclude startup, reference steps, fault-on intervals, and limiter recovery?
   - If any answer is no, fix logging/windowing in `gfm-validation` before retuning.

2. **Check whether the scenario exceeds design assumptions**
   - Current limit or modulation limit active.
   - LVRT/FRT, unbalanced fault, or per-phase limiting in scope.
   - Strong-grid/high-SCR or weak-grid/SCR assumptions differ from `p`.
   - Load, reference, Q demand, grid impedance, or DC-link limit differs from the original specs.
   - If yes, update the protection envelope, grid assumptions, and scenario notes before changing control gains.

3. **Classify the design mismatch**
   - P-sharing error: revisit `m_p`, multi-unit references, line impedance mismatch, and virtual impedance.
   - Q/V error: revisit `n_q`, Q sign convention, line impedance, and virtual impedance.
   - Frequency final value error: revisit P reference, load definition, `m_p`, and Hz/rad/s conversion.
   - Poor damping or oscillation: revisit `f_pwr_filt`, VSG `H`/`D`, PSC damping/virtual resistance, inner-loop bandwidths, and LCL resonance.
   - Current headroom failure: reduce P/Q request, revise current limits, add limiter mode assumptions, or select a protection-aware scenario.
   - Modulation saturation: check `V_dc`, `V_peak`, `m_max`, voltage reference scaling, and available headroom.

4. **Update the design**
   - State exactly which validation finding motivates the change.
   - Change the smallest set of specs or gains that addresses the mismatch.
   - Recompute dependent fields through `gfm_design_from_specs.m` or the relevant helper instead of editing one field by hand.
   - Regenerate `gfm_predict_steady_state` and, when relevant, `gfm_smallsignal`.
   - Tell the user to rerun `gfm-validation` on the same scenario and any newly relevant stress case.

## Report-back template

Use this shape when processing validation feedback:

```text
Validation feedback triage:
- Comparison contract: pass/fail/uncertain, with signal or unit notes.
- Assumption status: nominal / current-limited / modulation-limited / LVRT/FRT / strong-grid / model mismatch.
- Design action: no retune, retune fields X/Y/Z, or update model/logging first.
- New prediction: P/Q/f/V/current headroom and small-signal poles if relevant.
- Next validation: scenario(s) to rerun with gfm-validation.
```

Do not claim the redesign is verified until the updated simulation report comes back clean.
