function [sys, info] = gfm_smallsignal(p, varargin)
%GFM_SMALLSIGNAL  Linearized state-space of a GFM controller + LCL.
%
%   [sys, info] = gfm_smallsignal(p) returns an ss model of the small-signal
%   power-loop dynamics for the chosen control law, linearized around the
%   nominal operating point (P=P_ref, Q=Q_ref, ω=ω_n, |V|=V_peak).
%
%   Captured dynamics:
%     - Power-loop state(s) of the chosen law (droop LPF / VSG swing / dVOC)
%     - First-order P-θ coupling through the inductive line
%     - Q-LPF closed through the algebraic Q-V droop / synchronverter relation
%   Inputs   : [ΔP_ref; ΔQ_ref]
%   Outputs  : [Δω; Δ|V|; ΔP; ΔQ]
%
%   Use this for pole/zero/Bode quick-look before sim. Not a substitute for
%   linmod on the full Simulink model.
%
%   Conventions (must match references/droop-design.md and inner-loops-and-lcl.md):
%     - Amplitude-invariant Park: P = 1.5·V_d·I_d, K_θ = 1.5·V_peak²/X_line
%     - Δ|V_ref| is algebraic in droop / VSG / dVOC slow-manifold (not a state)
%     - Q-V droop is collapsed into the Q-LPF dynamics:
%         dQ_filt/dt = -(1 + n_q·K_Vmag)/τ_p · Q_filt + (n_q·K_Vmag/τ_p)·Q_ref
%
%   Optional name-value:
%     'plot'   - 'none' | 'pzmap' | 'bode'  (default 'pzmap')
%     'X_line' - per-inverter inductive coupling Ω (default ω*(L_f+L_2+L_g))

ip = inputParser;
ip.addParameter('plot',   'pzmap', @ischar);
ip.addParameter('X_line', [], @(x)isempty(x) || isnumeric(x));
ip.parse(varargin{:});
opt = ip.Results;

if isempty(opt.X_line)
    X_line = 2*pi*p.f_n * (p.L_f + p.L_2 + p.L_g);
else
    X_line = opt.X_line;
end

% Three-phase power-angle gain (amplitude-invariant Park):
%   P = 1.5·V_peak²·sin(δ)/X  →  K_θ = ∂P/∂δ = 1.5·V_peak²/X at δ ≈ 0
K_theta = 1.5 * p.V_peak^2 / X_line;
% Reactive-vs-V gain at the same operating point:
%   Q = 1.5·V_peak·(V_inv − V_pcc)/X  →  ∂Q/∂V_inv = 1.5·V_peak/X
K_Vmag  = 1.5 * p.V_peak / X_line;

switch lower(p.law)
    case 'droop'
        sys = droopSS(p, K_theta, K_Vmag);
    case 'vsg'
        sys = vsgSS(p, K_theta, K_Vmag);
    case 'dvoc'
        sys = dvocSS(p, K_theta, K_Vmag);
    case 'psc'
        sys = pscSS(p, K_theta, K_Vmag, X_line);
    otherwise
        error('gfm_smallsignal:badLaw', 'Unknown p.law = %s', p.law);
end

info.K_theta = K_theta;
info.K_Vmag  = K_Vmag;
info.X_line  = X_line;
info.poles   = pole(sys);
info.law     = p.law;

% Stability invariant: every pole should be in the open LHP for a sensibly
% tuned plant. If this fails, the small-signal derivation drifted again or
% the parameters are pathological — surface it before the user trusts the
% pzmap.
if any(real(info.poles) >= -1e-9)
    warning('gfm_smallsignal:unstable', ...
        'Linearized %s model has non-LHP pole(s); check derivation/params.', ...
        p.law);
end

% --- Plot ---
switch lower(opt.plot)
    case 'pzmap'
        figure; pzmap(sys); grid on;
        title(sprintf('Pole/Zero — %s', p.law));
    case 'bode'
        figure; bode(sys); grid on;
        title(sprintf('Bode — %s', p.law));
    case 'none'
        % no plot
    otherwise
        warning('gfm_smallsignal:badPlot', ...
            'Unknown plot option %s; skipping.', opt.plot);
end

end


% =====================================================================
function sys = droopSS(p, K_theta, K_Vmag)
% Droop, slow-manifold linearization.
%
% State : x = [ΔP_filt; Δθ; ΔQ_filt]
% Input : u = [ΔP_ref; ΔQ_ref]
%
% Dynamics:
%   τ_p·dP_filt/dt = K_θ·Δθ − P_filt              (P-LPF closed around line)
%   dθ/dt          = −m_p·(P_filt − P_ref)        (droop + phase integration)
%   τ_p·dQ_filt/dt = K_Vmag·Δ|V| − Q_filt          (Q-LPF closed around line)
%   Δ|V|           = −n_q·(Q_filt − Q_ref)         (Q-V droop, algebraic)
%
% Substituting Δ|V| collapses Q into a single first-order state:
%   dQ_filt/dt = −(1 + n_q·K_Vmag)/τ_p · Q_filt + (n_q·K_Vmag/τ_p)·Q_ref
%
% Outputs are formed algebraically from the states + inputs.

tau_p = 1 / p.w_pwr_filt;
m_p   = p.m_p;
n_q   = p.n_q;

aQ = (1 + n_q*K_Vmag) / tau_p;     % Q-LPF effective pole (closed through droop)
bQ = (n_q*K_Vmag)     / tau_p;

A = [-1/tau_p,   K_theta/tau_p,   0;
     -m_p,       0,               0;
      0,         0,              -aQ];
B = [0,    0;
     m_p,  0;
     0,    bQ];

C = [-m_p,    0,        0;             % Δω   = −m_p·P_filt   (+ m_p·P_ref via D)
      0,      0,       -n_q;           % Δ|V| = −n_q·Q_filt   (+ n_q·Q_ref  via D)
      0,      K_theta,  0;             % ΔP   = K_θ·Δθ
      0,      0,       -n_q*K_Vmag];   % ΔQ   = K_Vmag·Δ|V|   (+ n_q·K_Vmag·Q_ref via D)
D = [m_p,         0;
     0,           n_q;
     0,           0;
     0,           n_q*K_Vmag];

sys = ss(A, B, C, D, ...
    'StateName',  {'P_filt','theta','Q_filt'}, ...
    'InputName',  {'P_ref','Q_ref'}, ...
    'OutputName', {'omega','V','P','Q'});
end


% =====================================================================
function sys = vsgSS(p, K_theta, K_Vmag)
% Swing-equation VSG. Explicit ω state replaces droop's P-LPF.
%
% State : x = [Δω; Δθ; ΔQ_filt]
% Input : u = [ΔP_ref; ΔQ_ref]
%
% Dynamics:
%   J·dω/dt = ΔP_ref − K_θ·Δθ − D·Δω
%   dθ/dt   = Δω
%   τ_p·dQ_filt/dt = K_Vmag·Δ|V| − Q_filt
%   Δ|V|    = −K_q·(Q_filt − Q_ref)        (Q-V droop, algebraic)

J     = p.J_vsg;
D     = p.D_vsg;
K_q   = p.K_q;
tau_p = 1 / p.w_pwr_filt;

aQ = (1 + K_q*K_Vmag) / tau_p;
bQ = (K_q*K_Vmag)     / tau_p;

A = [-D/J,    -K_theta/J,   0;
      1,       0,           0;
      0,       0,          -aQ];
B = [1/J,    0;
     0,      0;
     0,      bQ];

C = [1,       0,         0;             % Δω
     0,       0,        -K_q;           % Δ|V| = −K_q·Q_filt (+ K_q·Q_ref via D)
     0,       K_theta,   0;             % ΔP   = K_θ·Δθ
     0,       0,        -K_q*K_Vmag];   % ΔQ   = K_Vmag·Δ|V|
D_o = [0,         0;
       0,         K_q;
       0,         0;
       0,         K_q*K_Vmag];

sys = ss(A, B, C, D_o, ...
    'StateName',  {'omega','theta','Q_filt'}, ...
    'InputName',  {'P_ref','Q_ref'}, ...
    'OutputName', {'omega','V','P','Q'});
end


% =====================================================================
function sys = dvocSS(p, K_theta, K_Vmag)
% Slow-manifold linearization of dVOC, reused via the droop equivalences:
%   m_p_eq = 2*eta/(3*V*^2)      (P-ω slope)
%   n_q_eq = 1 / (3·alpha·V*)    (Q-V slope)
% Power-loop "LPF" cutoff comes from the controller-internal current LPF
% (default ~500 Hz; override if your variant uses a different cutoff).

p_eq        = p;
p_eq.m_p    = 2 * p.eta / (3 * p.V_peak^2);
p_eq.n_q    = 1   / (3 * p.alpha * p.V_peak);
if isfield(p, 'f_i_lpf') && ~isempty(p.f_i_lpf) && p.f_i_lpf > 0
    p_eq.w_pwr_filt = 2*pi*p.f_i_lpf;
else
    p_eq.w_pwr_filt = 2*pi*500;
end
sys = droopSS(p_eq, K_theta, K_Vmag);
end


% =====================================================================
function sys = pscSS(p, K_theta, K_Vmag, X_line)
% Power Synchronization Control. No P-LPF in the sync loop; Q-V handled via
% an algebraic Q-V droop overlay (set p.n_q = 0 to disable).
%
% State : x = [Δθ; ΔQ_filt]
% Input : u = [ΔP_ref; ΔQ_ref]
%
% Dynamics:
%   dθ/dt = k_p·(P_ref − P) − damp_R·Δθ
%         = −(k_p·K_θ + damp_R)·Δθ + k_p·P_ref
%   τ_p·dQ_filt/dt = K_Vmag·Δ|V| − Q_filt
%   Δ|V|  = −n_q·(Q_filt − Q_ref)
%
% damp_R: linearized contribution of the virtual-resistance loop. Subtract
% R_v·Δi from v_ref; small-signal Δi ≈ K_θ/X · Δθ. See psc-design.md.

k_p   = p.k_p;
R_v   = p.R_v;
n_q   = p.n_q;
tau_p = 1 / p.w_pwr_filt;

damp_R = k_p * R_v * K_theta / X_line;

aQ = (1 + n_q*K_Vmag) / tau_p;
bQ = (n_q*K_Vmag)     / tau_p;

A = [-(k_p*K_theta + damp_R),   0;
      0,                       -aQ];
B = [k_p,   0;
     0,     bQ];

C = [-k_p*K_theta,   0;             % Δω   = −k_p·K_θ·Δθ (+ k_p·P_ref via D)
      0,            -n_q;           % Δ|V| = −n_q·Q_filt (+ n_q·Q_ref  via D)
      K_theta,       0;             % ΔP   = K_θ·Δθ
      0,            -n_q*K_Vmag];   % ΔQ   = K_Vmag·Δ|V|
D_o = [k_p,        0;
       0,          n_q;
       0,          0;
       0,          n_q*K_Vmag];

sys = ss(A, B, C, D_o, ...
    'StateName',  {'theta','Q_filt'}, ...
    'InputName',  {'P_ref','Q_ref'}, ...
    'OutputName', {'omega','V','P','Q'});
end
