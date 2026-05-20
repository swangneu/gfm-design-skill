# Verified-Baseline Workflow

Forward design from specs (the main workflow in `SKILL.md`) is the right approach when no working model exists. But a different situation comes up often enough to need its own recipe: **a user already has a known-good Simulink/SPS model**, and the task is to change one thing (grid event, setpoint, scenario) without breaking everything else.

Rebuilding from scratch in that situation has destroyed many sessions. This note describes the alternative: clone the verified `.slx`, patch only what the scenario requires, and audit the result against the baseline before trusting it.

## When to prefer this workflow

Use clone-and-patch when **all** of the following hold:

- A verified Simulink model already exists (passes its own basic test).
- The change is small relative to the baseline: a new disturbance source, a new dispatch setpoint, additional logging.
- The baseline's algorithm, electrical topology, sample times, and signal tags are not being changed.

Use the forward-design workflow in `SKILL.md` instead when:

- No working baseline exists and you must produce one.
- The control law itself is changing (e.g. dVOC → VSG), or sample-rate / topology is changing.
- The user explicitly asks for a from-specs design.

## The patcher pattern

A typical patcher is one MATLAB function that:

1. Copies the baseline `.slx` to the working file name.
2. Loads the working model.
3. Replaces or adds **only** the scenario-specific blocks.
4. (If needed) regex-patches hardcoded literals inside MATLAB Function charts.
5. Saves and closes.

Skeleton:
```matlab
function mdl = make_scenario_from_template()
p = scenario_params();           % only scenario-specific parameters live here
copyfile(p.template_slx, p.scenario_slx);
load_system(p.scenario_slx);

% --- Patch 1: replace the grid source with a Programmable VS ---
oldSrc   = [p.mdl '/Three-Phase Source'];
oldVolt  = get_param(oldSrc, 'Voltage');     % keep baseline's LL RMS string
oldFreq  = get_param(oldSrc, 'Frequency');
oldPos   = get_param(oldSrc, 'Position');
peer     = capture_peers(oldSrc);            % record (block, port#) of each phase wire
delete_block(oldSrc);
add_block('powerlib/Electrical Sources/Three-Phase Programmable Voltage Source', ...
    [p.mdl '/Programmable_Grid_Source'], 'Position', oldPos);
set_param([p.mdl '/Programmable_Grid_Source'], ...
    'PositiveSequence', sprintf('[%s 0 %s]', oldVolt, oldFreq), ...
    'VariationEntity',  'Phase', ...
    'VariationType',    'Step', ...
    'VariationStep',    num2str(p.delta_theta_deg), ...
    'VariationTiming',  sprintf('[%g 1e6]', p.jump_time));
ground_new_neutral(p.mdl, 'Programmable_Grid_Source');   % see implementation conventions
reconnect_peers(p.mdl, 'Programmable_Grid_Source', peer);

% --- Patch 2: regex-patch the chart's hardcoded P, Q literals ---
chart = sfroot.find('-isa','Stateflow.EMChart','Path',[p.mdl '/Inverter/dVOC']);
chart.Script = regexprep(chart.Script, '(\<P\s*=\s*)[\+\-]?\d+\.?\d*\s*;', sprintf('$1 %.6g;', p.P_W));
chart.Script = regexprep(chart.Script, '(\<Q\s*=\s*)[\+\-]?\d+\.?\d*\s*;', sprintf('$1 %.6g;', p.Q_var));

save_system(p.mdl);
close_system(p.mdl, 0);
end
```

The pattern is intentionally narrow: capture before deletion, replace, reconnect by `(block, port_number)` pairs rather than by line handles. Stale line handles after `delete_block` are a common source of "could not find port" errors.

## What stays the same

When cloning, do **not** touch:

- The control-law algorithm (dVOC chart math, RK4 stepper, persistent state init).
- Electrical constants verified by the baseline (`V_dc`, `f_sw`, filter `R/L/C`, grid impedance).
- Sample times (`Ts_power`, `Ts_ctrl`, `Ts_pwm`) — including the multi-rate hierarchy.
- Existing Goto/From tags (`Vinv`, `Iinv`, etc.) and the To-Workspace logging that consumes them.
- The chart's persistent-state initial condition, **unless** the baseline IC is a saddle point (see `dvoc-design.md` Initialization warning).

Every constant you re-derive is one chance to introduce a `sqrt(2)` / `sqrt(3)` / unit error. The baseline carries them for free if you let it.

## What you can safely patch

- The grid source's *block type* (Three-Phase Source → Three-Phase Programmable VS) while preserving its `Voltage` / `Frequency` / `PhaseAngle` parameter strings verbatim.
- Hardcoded literals in MATLAB Function charts (regex on `P = <number>;`, `Q = <number>;`, setpoints) — but read `dvoc-implementation-conventions.md`'s warning about charts with literal constants before doing this.
- Adding new logging tags or new Scope blocks (purely additive).
- Adding a new disturbance block that *replaces* the original grid source's role (must add a neutral ground if the new block exposes one and the old one didn't — see `simulink-modeling-conventions.md`).

## Convention audit (do this before trusting the patched model)

After patching, before drawing conclusions from `sim()`:

1. **Query the new source's parameters.** `get_param(newSrc, 'PositiveSequence')` should match the baseline's `Voltage` (LL RMS) — verify by hand. Compute `V_phase_peak = V_LL_RMS * sqrt(2)/sqrt(3)` and check it equals the value you expect.
2. **Re-run the baseline scenario.** If the baseline's known-good test (`run_dvoc_basic` or equivalent) still produces the same `|V_pcc|` peak after patching, the algorithm and electrical chain are intact. If not, you broke something else.
3. **Verify hardcoded-literal patches stuck.** Print the chart script (`disp(chart.Script)` or open the chart in the GUI) and confirm the new `P`, `Q`, etc. values are there.
4. **Run the new scenario.** Settled `|V_inv|` should be near the grid phase peak under `P*=0, Q*=0`. With non-zero `P*`, the active-power balance is `P_3ph ≈ P*` and `|V_inv|` deviates only slightly from the grid peak.

If steady-state `|V_inv|` is off by `√2`, you've likely confused Phi-form vs Hopf-form (see `dvoc-design.md`). If it's off by `sqrt(3)/2 ≈ 0.866`, you've likely confused LL RMS vs phase peak in the source-block parameter.

## Cross-references

- Chart literal patching, source-block parameter audit, neutral-pin gotcha: [dvoc-implementation-conventions](dvoc-implementation-conventions.md).
- SPS source unit conventions and Yg/Yn neutral behavior: [simulink-modeling-conventions](simulink-modeling-conventions.md).
- Phi-form vs Hopf-form amplitude trap and saddle-point IC: [dvoc-design](dvoc-design.md).
- Pre-event settled-window verification on the validation side: companion `$gfm-validation` skill, `references/pre-flight-convention-audit.md`.
