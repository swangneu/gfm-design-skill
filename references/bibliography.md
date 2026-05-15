# Bibliography

IEEE Transactions and equivalent trusted publications, organized by family. The references in the design notes are drawn from this list — keep new sources in this file rather than scattering them.

Selection criteria (per user instruction): prefer IEEE Transactions; accept IEEE TIA / TPEL / TPS / TAC / TCS-I / IES, and equivalent peer-reviewed venues (IET, EPSR). For grid-code, GFM specification, model-quality, and Simulink handoff guidance, use official standards, system-operator, national-lab, or MathWorks documentation. Skip preprints, MDPI, vendor marketing, and unverified summaries except where they aggregate primary work and are flagged as such.

## Family A — Droop and direct synchronization

**Standard P-ω / Q-V droop**
- Chandorkar, M.C.; Divan, D.M.; Adapa, R. *Control of parallel connected inverters in standalone AC supply systems*. IEEE Transactions on Industry Applications, 29(1):136–143, Jan/Feb 1993. — Foundational paper.
- Guerrero, J.M.; Vasquez, J.C.; Matas, J.; de Vicuña, L.G.; Castilla, M. *Hierarchical control of droop-controlled AC and DC microgrids — A general approach toward standardization*. IEEE TIE 58(1):158–172, Jan 2011.
- Rocabert, J.; Luna, A.; Blaabjerg, F.; Rodríguez, P. *Control of power converters in AC microgrids*. IEEE TPEL 27(11):4734–4749, Nov 2012. — Standard tutorial.

**Power synchronization control (PSC)**
- Zhang, L.; Harnefors, L.; Nee, H.-P. *Power-synchronization control of grid-connected voltage-source converters*. IEEE Transactions on Power Systems, 25(2):809–820, May 2010. — The defining paper.
- Harnefors, L.; Wang, X.; Yepes, A.G.; Blaabjerg, F. *Passivity-based stability assessment of grid-connected VSCs — An overview*. IEEE Journal of Emerging and Selected Topics in Power Electronics, 4(1):116–125, March 2016.

## Family B — Virtual synchronous machine (VSM, VSG, synchronverter)

**Swing-equation VSG**
- D'Arco, S.; Suul, J.A.; Fosso, O.B. *A virtual synchronous machine implementation for distributed control of power converters in SmartGrids*. Electric Power Systems Research 122:180–197, May 2015.
- Bevrani, H.; Ise, T.; Miura, Y. *Virtual synchronous generators: A survey and new perspectives*. International Journal of Electrical Power & Energy Systems 54:244–254, 2014.

**Synchronverter**
- Zhong, Q.-C.; Weiss, G. *Synchronverters: Inverters that mimic synchronous generators*. IEEE Transactions on Industrial Electronics, 58(4):1259–1267, Apr 2011. — The defining paper.
- Zhong, Q.-C.; Nguyen, P.-L.; Ma, Z.; Sheng, W. *Self-synchronized synchronverters: Inverters without a dedicated synchronization unit*. IEEE TPEL 29(2):617–630, Feb 2014.

**Adaptive / augmented inertia**
- Alipoor, J.; Miura, Y.; Ise, T. *Power system stabilization using virtual synchronous generator with alternating moment of inertia*. IEEE Journal of Emerging and Selected Topics in Power Electronics, 3(2):451–458, June 2015.

## Family C — Virtual oscillator (VOC / dVOC)

**Foundational VOC**
- Johnson, B.B.; Dhople, S.V.; Hamadeh, A.O.; Krein, P.T. *Synchronization of nonlinear oscillators in an LTI electrical power network*. IEEE Transactions on Circuits and Systems I: Regular Papers, 61(3):834–844, March 2014.

**dVOC**
- Colombino, M.; Groß, D.; Brouillon, J.-S.; Dörfler, F. *Global phase and magnitude synchronization of coupled oscillators with application to the control of grid-forming power inverters*. IEEE Transactions on Automatic Control, 64(11):4496–4511, Nov 2019. — The defining paper.
- Seo, G.-S.; Colombino, M.; Subotic, I.; Johnson, B.B.; Groß, D.; Dörfler, F. *Dispatchable virtual oscillator control for decentralized inverter-dominated power systems: Analysis and experiments*. IEEE Applied Power Electronics Conference (APEC) 2019. — Experimental validation.

**Comparative**
- Tayyebi, A.; Groß, D.; Anta, A.; Kupzog, F.; Dörfler, F. *Frequency stability of synchronous machines and grid-forming power converters*. IEEE Journal of Emerging and Selected Topics in Power Electronics, 8(2):1004–1018, June 2020.

## Cross-cutting — Virtual impedance, LCL, fault limiting

**LCL filter design**
- Liserre, M.; Blaabjerg, F.; Hansen, S. *Design and control of an LCL-filter-based three-phase active rectifier*. IEEE Transactions on Industry Applications, 41(5):1281–1291, Sep/Oct 2005. — The standard LCL design reference.

**Virtual impedance**
- Wang, X.; Beerten, J.; Belmans, R. *Virtual-impedance-based control for voltage-source and current-source converters*. IEEE TPEL 30(12):7019–7037, Dec 2015.
- He, J.; Li, Y.W. *Analysis, design, and implementation of virtual impedance for power electronics interfaced distributed generation*. IEEE TIA 47(6):2525–2538, Nov/Dec 2011.

**Overcurrent / fault-ride-through for GFM**
- Rosso, R.; Wang, X.; Liserre, M.; Lu, X.; Engelken, S. *Grid-forming converters: Control approaches, grid-synchronization, and future trends — A review*. IEEE Open Journal of Industry Applications, 2:93–109, 2021.
- Baeckeland, N.; Chatterjee, D.; Lu, M.; Johnson, B.; Seo, G.-S. *Overcurrent Limiting in Grid-Forming Inverters: A Comprehensive Review and Discussion*. IEEE Transactions on Power Electronics, 39(11):14493-14517, Nov 2024. DOI: 10.1109/TPEL.2024.3430316.
- Ordonez Murillo, A.; et al. *Current limiting strategies for grid forming inverters under low voltage ride through*. Renewable and Sustainable Energy Reviews, 202:114657, Sept 2024. DOI: 10.1016/j.rser.2024.114657.
- Dolado Fernandez, J.J.; Garcia, J.; Rausell Navarro, E.; Arnaltes Gomez, S.; Rodriguez Amenedo, J.L. *Low-Voltage Ride-Through Algorithm for Grid-Forming Converters*. IEEE Transactions on Power Electronics, 40(1):303-315, Jan 2025. DOI: 10.1109/TPEL.2024.3458193.
- Lyu, X.; Du, W.; Mohiuddin, S.M.; Nandanoori, S.P.; Elizondo, M. *Criteria for Grid-Forming Inverters Transitioning Between Current Limiting Mode and Normal Operation*. IEEE Transactions on Power Systems, 2024. DOI: 10.1109/TPWRS.2024.3402012.
- *A fault ride-through strategy for grid-forming converters under symmetrical and asymmetrical grid faults*. Electric Power Systems Research, 235:110672, 2024. DOI: 10.1016/j.epsr.2024.110672.

**Strong-grid and grid-strength stability**
- Li, Y.; Gu, Y.; Green, T. *Revisiting Grid-Forming and Grid-Following Inverters: A Duality Theory*. IEEE Transactions on Power Systems, 37(6):4541-4554, Nov 2022. DOI: 10.1109/TPWRS.2022.3151851.
- Huang, L.; Wu, C.; Zhou, D.; Blaabjerg, F. *A Simplified SISO Small-Signal Model for Analyzing Instability Mechanism of Grid-Forming Inverter under Stronger Grid*. IEEE COMPEL, 2021. DOI: 10.1109/COMPEL52922.2021.9646041.
- Ravanji, M.H.; Rathnayake, D.B.; Mansour, M.Z.; Bahrani, B. *Impact of Voltage-Loop Feedforward Terms on the Stability of Grid-Forming Inverters and Remedial Actions*. IEEE Transactions on Energy Conversion, 2023. DOI: 10.1109/TEC.2023.3246566.

## Standards, specifications, and grid-code anchors

- IEEE Std 1547-2018. *IEEE Standard for Interconnection and Interoperability of Distributed Energy Resources with Associated Electric Power Systems Interfaces*. Use for distribution DER interconnection requirements and test expectations.
- IEEE Std 2800-2022. *IEEE Standard for Interconnection and Interoperability of Inverter-Based Resources (IBRs) Interconnecting with Associated Transmission Electric Power Systems*. Use for transmission/sub-transmission IBR capability expectations.
- UNIFI Consortium. *Specifications for Grid-forming Inverter-based Resources, Version 2*. NREL/TP-5D00-89269, 2024. Use for GFM-specific functional behavior, current-limited ride-through assumptions, and EMT model expectations.
- AEMO. *Voluntary Specification for Grid-Forming Inverters: Core Requirements Test Framework*. January 2024. Use for scenario-style GFM tests and behavioral expectations. https://www.aemo.com.au/-/media/files/initiatives/engineering-framework/2023/grid-forming-inverters-jan-2024.pdf
- AEMO. *Grid-forming Technology Access Standards Technical Requirements Review*. Initiated 2025. Use as evidence that GFM voluntary guidance is moving toward connection/access requirements in some jurisdictions. https://www.aemo.com.au/consultations/current-and-closed-consultations/grid-forming-technology-access-standards-technical-requirements-review
- NERC. *Grid Forming Functional Specifications for BPS-Connected Battery Energy Storage Systems*. White Paper, September 2023. Use for BPS-connected BESS functional behavior prompts and test expectations. https://www.nerc.com/globalassets/our-work/reports/white-papers/white_paper_gfm_functional_specification.pdf
- DOE i2X. *Distributed Energy Resource Interconnection Roadmap*. 2024. Use for interconnection process context and emerging-technology standards needs. https://www.energy.gov/eere/i2x/doe-distributed-energy-resource-interconnection-roadmap

## Planning-model and model-quality anchors

- Du, W.; Nguyen, Q.H.; Wang, S.; Kim, J.; Liu, Y.; Zhu, S.; Tuffner, F.K.; et al. *Positive-Sequence Modeling of Droop-Controlled Grid-Forming Inverters for Transient Stability Simulation of Transmission Systems*. IEEE Transactions on Power Delivery, 39(3):1736-1748, 2024. DOI: 10.1109/TPWRD.2024.3376245.
- Du, W.; Lasseter, R.H.; Hardt, C.; Wang, S.; Zhu, S.; Liu, Y.; Nguyen, Q.; et al. *Model Specification of Droop-Controlled, Grid-Forming Inverters (REGFM_A1)*. PNNL-35110, September 2023. WECC approved/final model specification. https://www.pnnl.gov/main/publications/external/technical_reports/PNNL-35110.pdf
- PNNL. *New Grid-Forming Inverter Models Help Utilities Plan for a Renewable Future*. July 2024. Use as public context for REGFM_A1 and REGFM_B1 planning-model adoption; not a control-design source. https://www.pnnl.gov/publications/new-grid-forming-inverter-models-help-utilities-plan-renewable-future

## Simulink and model-readability anchors

- MathWorks. *Programmatic Modeling Basics*. Use for repeatable model generation with `new_system`, `add_block`, `add_line`, `set_param`, and related APIs. https://www.mathworks.com/help/simulink/ug/approach-modeling-programmatically.html
- MathWorks. *MAB Modeling Guidelines*. Use for readability, naming, simulation/verification, and code-generation modeling conventions. https://www.mathworks.com/help/simulink/mab-modeling-guidelines.html
- MathWorks. *Modeling Guidelines for Subsystems*. Use for subsystem hierarchy, inport/outport, signal labels, and block layout checks. https://www.mathworks.com/help/ecoder/ug/modeling-guidelines-for-subsystems.html

## Surveys and landscape papers

- Lasseter, R.H.; Chen, Z.; Pattabiraman, D. *Grid-Forming Inverters: A Critical Asset for the Power Grid*. IEEE JESTPE 8(2):925–935, June 2020.
- *Grid-Forming Inverter-Based Resource Research Landscape*. IEEE PES Open Article, March/April 2024. — Useful aggregator; cites the primary sources above.
- Khan, B.; Padmanaban, S.; et al. *Grid-forming control for inverter-based resources in power systems: A review*. IET Renewable Power Generation, 2024.
- *Grid Forming Inverter Modeling, Control, and Applications*. IEEE Access 9, 2021 (DOI 10.1109/ACCESS.2021.3104617).

## How to use this list

When writing a new reference doc:
1. Cite the *primary* paper (the first paper introducing the law), not a tertiary survey.
2. Quote the equation form the primary paper uses. Notation differs subtly across surveys.
3. If a survey is more accessible (open-access), still cite the primary paper and note "see also: <survey>" as a reading aid.
4. For standards, test frameworks, planning-model specs, and Simulink handoff rules, cite the official public document directly.
5. Do not cite preprints, vendor marketing, or unverified MDPI summaries as authority. They can be cross-checks, not sources.
