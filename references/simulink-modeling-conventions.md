# Simulink Modeling Conventions

This note defines how a Simulink or Simscape Electrical model should consume a
`gfm_params.m` struct produced by this skill. It is a handoff contract, not a
claim that a generated model has been validated.

## Preferred deliverables

Do not treat a binary `.slx` file as the only output. A readable handoff should
include:

1. `gfm_params.m` with all numerical assumptions and units.
2. A reproducible build script such as `build_gfm_model.m` if a model skeleton
   is generated.
3. `model_notes.md` or an equivalent header explaining topology, measurement
   points, Park transform convention, limits, and unsupported claims.
4. Optional `model_manifest.json` or MATLAB struct listing model version,
   controller law, sample times, standard targets, and source documents.

This follows the same idea as MathWorks programmatic modeling guidance: use
scripts for repeatable construction (`new_system`, `add_block`, `add_line`,
`set_param`) and use modeling guidelines for readability, naming, and review.

## Top-level diagram

Keep the top level readable. A typical GFM model should have no more than these
major subsystems visible at the root:

| Subsystem | Purpose |
|---|---|
| `DC_Link_Source` | DC bus source, source limits, optional energy/SOC dynamics |
| `Power_Stage` | universal bridge or averaged converter, PWM, modulation limits |
| `LCL_Filter_Grid` | `L_f`, `C_f`, `R_d`, `L_2`, transformer or line impedance, grid source |
| `Measurements` | voltage/current sensors, RMS/sequence/Park transforms, filtering |
| `GFM_Controller` | droop/VSG/dVOC/PSC states and voltage reference generation |
| `Protection_Limits` | current limiting, modulation limiting, anti-windup, recovery logic |
| `Scenario_Events` | load steps, faults, voltage dips, frequency ramps, breaker commands |
| `Logging_Checks` | logged signals and simple limit assertions |

Avoid hiding electrical assumptions in unnamed blocks. Every subsystem should
have a short annotation or mask description that states its physical role and
units.

## Signal naming and units

Use explicit signal names. Prefer names that carry frame and units:

| Signal | Meaning |
|---|---|
| `v_pcc_abc_V` | measured phase-to-neutral PCC voltage in volts |
| `i_grid_abc_A` | grid-side phase current in amps |
| `i_inv_abc_A` | inverter-side filter current in amps |
| `v_pcc_dq_V` | Park-transformed PCC voltage |
| `i_grid_dq_A` | Park-transformed grid-side current |
| `theta_ctrl_rad` | controller internal electrical angle |
| `omega_ctrl_radps` | controller internal angular frequency |
| `p_inst_W`, `q_inst_var` | instantaneous active/reactive power using the documented convention |
| `m_abc_pu` | bridge modulation command, per unit of `V_dc/2` |

The repo assumes amplitude-invariant Park and peak phase quantities unless a
model explicitly documents a different convention. If a model uses RMS dq
values or power-invariant Park, the P/Q formulas and droop gains must be
adapted before using the parameter struct.

## Time-base contract

Record these sample times before tuning:

```matlab
p.Ts_power   % electrical network / powergui step
p.Ts_ctrl    % controller execution step
p.Ts_pwm     % PWM carrier or averaged-converter update step
p.f_sw       % switching frequency for a switching model
p.f_pwr_filt % power-measurement LPF cutoff
```

The expected bandwidth ladder is:

```text
power/swing dynamics << outer voltage loop << inner current loop << LCL resonance << switching frequency
```

For a switching EMT model, `Ts_power` must be small enough to resolve the
switching and LCL dynamics. For an averaged model, the same control sample-time
contract should still be preserved so that later switching-model migration does
not silently change controller behavior.

## Average model vs switching model

Use both when possible:

| Model type | Use for | Main limitation |
|---|---|---|
| Averaged converter | control-law exploration, small-signal sweeps, fast test matrices | hides PWM ripple, dead time, saturation timing, and gate ordering |
| Switching EMT | current spikes, LVRT, LCL damping, PWM saturation, protection timing | slower and more sensitive to solver/sample-time choices |

The design skill can hand off parameters to either model, but it does not prove
that the bridge, PWM, or measurement implementation is correct.

For dVOC-specific alpha-beta scaling, `eta_scale`, PWM handoff, and sign checks,
read [dvoc-implementation-conventions](dvoc-implementation-conventions.md)
before retuning gains.

## Controller boundary

The baseline contract is:

- Inputs: measured `v_pcc_abc_V`, measured `i_grid_abc_A` or `i_inv_abc_A`,
  DC-link voltage if used, and optional enable/fault/reset commands.
- State owner: one controller block should own droop/VSG/dVOC/PSC states,
  filters, anti-windup states, and recovery ramps.
- Output: `m_abc_pu` in `[-p.m_max, p.m_max]` or a voltage reference that a
  documented inner-loop subsystem converts to `m_abc_pu`.

If inner V/I loops are separate Simulink subsystems, the boundary must state
which block owns current-reference limiting and which block receives the
anti-windup feedback.

## SPS source-block unit conventions

> Scope: Simulink / SPS specific. Applies to any control law, not just dVOC.

Both `Three-Phase Source` and `Three-Phase Programmable Voltage Source` from `powerlib/Electrical Sources` take their amplitude as **line-to-line RMS**, not LL peak, not phase peak.

| Block | Amplitude parameter | Interpretation |
|---|---|---|
| `Three-Phase Source` | `Voltage` | LL RMS in volts |
| `Three-Phase Programmable Voltage Source` | `PositiveSequence(1)` | LL RMS in volts |
| `AC Voltage Source` (single-phase) | `Amplitude` | Peak in volts |

For a 3-phase model that should produce `V_phase_peak` at the PCC, set `Voltage = V_phase_peak * sqrt(3) / sqrt(2)` (equivalently `V_phase_RMS * sqrt(3)`). A `Voltage` string like `100/sqrt(2)*sqrt(3) ≈ 122.47` produces `V_phase_peak = 100 V`, not `70.7 V` — even though the literal expression *looks* like it computes a peak quantity. The SPS interpretation rules.

If a model comment says "V peak LL" beside an SPS source literal, query the block (`get_param(src,'Voltage')`) and recompute the expected phase peak with the actual block convention before trusting the comment.

A factor of `sqrt(3/2) ≈ 0.866` between predicted and simulated voltage almost always traces back to this trap.

## Source-of-truth: query the actual SPS block

> Scope: Simulink / SPS specific. Applies to any model handoff, not just dVOC.

When handed a verified Simulink/SPS model, do not trust the README, model comments, or block annotations about what the source/measurement blocks contain. Query the blocks directly:

```matlab
get_param('mdl/Three-Phase Source', 'Voltage')                  % LL RMS string
get_param('mdl/Three-Phase Source', 'Frequency')                % Hz
get_param('mdl/Three-Phase Source', 'PhaseAngle')               % deg (sine convention)
get_param('mdl/Three-Phase Source', 'InternalConnection')       % 'Y'/'Yn'/'Yg'/'Delta'
get_param('mdl/Programmable_Grid_Source', 'PositiveSequence')   % '[V_LL_RMS phase_deg freq_Hz]'
```

The audit takes seconds and catches the `sqrt(3/2)`, `sqrt(2)`, and `sqrt(3)` voltage-amplitude family of errors before they look like a control-law tuning problem. Do this on every inherited model before drawing any tuning conclusion.

## SPS source neutral pin (Yg vs Yn)

> Scope: Simulink / SPS specific. Applies to any control law that uses a programmable grid source for disturbance injection.

`Three-Phase Source` with `InternalConnection='Yg'` is internally grounded and has no exposed neutral pin (3 external connections). `Three-Phase Programmable Voltage Source` exposes a neutral pin (`LConn(1)`) regardless of its `Network Connection` setting. When swapping these blocks programmatically:

```matlab
% After replacing the Three-Phase Source with a Programmable VS,
% add a Ground to LConn(1) to avoid 'voltage source short-circuited'.
add_block('powerlib/Elements/Ground', [mdl '/Grid_Neutral_Ground'], 'Position', ...);
add_line(mdl, ...
    get_param([mdl '/Grid_Neutral_Ground'],'PortHandles').LConn(1), ...
    get_param([mdl '/Programmable_Grid_Source'],'PortHandles').LConn(1), ...
    'autorouting','on');
```

The same caution applies in reverse if you ever replace a Programmable VS with a Three-Phase Source: delete the now-unused Ground.

## MATLAB Function chart literals

> Scope: Simulink-level rule (applies to any MATLAB Function chart, not just dVOC). For dVOC-specific literals worth searching for, see `dvoc-implementation-conventions.md`.

Constants declared at the top of a MATLAB Function chart's script are evaluated at compile time:

```matlab
function y = myChart(u)
%#codegen
gain = 1.5;        % literal — locked at compile time
y = gain * u;
end
```

Wiring a new value through a `Constant` block to a new input port does **not** override these literals. Two paths:

1. **Patch the script via the Stateflow API.** Lowest risk if you're working from a verified baseline.
   ```matlab
   chart = sfroot.find('-isa','Stateflow.EMChart','Path','my_model/Inverter/Ctrl');
   chart.Script = regexprep(chart.Script, '(\<gain\s*=\s*)[\+\-]?\d+\.?\d*\s*;', '$1 2.5;');
   ```
2. **Refactor the chart to accept a parameter input.** Higher risk: changes the chart's signature, sample-time inheritance, and (if you change the persistent-state size) the initial-condition behavior.

When generating a new chart from a `gfm_params` struct, prefer (2) from the start: pass `p.ctrl_vec` or per-field inputs so the chart can be retuned at run time without script surgery.

## Electrical topology details to keep visible

Do not collapse these into an undocumented impedance:

- Transformer leakage or feeder impedance between inverter and PCC.
- Grid impedance used to set SCR and X/R.
- Filter damping resistor or active damping path.
- Whether the measured current is inverter-side, capacitor, or grid-side.
- Breaker location used for grid connection and islanding tests.
- Fault location and fault impedance for LVRT/FRT tests.

For strong-grid cases, never connect a controlled ideal voltage source to an
ideal infinite bus through zero impedance. Include at least the physical filter,
transformer leakage, feeder impedance, or an explicit virtual impedance.

## Readability checklist

Before handing a model to a user, check:

- Top-level subsystems are named by physical role, not implementation detail.
- Signal names are shown across subsystem boundaries.
- Units and frames are visible in names or annotations.
- Goto/From tags are local and sparse; cross-hierarchy signal jumps are avoided.
- Critical MATLAB Function blocks have header comments listing inputs, outputs,
  units, sample time, and persistent state.
- All saturation blocks have matching anti-windup or a documented reason they
  are output-only monitors.
- Test events are disabled by default or clearly controlled by a scenario
  selector.
- Logged signals include current, voltage, P/Q, modulation, controller angle,
  frequency, limiter status, and DC-link variables.

## Source anchors

- MathWorks, *Programmatic Modeling Basics*: https://www.mathworks.com/help/simulink/ug/approach-modeling-programmatically.html
- MathWorks, `add_block`: https://www.mathworks.com/help/simulink/slref/add_block.html
- MathWorks, `add_line`: https://www.mathworks.com/help/simulink/slref/add_line.html
- MathWorks, *MAB Modeling Guidelines*: https://www.mathworks.com/help/simulink/mab-modeling-guidelines.html
- MathWorks, *Modeling Guidelines for Subsystems*: https://www.mathworks.com/help/ecoder/ug/modeling-guidelines-for-subsystems.html
- UNIFI Consortium, *Specifications for Grid-Forming Inverter-Based Resources, Version 2*, NREL/TP-5D00-89269, 2024.
- Local references: [inner-loops-and-lcl](inner-loops-and-lcl.md), [current-limiting-and-protection](current-limiting-and-protection.md), [standards-and-grid-codes](standards-and-grid-codes.md).
