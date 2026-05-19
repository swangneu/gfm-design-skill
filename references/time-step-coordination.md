# Time-Step Coordination

A GFM Simulink model has at least four discrete rates that must be designed
together, not picked one at a time. Getting any of them wrong silently
distorts the controller dynamics and the steady-state operating point.

## The four rates

| Rate | Block / setting | Typical |
|---|---|---|
| `Ts_power` | `powergui` Discrete `SampleTime` | 0.1 - 2 us |
| `Ts_pwm`   | PWM Generator `Ts` (carrier sampling) | 0.1 - 2 us |
| `Ts_ctrl`  | controller block sample time          | 10 - 500 us |
| `f_pwr_filt` | power-measurement LPF cutoff        | 50 - 500 Hz |

These must satisfy two constraints:

1. **Switching resolution**: at least 10 samples per PWM period,
   `Ts_pwm <= 1/(10*f_sw)`. For `f_sw = 50 kHz`, that is `Ts_pwm <= 2 us`.
   Going finer (0.1 us) is cheap and removes carrier aliasing.
2. **Bandwidth ladder**: `f_pwr_filt << f_outer_v << f_inner_i << f_sw/2`,
   and the controller block must run fast enough to resolve its own
   bandwidth: `Ts_ctrl <= 1/(10*f_ctrl_BW)`.

The slower controller rate is intentional: power-stage transients live at
`Ts_power`; the controller does not need to (and should not) run that fast.

## The pitfall: inherited block sample time

A controller written in C, MATLAB, or Stateflow usually hardcodes its design
step somewhere - a `#define Ts 0.0001f`, a `Ts` parameter, an RK4 `dt`. The
block that hosts the controller in Simulink has its own sample time. If the
block runs faster than the design step, the integrator advances by
`dt_design` per call but the calls happen every `Ts_block`. Total advance is
`dt_design / Ts_block` times too fast.

Concrete failure observed: an Andronov-Hopf dVOC with `dt = 100 us` hardcoded
in a MATLAB Function block left at "inherited" Ts inside a model with
`Ts_power = 10 us` ran the controller 10x too fast. With `P* = Q* = 0` the
algorithm should drive current to zero; instead it settled with 37 A peak
phase current and a 30% over-amplitude voltage state. Forcing the block to
discrete `Ts = 1e-4` recovered the intended behaviour (7 A residual current,
voltage state tracking grid amplitude).

## Setting block sample time explicitly

**MATLAB Function block** - the default is inherited. To force discrete:

```matlab
rt = sfroot;
chart = rt.find('-isa', 'Stateflow.EMChart', 'Path', blockPath);
chart.ChartUpdate = 'DISCRETE';
chart.SampleTime = '1e-4';   % must match the algorithm's design dt
```

Setting `'SampleTime'` via `set_param` on the parent SubSystem fails - the
sample time lives on the underlying Stateflow chart.

**S-Function Builder block** - the discrete sample time is in the
Initialization tab. The C macro `#define Ts` does not propagate to Simulink;
the two must be set consistently by hand.

**S-Function (handwritten C)** - `mdlInitializeSampleTimes` declares the
rate. Hardcoding to `SAMPLE_TIME_CONTINUOUS` and then calling an RK4 with a
fixed `dt` is the same bug in C form.

## Symptoms of bad coordination

| Symptom | Likely cause |
|---|---|
| Current much higher than predicted with `P*=Q*=0` | controller running too fast (integrator over-advancing) |
| Oscillation at a frequency that scales with `Ts_block/dt_design` | implicit multi-rate instead of intended |
| Steady state achieved but V_inv amplitude is non-physical | limit cycle pushed off design point by aliased forcing |
| Blocky PWM ripple | `Ts_pwm` too coarse |
| Solver complains about algebraic loop | continuous + discrete signal entering algebraic block |

## S-Function Builder caveats

S-Function Builder generates `<name>.c`, `<name>_wrapper.c`, `<name>.tlc`,
`<name>.mexw64`, `rtwmakecfg.m`, and `SFB__<name>__SFB.mat`. These are build
artifacts, not source. They:

- Get out of sync with the algorithm if anyone edits them outside the
  `SFUNWIZ_*_Changes_BEGIN/END` markers.
- Reference absolute paths that break when the project moves.
- Bloat the working directory.

Recommendations:

1. Gitignore `*.mexw64`, `*.tlc`, `*_wrapper.c`, `rtwmakecfg.m`, `SFB__*.mat`.
2. Prefer **MATLAB Function blocks** for new controllers. They embed the
   algorithm in the .slx, work without C compilation, and codegen if Simulink
   Coder is licensed.
3. If S-Function Builder is needed (legacy code, third-party C library), keep
   the `<name>.c` source under version control and treat everything else as
   regeneratable.

## Porting S-Function Builder to MATLAB Function block

Verbatim algorithm preservation, idiomatic Simulink:

1. Copy the body of `<name>_Outputs_wrapper` into a MATLAB Function.
2. Move `Externs_BEGIN/_END` globals into a `persistent` declaration.
3. Replace `Start_wrapper` initialization with `if isempty(state); state = ...; end`.
4. Replace `float`/`double` macros with literals.
5. Map output pointers `*y0`, `*y1`, ... to the function's `[out0, out1, ...]` return list.
6. Set the chart's discrete `SampleTime` to match the C `#define Ts`.

## Cross-references

- [simulink-modeling-conventions](simulink-modeling-conventions.md): top-level layout, signal naming.
- [dvoc-implementation-conventions](dvoc-implementation-conventions.md): dVOC alpha-beta scaling.
- [inner-loops-and-lcl](inner-loops-and-lcl.md): bandwidth ladder math.
