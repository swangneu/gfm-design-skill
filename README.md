# gfm-design

A portable [Codex](https://openai.com/codex) / [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) skill for designing grid-forming (GFM) inverter controllers for MATLAB/Simulink + Simscape Electrical.

## What it does

When invoked, the skill helps you:

- **Choose** a GFM control law (droop / VSG / synchronverter / dVOC / PSC) from system specs.
- **Tune** the law-specific gains ($m_p$, $n_q$, $J$, $D$, $H$, $\eta$, $\alpha$, $\kappa$, $k_p$, virtual impedance, inner V/I PI) using analytical formulas grounded in IEEE Transactions literature.
- **Predict** steady-state $\omega_{\mathrm{pcc}}$, $V_{\mathrm{pcc}}$, and per-inverter $P/Q$ sharing *before* running a simulation.
- **Linearize** the closed-loop dynamics for a pole/Bode quick-look across droop / VSG / dVOC / PSC.

Deliverable is a populated `gfm_params.m` parameter struct plus analytical predictions. The user plugs the struct into their own Simulink model; this skill never calls `sim()`. Closing the loop after simulation is left to manual sim review (or a future companion validation skill).

## Notation

| Symbol | Meaning |
|---|---|
| $m_p$ | Active-power/frequency droop slope for $P-\omega$ control |
| $n_q$ | Reactive-power/voltage droop slope for $Q-V$ control |
| $J$, $D$, $H$ | VSG/synchronverter inertia and damping parameters |
| $\eta$, $\alpha$, $\kappa$ | dVOC dispatch, voltage, and coupling gains |
| $k_p$ | PSC power-synchronization gain |
| $\omega_{\mathrm{pcc}}$, $V_{\mathrm{pcc}}$ | Predicted PCC angular frequency and voltage magnitude |

## Coverage

Control laws covered with self-contained math + worked examples:

| Family | Law | Reference doc |
|---|---|---|
| Droop | $P-\omega$ / $Q-V$ droop | [droop-design.md](references/droop-design.md) |
| Droop | Power Synchronization Control (PSC) | [psc-design.md](references/psc-design.md) |
| VSM | Swing-equation VSG | [vsg-synchronverter-design.md](references/vsg-synchronverter-design.md) |
| VSM | Synchronverter (Zhong/Weiss) | [vsg-synchronverter-design.md](references/vsg-synchronverter-design.md) |
| Oscillator | dVOC (Colombino/Groß/Dörfler) | [dvoc-design.md](references/dvoc-design.md) |
| Cross-cutting | Virtual impedance | [virtual-impedance.md](references/virtual-impedance.md) |
| Cross-cutting | Inner V/I PI on LCL | [inner-loops-and-lcl.md](references/inner-loops-and-lcl.md) |
| Cross-cutting | Multi-unit $P/Q$ sharing | [multi-unit-sharing.md](references/multi-unit-sharing.md) |

Decision tree across all laws: [control-law-taxonomy.md](references/control-law-taxonomy.md). Full IEEE bibliography: [bibliography.md](references/bibliography.md).

## Install

The skill is a folder containing `SKILL.md`, `references/`, and `scripts/`. Install the same folder in the skill directory for the agent you use.

### [Codex](https://openai.com/codex)

User-level install on Windows PowerShell:

```powershell
$root = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "$env:USERPROFILE\.codex" }
New-Item -ItemType Directory -Force (Join-Path $root "skills") | Out-Null
git clone https://github.com/swangneu/gfm-design-skill (Join-Path $root "skills\gfm-design")
```

macOS / Linux:

```bash
root="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$root/skills"
git clone https://github.com/swangneu/gfm-design-skill "$root/skills/gfm-design"
```

Restart Codex, then ask for a GFM design task or invoke the skill explicitly with `$gfm-design`.

### [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)

Project-level install (this repo only, commits to git):

```text
your-project/
├── .claude/
│   └── skills/
│       └── gfm-design/      contents of this repo
└── ...
```

User-level install on Windows PowerShell:

```powershell
git clone https://github.com/swangneu/gfm-design-skill "$env:USERPROFILE\.claude\skills\gfm-design"
```

macOS / Linux:

```bash
git clone https://github.com/swangneu/gfm-design-skill ~/.claude/skills/gfm-design
```

Restart Claude Code, then type `/gfm-design`; the skill name should appear in the slash-command list. Claude Code can also invoke it automatically when you describe a GFM design task.

### Compatibility notes

- `SKILL.md` is the shared skill manifest used by both Codex and Claude Code.
- `agents/openai.yaml` is Codex UI metadata. Claude Code can ignore it safely.
- The MATLAB scripts and reference docs are standalone and do not depend on either agent.

## Use without a skill runner

All MATLAB scripts under [scripts/](scripts/) are standalone and run from any MATLAB $\ge$ R2024b (`gfm_smallsignal` additionally needs Control System Toolbox):

- `gfm_design_from_specs.m` — specs $\to$ populated parameter struct.
- `gfm_predict_steady_state.m` — analytical $\omega_{\mathrm{pcc}}$ / $V_{\mathrm{pcc}}$ / per-inverter $P/Q$ (no sim).
- `gfm_inner_loop_tuning.m` — bandwidth-driven V/I PI gains.
- `gfm_smallsignal.m` — linearized state-space for pole/Bode quick-look.
- `test_gfm_design.m` — smoke harness covering the four scripts above.

The reference markdown files under [references/](references/) are self-contained design notes you can read as a primer regardless of the skill harness.

## Quick start (MATLAB only)

```matlab
% 1. Add the scripts to your path
addpath('<path-to-gfm-design>/scripts');

% 2. Design from specs (defaults match a 60 Hz, 480 V LL, 10 kVA plant)
p = gfm_design_from_specs( ...
        'law',         'droop',  ...    % droop | vsg | dvoc | psc
        'topology',    'single', ...    % single | double
        'droop_w_pct', 1,        ...    % 1% w-droop at rated P
        'droop_v_pct', 5);              % 5% V-droop at rated Q

% 3. Predict steady state analytically (no sim needed)
pred = gfm_predict_steady_state(p);

% 4. Quick-look small-signal stability
[sys, info] = gfm_smallsignal(p, 'plot', 'pzmap');
disp(info.poles);

% 5. Plug `p` into your own Simulink model. The struct field names match a
%    typical GFM model schema (V_dc, L_f, R_f, C_f, R_d, L_2, R_2, m_p, n_q,
%    Kp_i, Ki_i, Kp_v, Ki_v, ...). See "Parameter-struct conventions" in
%    SKILL.md for the assumed plant topology and controller interface.
```

## Repo layout

```
gfm-design/
├── SKILL.md                          Shared Codex/Claude skill manifest
├── agents/
│   └── openai.yaml                   Codex UI metadata
├── README.md                         This file
├── LICENSE                           MIT
├── references/                       Self-contained design notes (no external deps)
│   ├── control-law-taxonomy.md       Decision tree across all GFM families
│   ├── droop-design.md               P-omega / Q-V droop math + worked examples
│   ├── vsg-synchronverter-design.md  Swing-eq and Zhong/Weiss synchronverter
│   ├── dvoc-design.md                Dispatchable VOC (Colombino/Groß/Dörfler 2019)
│   ├── psc-design.md                 Harnefors-style power synchronization
│   ├── inner-loops-and-lcl.md        Cascaded V/I PI + LCL filter sizing
│   ├── virtual-impedance.md          Cross-cutting Q-sharing / fault-limit overlay
│   ├── multi-unit-sharing.md         Predicted P/Q sharing math
│   └── bibliography.md               IEEE Transactions citations, by family
└── scripts/                          MATLAB tooling (all standalone)
    ├── gfm_design_from_specs.m       specs -> populated parameter struct
    ├── gfm_predict_steady_state.m    analytical omega_pcc / V_pcc / sharing (no sim)
    ├── gfm_inner_loop_tuning.m       bandwidth-driven V/I PI gains
    ├── gfm_smallsignal.m             linearized state-space for pole/Bode
    └── test_gfm_design.m             smoke harness for the analytical scripts
```

## Requirements

- MATLAB R2024b or newer
- Control System Toolbox (for `gfm_smallsignal`)
- Simulink + Simscape Electrical / Specialized Power Systems (only if you want to drop the resulting `p` struct into a Simulink model)

The MATLAB scripts in this skill have no other dependencies.

## Scope and verification

- Output of this skill is a **design**, not evidence. A design predicts behavior; only simulation verifies it. The skill never invokes `sim()`.
- This project is **not** certified, safety-qualified, or grid-code-qualified control software. Do not use its outputs for safety-critical, protection, grid-interconnection, production hardware, or field deployment decisions without independent engineering review, simulation, hardware-in-the-loop testing, and applicable certification.
- All numeric design formulas are grounded in IEEE Transactions papers cited in [references/bibliography.md](references/bibliography.md). Surveys and tertiary sources were used only as discovery aids.
- The MATLAB scripts have been written from the same formulas as the reference docs but have not been independently validated against published reference results — treat the first run as a smoke test. The [`test_gfm_design.m`](scripts/test_gfm_design.m) harness exercises power-balance, sign conventions, small-signal stability per law, and the law-equivalence relations ($\mathrm{VSG} \leftrightarrow \mathrm{droop}$, $\mathrm{dVOC} \leftrightarrow \mathrm{droop}$ slopes). Run it with `addpath('scripts'); test_gfm_design`.

## Contributing

Issues and pull requests welcome. Priority targets:

1. A companion validation skill that closes the loop on a simulated design (compare predicted vs. logged $P/Q$, $\omega$, $V$).
2. Worked examples for non-default plant configurations (low-voltage feeder, weak grid with SCR < 2, mixed R/X).
3. Better Bode-derived heuristics for the outer voltage PI gain across plants very different from the 480 V / 10 kVA baseline.

## License

[MIT](LICENSE).
