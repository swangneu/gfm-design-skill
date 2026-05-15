# Strong-Grid Stability

Grid-forming controls are often introduced as a remedy for weak-grid problems,
but high short-circuit ratio (SCR) is not automatically safe. A GFM inverter is
a controlled voltage source connected to another stiff voltage source. When the
coupling impedance is small, small angle or voltage errors can produce large
current and power swings.

This note captures the strong-grid checks that should accompany weak-grid SCR
checks.

## Mechanism

For an inductive Thevenin connection, active power is approximately:

```text
P ~= E * V / X * sin(delta)
```

Near an operating point:

```text
dP/delta ~= E * V / X
```

As `X` gets smaller, the synchronizing power stiffness rises. That can help
static power transfer, but it can also make droop, VSG, PSC, or dVOC states
over-react to small angle disturbances. In the limit, a nearly ideal voltage
source is pushing against a nearly ideal infinite bus.

The duality view in Li, Gu, and Green is a useful mental model: GFL controls
are vulnerable to weak-grid synchronization problems, while GFM controls can be
vulnerable to strong-grid interactions because their voltage-forming interface
is too stiff for the coupling impedance and inner-loop dynamics.

## Risk indicators

Treat these as prompts for a strong-grid check:

- SCR is high, or the model uses an infinite bus with very small `L_g`.
- Transformer leakage and feeder impedance are omitted or unrealistically low.
- Direct voltage reference is used with no inner current loop or virtual
  impedance.
- Power synchronization gain, droop gain, or VSG damping was tuned only for a
  weak-grid case.
- The model has fast outer voltage control fighting a nearly fixed PCC voltage.
- LCL resonance is close to inner-loop bandwidth or poorly damped.
- Connection tests include breaker closing with nonzero angle or voltage error.

## Mitigation levers

| Lever | Effect | Tradeoff |
|---|---|---|
| Virtual impedance | softens the voltage source and adds damping | reduces voltage stiffness and changes sharing |
| Lower power-sync gain | reduces response to small power errors | slower P/frequency response |
| Higher damping in VSG/PSC | improves oscillation damping | can reduce inertial feel or transient support |
| Inner current loop with limit | bounds current during hard-grid transients | needs anti-windup and bandwidth separation |
| Active LCL damping | damps filter modes without resistor loss | adds sensor/filter tuning |
| Pre-synchronization | reduces breaker-close transients | needs explicit connect sequence |

Virtual impedance should be part of the controller model, not a hidden external
line impedance. If it depends on measured current, include a discrete delay or
filtered implementation to avoid algebraic loops.

## Strong-grid test matrix

Run a grid-strength sweep alongside weak-grid tests:

| Sweep item | Suggested values |
|---|---|
| SCR | 2, 5, 10, 20, 50, infinite-bus approximation |
| X/R | project value plus low-R and high-R edge cases |
| Grid inductance | nominal, half nominal, one-tenth nominal |
| Virtual impedance | none, nominal, doubled |
| Power-loop gain | nominal, half, double |
| VSG damping | nominal, half, double |

Events:

- P and Q setpoint steps.
- Grid voltage magnitude step of +/-5% and +/-10%.
- Phase jump of +/-5, +/-10, and +/-20 electrical degrees.
- Breaker close with small voltage, frequency, and angle mismatch.
- LCL resonance disturbance or impedance scan.
- GFM plus GFL hybrid plant under the same events.

Log dominant pole damping, oscillation frequency, peak current, peak
modulation, settling time, and limiter activation. If a design is stable only
because current limiting is active during a nominal strong-grid event, the
nominal controller is not robust.

## Simulink-specific guidance

Avoid these modeling shortcuts:

- Ideal controlled voltage source directly connected to an ideal infinite bus.
- Zero transformer leakage.
- Removing filter resistance and damping "for simplicity".
- Treating `SCR = infinite` as a substitute for a high but finite grid model.

At minimum, keep the physical LCL, transformer leakage, feeder/grid impedance,
and measurement filters. If the study intentionally uses an infinite bus, label
it as a stress case and expect different dynamics from a realistic strong grid.

## Source anchors

- Li, Gu, Green, *Revisiting Grid-Forming and Grid-Following Inverters: A
  Duality Theory*, IEEE Transactions on Power Systems, 37(6):4541-4554, 2022,
  DOI: 10.1109/TPWRS.2022.3151851.
- Huang, Wu, Zhou, Blaabjerg, *A Simplified SISO Small-Signal Model for
  Analyzing Instability Mechanism of Grid-Forming Inverter under Stronger
  Grid*, IEEE COMPEL, 2021, DOI: 10.1109/COMPEL52922.2021.9646041.
- Ravanji, Rathnayake, Mansour, Bahrani, *Impact of Voltage-Loop Feedforward
  Terms on the Stability of Grid-Forming Inverters and Remedial Actions*, IEEE
  Transactions on Energy Conversion, 2023, DOI: 10.1109/TEC.2023.3246566.
- Local references: [virtual-impedance](virtual-impedance.md), [inner-loops-and-lcl](inner-loops-and-lcl.md), [control-law-taxonomy](control-law-taxonomy.md).
