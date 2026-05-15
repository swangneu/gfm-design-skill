# Recent GFM Requirements and Research Directions

This note captures recent discussion that sits around, but not inside, current
interconnection standards. Use it to ground prompts about "what else should we
think about" beyond a nominal GFM controller design.

## Direction of travel

| Topic | Recent direction | Design implication |
|---|---|---|
| Functional behavior over control-law labels | UNIFI and AEMO focus on observable behavior, not whether the law is droop, VSG, PSC, or dVOC | prompts should ask what behavior is required before picking a law |
| EMT model quality | specifications increasingly expect credible EMT behavior, especially during current-limited events | parameter design must be followed by EMT/HIL validation |
| LVRT/FRT with limited current | current limiting is now a central GFM research topic | limiter mode and recovery rule must be recorded before fault claims |
| Strong-grid stability | GFM can have high-SCR instability even if it helps weak grids | run SCR sweeps on both sides, not only weak-grid cases |
| Plant-level GFM | BESS, PV+BESS, wind+BESS, STATCOM, and HVDC plants need plant controller and energy-limit assumptions | inverter-level tuning is not enough for plant claims |
| Generic planning models | WECC-approved REGFM_A1 and REGFM_B1 show movement into positive-sequence planning tools | keep the distinction between EMT controller design and planning model behavior |
| Access standards | AEMO's GFM access-standards review shows voluntary specs moving toward connection requirements | record jurisdiction and project-specific rules explicitly |
| Data-driven verification | recent work is exploring input-output specifications and data-driven checks | future companion tools can compare logged EMT responses against behavior specs |

## Prompt-grounding rule

When this skill answers a design or modeling prompt, ground each non-obvious
recommendation in one of:

1. A local reference doc in this folder.
2. A primary paper or technical specification listed in [bibliography](bibliography.md).
3. A clearly marked engineering heuristic, if no stronger source is available.

If a user asks for a claim that requires simulation, HIL, certification, or
grid-code review, state that the repo can only provide design assumptions and a
validation checklist.

## Source anchors

- UNIFI Consortium, *Specifications for Grid-Forming Inverter-Based Resources,
  Version 2*, NREL/TP-5D00-89269, 2024:
  https://www.nrel.gov/docs/fy24osti/89269.pdf
- AEMO, *Voluntary Specification for Grid-Forming Inverters: Core Requirements
  Test Framework*, January 2024:
  https://www.aemo.com.au/-/media/files/initiatives/engineering-framework/2023/grid-forming-inverters-jan-2024.pdf
- AEMO, *Grid-forming Technology Access Standards Technical Requirements
  Review*, initiated 2025:
  https://www.aemo.com.au/consultations/current-and-closed-consultations/grid-forming-technology-access-standards-technical-requirements-review
- NERC, *Grid Forming Functional Specifications for BPS-Connected Battery
  Energy Storage Systems*, White Paper, September 2023:
  https://www.nerc.com/globalassets/our-work/reports/white-papers/white_paper_gfm_functional_specification.pdf
- DOE i2X, *Distributed Energy Resource Interconnection Roadmap*, 2024:
  https://www.energy.gov/eere/i2x/doe-distributed-energy-resource-interconnection-roadmap
- PNNL, *New Grid-Forming Inverter Models Help Utilities Plan for a Renewable
  Future*, 2024:
  https://www.pnnl.gov/publications/new-grid-forming-inverter-models-help-utilities-plan-renewable-future
- Li, Gu, Green, *Revisiting Grid-Forming and Grid-Following Inverters: A
  Duality Theory*, IEEE Transactions on Power Systems, 2022.
- Baeckeland et al., *Overcurrent Limiting in Grid-Forming Inverters*, IEEE
  TPEL, 2024.
