# dVOC Implementation Conventions

Use this note when translating a dVOC design into an averaged converter,
Simulink/Specialized Power Systems switching model, or MATLAB Function
controller. It is an implementation guardrail, not a replacement for
`dvoc-design.md`.

## Canonical controller boundary

For the baseline implementation, the dVOC state is the alpha-beta inverter
voltage reference:

```text
v = [v_alpha; v_beta]
```

The controller owns the oscillator state, current filter, power filter, and
limits. It outputs a modulation command:

```text
v_alpha_beta -> inverse Clarke -> v_abc -> m_abc = v_abc / (Vdc/2)
```

Prefer a standard two-level PWM block for the final gate generation. In
Specialized Power Systems, use `PWM Generator (2-Level)` with external
three-phase modulation, then feed its gate output to `Universal Bridge`.

Do not treat hand-coded or controller-debug gate vectors as proof that the
bridge received the same gate vector. Log the actual PWM block output when
validating a switching model.

## Alpha-beta and P/Q convention

This skill assumes amplitude-invariant Clarke coordinates and peak phase
quantities:

```text
v_alpha = (2/3) * (v_a - 0.5*v_b - 0.5*v_c)
v_beta  = (2/3) * (sqrt(3)/2) * (v_b - v_c)

v_a = v_alpha
v_b = -0.5*v_alpha + (sqrt(3)/2)*v_beta
v_c = -0.5*v_alpha - (sqrt(3)/2)*v_beta
```

With positive current defined as inverter-to-grid injected current:

```text
P = 1.5 * (v_alpha*i_alpha + v_beta*i_beta)
Q = 1.5 * (v_beta*i_alpha - v_alpha*i_beta)
```

The dispatch-current matrix must match that convention:

```text
i_star = K(P*,Q*) v

K(P*,Q*) = 2/(3*Vstar^2) * [ P*   Q*
                            -Q*   P* ]
```

At `||v|| = Vstar`, `i = K(P*,Q*)v` gives the requested `P*` and `Q*` under
the formulas above. If a model uses RMS dq values, power-invariant Clarke/Park,
or the opposite reactive-power sign convention, this `2/3` factor or the sign
of the off-diagonal terms must change. Do not mix conventions.

Some papers absorb the `3/2` scaling into their definition of `K_i` or power.
For this skill's convention,

```text
R(kappa) * (K(P*,Q*)v - i)
```

is equivalent to paper forms such as:

```text
K_i v - R(kappa)i
```

when `K_i = R(kappa)K(P*,Q*)`.

## ODE skeleton

The implementation should preserve this structure:

```matlab
J  = [0, -1; 1, 0];
O  = omega0 * J;
Rk = [cos(kappa), -sin(kappa); sin(kappa), cos(kappa)];
K  = 2/(3*Vstar^2) * [Pstar, Qstar; -Qstar, Pstar];
phi = (Vstar^2 - v.'*v) / Vstar^2;

dv = O*v + eta * (Rk*(K*v - i_f) + alpha*phi*v);
```

Use exact rotation for the nominal oscillator part:

```matlab
rot = [cos(omega0*Ts), -sin(omega0*Ts);
       sin(omega0*Ts),  cos(omega0*Ts)];
v_next = rot*v + Ts * eta * (Rk*(K*v - i_f) + alpha*phi*v);
```

This avoids forward-Euler amplitude growth on `omega0*J*v`.

## `eta_scale` meaning

`eta_scale` is not a new control state or a new control law. It is a
dimensionless multiplier on the synchronization gain:

```matlab
eta = eta_scale * 1.5 * m_p_target * Vstar^2;
```

With this skill's scaling:

```text
m_p_effective = 2*eta/(3*Vstar^2) = eta_scale*m_p_target
```

Rules of thumb:

- Single inverter, stiff grid, averaged-law sanity check: start at
  `eta_scale = 1`.
- Paralleled units or weak damping: start lower, often `0.25` to `0.5`.
- Values above `1` make the dispatch loop stiffer and can excite LCL, PWM, or
  grid modes; treat them as a tuned design choice requiring validation.

## Sign and PWM validation recipe

Before retuning dVOC gains, validate implementation conventions in this order:

1. Check Clarke/inverse Clarke with a balanced positive-sequence sine. Confirm
   `v_a + v_b + v_c` is near zero and alpha-beta magnitude is the phase peak.
2. Check the PWM/bridge path with a small fixed balanced `m_abc`. Confirm the
   PWM block output switches, bridge phase voltages are balanced, and terminal
   voltage polarity matches the modulation command.
3. In an averaged alpha-beta plant, run `P_ref > 0`, `Q_ref = 0`. Confirm
   positive settled `P`, small `Q`, and current magnitude near
   `P/(1.5*Vstar)`.
4. In the switching model, log both `m_abc` and the actual PWM gate output.
   Confirm `P` increases when `P_ref` increases and the current fundamental is
   balanced.

Common symptoms:

- `P` has the wrong sign: current measurement orientation or modulation
  polarity is likely flipped.
- Large `Q` at small active-power command: reactive-power sign, alpha-beta
  phase sequence, `kappa`, or voltage polarity is likely inconsistent.
- Nonzero `m_abc` but zero bridge voltage: PWM block configuration, gate order,
  or device model is wrong.
- Averaged model tracks but switching model does not: inspect bridge/PWM/LCL
  realization and current filtering before changing dVOC gains.

Keep this checklist in the model notes or validation report so future retuning
does not hide a convention mismatch.
