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
%   Inputs   : [ΔP_ref; ΔQ_ref]
%   Outputs  : [Δω; Δ|V|; ΔP; ΔQ]
%
%   Use this for pole/zero/Bode quick-look before sim. Not a substitute for
%   linmod on the full Simulink model.
%
%   Optional name-value:
%     'plot' - 'none' | 'pzmap' | 'bode'  (default 'pzmap')
%     'X_line' - per-inverter inductive coupling Ω (default ω*(L_2+L_g))

ip = inputParser;
ip.addParameter('plot',   'pzmap', @ischar);
ip.addParameter('X_line', [], @(x)isempty(x) || isnumeric(x));
ip.parse(varargin{:});
opt = ip.Results;

if isempty(opt.X_line)
    X_line = 2*pi*p.f_n * (p.L_2 + p.L_g);
else
    X_line = opt.X_line;
end

% Power-angle gain (kW/rad): K_θ = 1.5 * V_d * V_pcc / X_line
% At the operating point V_d ≈ V_pcc ≈ V_peak (rms-peak phase).
K_theta = 1.5 * p.V_peak^2 / X_line;
% Power-magnitude gain ∂Q/∂|V|
K_Vmag  = 1.5 * p.V_peak / X_line;

switch lower(p.law)
    case 'droop'
        sys = droopSS(p, K_theta, K_Vmag);
    case 'vsg'
        sys = vsgSS(p, K_theta, K_Vmag);
    case 'dvoc'
        sys = dvocSS(p, K_theta, K_Vmag);
    case 'psc'
        sys = pscSS(p, K_theta, K_Vmag);
    otherwise
        error('gfm_smallsignal:badLaw', 'Unknown p.law = %s', p.law);
end

info.K_theta = K_theta;
info.K_Vmag  = K_Vmag;
info.X_line  = X_line;
info.poles   = pole(sys);
info.law     = p.law;

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
% State : x = [ΔP_filt; Δθ; ΔQ_filt; Δ|V|]
% Inputs: u = [ΔP_ref; ΔQ_ref]
%
% LPF on power : τ_p * dP_filt/dt = ΔP - ΔP_filt
% Droop        : Δω = -m_p * (P_filt - P_ref)
% Phase int    : dθ/dt = Δω
% Power coupling: ΔP ≈ K_θ * Δθ, ΔQ ≈ -K_Vmag * (|V_pcc|-|V_inv|) ≈ K_Vmag*Δ|V|
% Voltage droop: Δ|V| = -n_q * (Q_filt - Q_ref)

tau_p = 1 / p.w_pwr_filt;
m_p   = p.m_p;
n_q   = p.n_q;

A = [-1/tau_p,          K_theta/tau_p,    0,            0;
     -m_p,              0,                0,            0;
      0,                0,               -1/tau_p,     -K_Vmag/tau_p;
      0,                0,               -n_q,          0];
B = [0,         0;
     m_p,       0;
     0,         0;
     0,         n_q];
C = [0, -m_p,  0,    0;     % Δω
     0,  0,   0,    1;     % Δ|V|
     1,  0,   0,    0;     % ΔP_filt (≈ ΔP at low freq)
     0,  0,   1,    0];    % ΔQ_filt
D = zeros(4,2);

sys = ss(A, B, C, D, ...
    'StateName',  {'P_filt','theta','Q_filt','V_mag'}, ...
    'InputName',  {'P_ref','Q_ref'}, ...
    'OutputName', {'omega','V','P','Q'});
end


% =====================================================================
function sys = vsgSS(p, K_theta, K_Vmag)
% State : x = [Δω; Δθ; ΔQ_filt; Δ|V|]
% J*dω/dt = ΔP_ref - ΔP - D*Δω
% ΔP = K_θ * Δθ ; dθ/dt = Δω

J     = p.J_vsg;
D     = p.D_vsg;
K_q   = p.K_q;
tau_p = 1 / p.w_pwr_filt;     % Q-side LPF (reuse droop LPF)

A = [-D/J,              -K_theta/J,         0,            0;
      1,                 0,                 0,            0;
      0,                 0,                -1/tau_p,     -K_Vmag/tau_p;
      0,                 0,                -K_q,          0];
B = [1/J,      0;
     0,        0;
     0,        0;
     0,        K_q];
C = [1, 0, 0, 0;            % Δω
     0, 0, 0, 1;            % Δ|V|
     0, K_theta, 0, 0;      % ΔP
     0, 0, 1, 0];           % ΔQ_filt
D_o = zeros(4,2);

sys = ss(A, B, C, D_o, ...
    'StateName',  {'omega','theta','Q_filt','V_mag'}, ...
    'InputName',  {'P_ref','Q_ref'}, ...
    'OutputName', {'omega','V','P','Q'});
end


% =====================================================================
function sys = dvocSS(p, K_theta, K_Vmag)
% Slow-manifold linearization. Treat dVOC as droop with:
%   m_p_eq = eta / V*^2     (P-ω slope)
%   n_q_eq = 1/(3*alpha*V*) (Q-V slope)
%   tau_p ≈ 0               (no LPF in dVOC itself; the current-feedback LPF
%                            sets it; here we use the controller-internal one)
%
% For a first-order check, use the same structure as droopSS with the
% equivalent slopes. Caller can sharpen by adding the i-LPF state.

p_eq        = p;
p_eq.m_p    = p.eta / p.V_peak^2;
p_eq.n_q    = 1 / (3 * p.alpha * p.V_peak);
p_eq.w_pwr_filt = 2*pi*500;     % match the controller's i-LPF cutoff
sys = droopSS(p_eq, K_theta, K_Vmag);
end


% =====================================================================
function sys = pscSS(p, K_theta, K_Vmag)
% No LPF in the sync loop. State: x = [Δθ; ΔQ_filt; Δ|V|]
% dθ/dt = k_p * (P_ref - P) = k_p * (P_ref - K_θ*Δθ)
% Optional virtual resistance damping enters as -k_p * R_v * Δi ≈ -k_p*R_v*K_θ/X_line*Δθ

k_p = p.k_p;
R_v = p.R_v;
n_q = p.n_q;
tau_p = 1 / p.w_pwr_filt;

% damping injected by R_v on i
damp_R = k_p * R_v * K_theta / (2*pi*p.f_n * (p.L_2 + p.L_g));

A = [-(k_p*K_theta + damp_R),   0,             0;
      0,                       -1/tau_p,     -K_Vmag/tau_p;
      0,                       -n_q,          0];
B = [k_p, 0;
     0,    0;
     0,    n_q];
C = [k_p*K_theta, 0, 0;       % Δω = -k_p*K_θ*Δθ (steady state when error=0)
     0,           0, 1;       % Δ|V|
     K_theta,     0, 0;       % ΔP
     0,           1, 0];      % ΔQ_filt
D_o = zeros(4,2);

sys = ss(A, B, C, D_o, ...
    'StateName',  {'theta','Q_filt','V_mag'}, ...
    'InputName',  {'P_ref','Q_ref'}, ...
    'OutputName', {'omega','V','P','Q'});
end
