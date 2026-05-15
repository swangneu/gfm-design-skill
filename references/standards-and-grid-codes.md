# Standards and Grid-Code Boundary

This skill may reference public standards and specifications to shape a design
checklist, but it does not certify, qualify, or prove compliance. Treat every
standard item here as an input requirement or validation target for a separate
simulation, HIL, commissioning, and interconnection-review process.

## Which public document applies?

| Situation | Primary public document to check | How to use it in this skill |
|---|---|---|
| Distribution-connected DER in the United States | IEEE 1547-2018, plus applicable amendments and local adoption rules | Confirm ride-through, abnormal voltage/frequency response, power quality, islanding, interoperability, and test expectations. |
| Transmission or sub-transmission IBR in the United States | IEEE 2800-2022, plus applicable regional rules | Confirm minimum capability expectations for ride-through, active/reactive power control, abnormal voltage/frequency support, power quality, negative-sequence current, and system protection. |
| GFM-specific functional behavior | UNIFI Specifications for GFM IBRs, Version 2 | Use the GFM behavior priorities, power-sharing expectations, fault-response considerations, and EMT-model expectations as design assumptions. |
| Australian NEM GFM projects | AEMO voluntary GFM specification, AEMO GFM access-standards review, NER connection/access standards | Use as jurisdiction-specific GFM behavior and test-framework inputs; do not generalize these to other regions. |
| BPS-connected BESS in North America | NERC GFM functional-specification white paper plus local TO/TP/PC requirements | Use for functional behavior prompts and BESS-specific assumptions; not a binding standard by itself. |
| Harmonics/power quality studies | IEEE 519 and site-specific power-quality rules | Keep outside this skill unless the user provides harmonic limits and a detailed switching/filter model. |
| Voltage-service range | ANSI C84.1 or local equivalent | Use for allowable service-voltage assumptions, not controller proof. |

For non-U.S. projects, replace these with the applicable grid code, connection
agreement, market rule, and OEM data sheet. Do not assume IEEE defaults apply.

## GFM-specific assumptions to record

When producing `gfm_params.m`, include a short assumptions block with:

- Applicable interconnection level: distribution, sub-transmission, islanded
  microgrid, lab testbed, or unknown.
- Standard or grid-code target: e.g. IEEE 1547-2018, IEEE 2800-2022, UNIFI v2,
  AEMO GFM voluntary specification, GB GC0137, or project-specific rules.
- Normal operating voltage/frequency band.
- Ride-through voltage/frequency envelope, if supplied.
- Fault current magnitude and duration capability.
- Current-limiting mode and recovery strategy.
- Active/reactive current priority during abnormal voltage.
- Negative-sequence or per-phase current behavior for unbalanced faults.
- Harmonic and power-quality assumptions.
- LVRT/HVRT curves, voltage measurement basis, current priority, negative-sequence/per-phase behavior, and recovery/exit rule when fault ride-through is in scope.
- Strong-grid connection assumptions: SCR/X/R range, transformer or feeder impedance, pre-synchronization thresholds, and virtual impedance/damping assumptions.

If any of these are unknown, label the design as a nominal controller design
only. Do not state that it is grid-code ready.

## Public-source guidance

IEEE 2800-2022 establishes technical minimum requirements for IBRs connected to
transmission and sub-transmission systems. Its public summary names voltage and
frequency ride-through, active/reactive power control, dynamic support during
abnormal voltage/frequency, power quality, negative-sequence current injection,
and system protection as covered areas.

IEEE 1547-2018 establishes interconnection and interoperability requirements
for DER connected with electric power systems. Its public summary covers
performance, operation, testing, safety considerations, maintenance,
abnormal-condition response, power quality, islanding, and test requirements.

UNIFI Specifications for GFM IBRs, Version 2 define functional expectations for
GFM IBRs at plant and unit levels. For abnormal events, use its priority order:
self-protection first, system-wide stability second, return to setpoints third.
UNIFI also expects EMT models to include fault-current shaping behavior when the
fault current is time limited.

Recent AEMO work is useful when a project is in the Australian NEM or when the
user asks about how GFM voluntary specifications are evolving toward access
requirements. Treat it as jurisdiction-specific guidance, not a universal
standard.

The 2024 IEEE TPEL current-limiting review is a useful technical reference:
current limiting protects the power stage, but also changes device stability,
transient system stability, protection behavior, and post-fault recovery.

## What not to claim

Do not claim any of the following based on this skill alone:

- IEEE 1547, IEEE 2800, UL 1741, NERC, AEMO, GB, ENTSO-E, or local grid-code
  compliance.
- Fault-ride-through success.
- Protection coordination success.
- Harmonic compliance.
- Black-start capability.
- Safety qualification.
- Production firmware readiness.

The correct wording is: "This parameter set is a nominal analytical design with
recorded protection and grid-code assumptions; it still requires EMT
simulation, hardware/protection review, and project-specific compliance work."

## Links

- IEEE 2800-2022 public summary: https://standards.ieee.org/ieee/7003/10453/
- IEEE 1547-2018 public summary: https://standards.ieee.org/ieee/1547/5915/
- UNIFI Specifications for GFM IBRs, Version 2: https://www.nrel.gov/docs/fy24osti/89269.pdf
- AEMO voluntary GFM test framework: https://www.aemo.com.au/-/media/files/initiatives/engineering-framework/2023/grid-forming-inverters-jan-2024.pdf
- AEMO GFM access standards review: https://www.aemo.com.au/consultations/current-and-closed-consultations/grid-forming-technology-access-standards-technical-requirements-review
- NERC GFM BESS functional specification white paper: https://www.nerc.com/globalassets/our-work/reports/white-papers/white_paper_gfm_functional_specification.pdf
- DOE i2X DER interconnection roadmap: https://www.energy.gov/eere/i2x/doe-distributed-energy-resource-interconnection-roadmap
- Current limiting review: https://doi.org/10.1109/TPEL.2024.3430316
- LVRT/FRT design checklist: [lvrt-and-fault-ride-through](lvrt-and-fault-ride-through.md)
- Strong-grid stability checklist: [strong-grid-stability](strong-grid-stability.md)
