# GFM Control Law Taxonomy

A decision map across the three IEEE-recognized GFM families plus their commonly seen variants. Each entry lists the differential equation that defines the law, when to pick it, what its weakness is, and which IEEE source pins it down.

## Family A — Droop-based

Direct mapping of grid-following alternator behavior. Power flows act through angle/frequency droop and voltage/reactive droop. State-of-the-art baseline.

### A1. Standard P-ω / Q-V droop

```
dθ/dt = ω
ω     = ω_n − m_p · (P_filt − P_ref)
|V|   = V_peak − n_q · (Q_filt − Q_ref)
τ_p · dP_filt/dt = P − P_filt        (LPF; gives the swing dynamics)
```

- **Slope choice**: `m_p = (Δω%) · ω_n / S_rated`, `n_q = (ΔV%) · V_peak / S_rated`.
- **Pick when**: simplest plant, single or paralleled inverters, primary control only.
- **Weakness**: Q-sharing degrades under mismatched line impedance; no virtual inertia (LPF time constant is the only "inertia" knob).
- **Source**: Chandorkar, Divan, Adapa, *Control of parallel connected inverters in standalone AC supply systems*, IEEE TIA 29(1), 1993. Modern survey: Rocabert et al., *Control of power converters in AC microgrids*, IEEE TPEL 27(11), 2012.

### A2. Power synchronization control (PSC)

```
dθ/dt = ω_n + k_p · (P_ref − P)            // direct P → Δω, no LPF
v_ref = V_ref ∠ θ                          // magnitude held by an outer V loop
```

- Equivalent to droop in DC, faster in AC because the LPF is gone.
- **Pick when**: weak-grid HVDC interconnections or wind-farm PCC. Harnefors's family. Robust at low SCR.
- **Weakness**: needs damping (often an inner virtual-resistance loop or an explicit phase-margin shaping filter).
- **Source**: Zhang, Harnefors, Nee, *Power-synchronization control of grid-connected voltage-source converters*, IEEE TPS 25(2), 2010.

### A3. Synchronous power control (SPC), enhanced direct power control (EDPC)

Variants that pre-filter or feed-forward the active-power reference. Rarely the right starting point in a research repo — use droop or PSC unless a paper specifically reports SPC/EDPC for the application.

## Family B — Virtual synchronous machine (VSM / VSG)

Embeds an explicit swing equation. Behaves like a synchronous generator from the grid's terminals.

### B1. Swing-equation VSG

```
J · dω/dt = P_ref − P − D · (ω − ω_n)        // mechanical swing
dθ/dt     = ω
|V|       = V_peak − K_q · (Q − Q_ref)       // Q-V droop reused
```

- **Mapping to droop**: at steady state `(ω−ω_n) = (P_ref − P)/D`, so `D = 1/m_p` ties the droop slope. Inertia constant `H = J · ω_n² / (2 · S_rated)`.
- **Pick when**: need explicit inertia for low-inertia grid studies, RoCoF requirements, or co-simulation with a synchronous-machine model.
- **Weakness**: low D and high J both promote oscillation; tune from `(ω_n, ζ)` not from `(J, D)` directly.
- **Source**: D'Arco, Suul, Fosso, *A virtual synchronous machine implementation for distributed control of power converters in SmartGrids*, EPSR 122, 2015. IEEE: Bevrani, Ise, Miura, *Virtual synchronous generators: A survey and new perspectives*, IJEPES 54, 2014.

### B2. Synchronverter

Identical state equations to B1 with one twist: the Q-V loop is replaced by a *flux-magnitude integrator* `dM_f i_f / dt = (1/K) · (Q_ref − Q − D_q · (V − V_ref))`. Gives integral action on voltage, no steady-state V error.

- **Pick when**: voltage regulation must be exact (e.g. islanded microgrid with V-quality targets).
- **Weakness**: stability of the flux integrator under transient is delicate; needs anti-windup.
- **Source**: Zhong, Weiss, *Synchronverters: Inverters that mimic synchronous generators*, IEEE TIE 58(4), 2011.

### B3. VISMA, augmented VSG, adaptive-inertia VSG

Variants that change `J` and `D` online (e.g. `J ∝ |dω/dt|`). Useful in published results but not in scope for first-pass design. If the user requests one, return B1 with a note that they can swap the gain blocks.

## Family C — Virtual oscillator

Nonlinear oscillator with a stable limit cycle. Synchronizes by physics, not by power-feedback control.

### C1. Dispatchable virtual oscillator control (dVOC)

α-β frame state `v = [v_α; v_β]`:

```
v̇ = ω_n · J · v + η · R(κ) · (K(v) − i) + η · α · Φ(v) · v
K(v)   = (2/(3·V*²)) · [P*  Q*; −Q*  P*] · v        // dispatch current ref
Φ(v)   = (V*² − ‖v‖²) / V*²                         // mag regulation
R(κ)   = [cos κ  −sin κ; sin κ  cos κ];  κ = π/2 (inductive grid)
```

- **Slow-manifold equivalence**: with the `2/(3·V*²)` dispatch-current convention above, small-signal P-ω slope is `Δω = (2η/(3·V*²)) · (P* − P)`; Q-V slope is `Δ|v| = (1/(3·α·V*)) · (Q* − Q)`. Use these to match a target droop %.
- **Pick when**: rigorous synchronization guarantees needed (Lyapunov stability under arbitrary topology); academic study.
- **Weakness**: when paralleled at `Q=0, ‖v‖=V*` the diff-mode is weakly damped — scale `η` down (typical: `eta_scale = 0.25` for two paralleled units) or add a current-feedback LPF.
- **Source**: Colombino, Groß, Brouillon, Dörfler, *Global phase and magnitude synchronization of coupled oscillators with application to the control of grid-forming power inverters*, IEEE TAC 64(11), 2019. Foundational VOC: Johnson, Dhople, Hamadeh, Krein, *Synchronization of nonlinear oscillators in an LTI electrical power network*, IEEE TCS-I 61(3), 2014.

### C2. Unified VOC, dead-zone VOC

Hardware-friendly variants. Skip unless the user references them specifically.

## Cross-cutting layer — Virtual impedance

Not a control law on its own — a *modifier* applied on top of A/B/C. Subtracts a virtual `Z_v · i` from the voltage reference to behave as if a programmable impedance sits in series with the inverter.

- **Pick when**: paralleled GFMs with mismatched line impedance, fault-current limiting needed, weak-grid stabilization.
- **Source**: Wang, Beerten, Belmans, *Virtual-impedance-based control for voltage-source and current-source converters*, IEEE TPEL 30(12), 2015.

See `virtual-impedance.md`.

## Decision tree

```
Need explicit inertia / RoCoF / SG-equivalent dynamics?
├── YES → B1 (VSG) or B2 (Synchronverter if V must be regulated to zero error)
└── NO
    │
    Need formal Lyapunov sync proof / academic study of nonlinear sync?
    ├── YES → C1 (dVOC)
    └── NO
        │
        Weak grid / HVDC / SCR < 2?
        ├── YES → A2 (PSC) + inner V or virtual-R damping
        └── NO  → A1 (standard droop) — start here unless above triggers fire
```

Mismatched line impedance between paralleled units → add virtual impedance regardless of family.

## Cross-references

- Math + worked examples per family: [droop-design](droop-design.md), [vsg-synchronverter-design](vsg-synchronverter-design.md), [dvoc-design](dvoc-design.md), [psc-design](psc-design.md).
- Inner V/I loop sizing (independent of family): [inner-loops-and-lcl](inner-loops-and-lcl.md).
- Bibliography with IEEE Transactions citations: [bibliography](bibliography.md).
