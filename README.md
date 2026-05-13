# gfm-design

A [Claude Code](https://claude.com/claude-code) skill for designing grid-forming (GFM) inverter controllers in MATLAB/Simulink + Simscape Electrical.

## What it does

When invoked, the skill helps you:

- **Choose** a GFM control law (droop / VSG / synchronverter / dVOC / PSC) from system specs.
- **Tune** the law-specific gains (m_p, n_q, J, D, H, η, α, κ, k_p, virtual impedance, inner V/I PI) using analytical formulas grounded in IEEE Transactions literature.
- **Predict** steady-state ω_pcc, V_pcc, and per-inverter P/Q sharing *before* running a simulation.
- **Generate a full variant scaffold** — `gfm_params.m` + `build_*.m` + `run_*_sim.m` — that drops into a Simulink workflow and produces a runnable `.slx`.

It is paired (conceptually) with a separate validation skill that closes the loop after simulation. This repo only contains the design skill.

## Coverage

Control laws covered with self-contained math + worked examples:

| Family | Law | Reference doc |
|---|---|---|
| Droop | P-ω / Q-V droop | [droop-design.md](references/droop-design.md) |
| Droop | Power Synchronization Control (PSC) | [psc-design.md](references/psc-design.md) |
| VSM | Swing-equation VSG | [vsg-synchronverter-design.md](references/vsg-synchronverter-design.md) |
| VSM | Synchronverter (Zhong/Weiss) | [vsg-synchronverter-design.md](references/vsg-synchronverter-design.md) |
| Oscillator | dVOC (Colombino/Groß/Dörfler) | [dvoc-design.md](references/dvoc-design.md) |
| Cross-cutting | Virtual impedance | [virtual-impedance.md](references/virtual-impedance.md) |
| Cross-cutting | Inner V/I PI on LCL | [inner-loops-and-lcl.md](references/inner-loops-and-lcl.md) |
| Cross-cutting | Multi-unit P/Q sharing | [multi-unit-sharing.md](references/multi-unit-sharing.md) |

Decision tree across all laws: [control-law-taxonomy.md](references/control-law-taxonomy.md). Full IEEE bibliography: [bibliography.md](references/bibliography.md).

## Install

Drop the entire `gfm-design/` directory into your project under `.claude/skills/`:

```
your-project/
├── .claude/
│   └── skills/
│       └── gfm-design/
│           ├── SKILL.md
│           ├── references/
│           └── scripts/
└── ...
```

Claude Code will auto-discover the skill on startup. Invoke it by mentioning a GFM-design task or by typing `/gfm-design`.

## Use without Claude Code

The MATLAB scripts under [scripts/](scripts/) are standalone and run from any MATLAB ≥ R2024b with Simscape Electrical (Specialized Power Systems). The reference markdown files under [references/](references/) are self-contained design notes you can read as a primer regardless of the skill harness.

## Quick start (MATLAB only)

```matlab
% 1. Add the scripts to your path
addpath('.claude/skills/gfm-design/scripts');

% 2. Design from specs (defaults match a 60 Hz, 480 V LL, 10 kVA plant)
p = gfm_design_from_specs( ...
        'law',         'droop',  ...    % droop | vsg | dvoc | psc
        'topology',    'single', ...    % single | double
        'droop_w_pct', 1,        ...    % 1% w-droop at rated P
        'droop_v_pct', 5);              % 5% V-droop at rated Q

% 3. Predict steady state analytically (no sim needed)
pred = gfm_predict_steady_state(p);

% 4. Generate a full Simulink variant folder (params + build + run)
gfm_generate_variant('my_droop_variant', ...
                     'law',      'droop', ...
                     'topology', 'single');

% 5. Build the model and simulate
cd my_droop_variant
build_gfm_droop_single        % writes my_droop_variant/gfm_droop_single.slx
run_gfm_droop_single_sim      % writes runs/<timestamp>/ with plots and summary
```

## Scaffold support matrix

`gfm_generate_variant` currently supports these `(law, topology)` combinations end-to-end because they have working reference implementations the generator can clone from:

| Law | Single | Double |
|---|---|---|
| Droop | ✅ | ✅ |
| VSG | ❌ (needs template) | ✅ |
| dVOC | ❌ (needs template) | ✅ |
| Synchronverter | ❌ (needs template) | ❌ (needs template) |
| PSC | ❌ (needs template) | ❌ (needs template) |

For unsupported combinations, the generator emits a clear "not implemented" error with instructions to add a controller-code template. PRs welcome.

## Repo layout

```
gfm-design/
├── SKILL.md                          Claude Code skill manifest (triggers, workflow, scope)
├── README.md                         This file
├── LICENSE                           MIT
├── references/                       Self-contained design notes (no external deps)
│   ├── control-law-taxonomy.md       Decision tree across all GFM families
│   ├── droop-design.md               P-ω / Q-V droop math + worked examples
│   ├── vsg-synchronverter-design.md  Swing-eq and Zhong/Weiss synchronverter
│   ├── dvoc-design.md                Dispatchable VOC (Colombino/Groß/Dörfler 2019)
│   ├── psc-design.md                 Harnefors-style power synchronization
│   ├── inner-loops-and-lcl.md        Cascaded V/I PI + LCL filter sizing
│   ├── virtual-impedance.md          Cross-cutting Q-sharing / fault-limit overlay
│   ├── multi-unit-sharing.md         Predicted P/Q sharing math
│   └── bibliography.md               IEEE Transactions citations, by family
└── scripts/                          MATLAB tooling
    ├── gfm_design_from_specs.m       specs → populated parameter struct
    ├── gfm_predict_steady_state.m    analytical ω_pcc / V_pcc / sharing (no sim)
    ├── gfm_inner_loop_tuning.m       bandwidth-driven V/I PI gains
    ├── gfm_smallsignal.m             linearized state-space for pole/Bode
    └── gfm_generate_variant.m        full variant scaffold generator
```

## Requirements

- MATLAB R2024b or newer
- Simulink
- Simscape Electrical / Specialized Power Systems

The MATLAB scripts have no other dependencies.

## Scope and verification

- Output of this skill is a **design**, not evidence. A design predicts behavior; only simulation verifies it. The skill never invokes `sim()` — that is the job of a downstream validation step.
- All numeric design formulas are grounded in IEEE Transactions papers cited in [references/bibliography.md](references/bibliography.md). Surveys and tertiary sources were used only as discovery aids.
- The MATLAB scripts have been written from the same formulas as the reference docs but have not been independently validated against published reference results — treat the first run as a smoke test.

## Contributing

Issues and pull requests welcome. Priority targets:

1. Controller-code templates for the missing combinations (especially `vsg+single`, `psc+double`).
2. A companion validation skill (`gfm-validation`) that closes the loop on the design.
3. Worked examples for non-default plant configurations (low-voltage feeder, weak grid with SCR < 2, mixed R/X).

## License

[MIT](LICENSE).
