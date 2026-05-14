function pred = gfm_predict_steady_state(p, varargin)
%GFM_PREDICT_STEADY_STATE  Analytical steady-state for a GFM model.
%
%   pred = gfm_predict_steady_state(p) returns a struct with predicted
%   per-inverter P, Q, ω_pcc, V_pcc for the parameter struct p.
%
%   Works for any law (droop/VSG/dVOC/PSC) because on the slow manifold
%   they all collapse to the same droop slopes (m_p, n_q for droop;
%   1/D for VSG; eta/V^2 for dVOC; k_p for PSC).
%
%   Optional name-value:
%     'load_P'  - real load at PCC (W). Default: sum of P_ref_i (perfect setpoint)
%     'load_Q'  - reactive load at PCC (VAR). Default: 0
%     'verbose' - print a summary table. Default: true
%
%   The prediction is for an inductive coupling and matched droop slopes,
%   so it is a *first-order* check. If sim disagrees by more than 5%,
%   suspect line-Z mismatch, Q sign convention, or saturation. See
%   ../references/multi-unit-sharing.md.

ip = inputParser;
ip.addParameter('load_P', [],   @(x)isempty(x) || isnumeric(x));
ip.addParameter('load_Q', 0,    @isnumeric);
ip.addParameter('verbose', true, @islogical);
ip.parse(varargin{:});
opt = ip.Results;

% --- Map any law to its effective P-ω slope m_p_eq ---
switch lower(p.law)
    case 'droop'
        m_p_eq = p.m_p;
    case 'vsg'
        m_p_eq = 1 / p.D_vsg;       % steady-state of swing eq
    case 'dvoc'
        m_p_eq = p.eta / p.V_peak^2;
    case 'psc'
        m_p_eq = p.k_p;
    otherwise
        error('gfm_predict_steady_state:badLaw', ...
              'Unknown p.law = %s', p.law);
end

% --- Q-V slope ---
switch lower(p.law)
    case 'droop',  n_q_eq = p.n_q;
    case 'vsg',    n_q_eq = p.K_q;
    case 'dvoc',   n_q_eq = 1 / (3 * p.alpha * p.V_peak);
    case 'psc',    n_q_eq = p.n_q;   % PSC reuses droop's Q-V if defined; else 0
end

% --- Determine topology ---
is_double = isfield(p, 'P_ref1');

if is_double
    P_refs = [p.P_ref1; p.P_ref2];
else
    P_refs = p.P_ref;
end
N = numel(P_refs);

% --- Load (defaults to perfect setpoint match) ---
if isempty(opt.load_P)
    P_load = sum(P_refs);
else
    P_load = opt.load_P;
end
Q_load = opt.load_Q;

% --- P-sharing: common Δω across all units ---
% Droop: ω = ω_n − m_p·(P − P_ref). Steady state ω is common, so
%   P_i = P_ref_i + (ω_n − ω) / m_p_i.
% Sum and impose ΣP_i = P_load (units share m_p_eq in the design path):
%   Δω ≡ ω_n − ω = (P_load − ΣP_ref) / Σ(1/m_p) = m_p_eq·(P_load − ΣP_ref)/N
% Overload (P_load > ΣP_ref) → Δω > 0 → frequency drops → each unit picks up
% more than its setpoint. Sign check is the invariant that breaks if this
% formula goes wrong; see references/multi-unit-sharing.md.
delta_w   = (P_load - sum(P_refs)) / (N / m_p_eq);
P_i       = P_refs + delta_w / m_p_eq;
omega_pcc = p.w_n - delta_w;        % all units settle at same ω

% Invariant: ΣP_i must equal P_load to within floating-point tolerance.
% A failure here means the sign / formula above drifted again.
assert(abs(sum(P_i) - P_load) < 1e-6 * max(1, abs(P_load)), ...
    'gfm_predict_steady_state:powerBalance', ...
    'P-sharing invariant broken: ΣP_i=%g, P_load=%g', sum(P_i), P_load);

% --- Q-sharing: PCC voltage common to all units ---
% Q_i = (V_peak - V_pcc) / (n_q_eq + X_i/V_peak)
% For now assume identical line impedances. Real mismatch handled by
% caller passing per-unit X_i (future extension).
X_to_pcc = 2*pi*p.f_n * p.L_2;       % per-inverter L_2; ignore R_2 for first-order
X_term   = X_to_pcc / p.V_peak;

% Solve for V_pcc s.t. ΣQ_i = Q_load
% Σ (V_peak - V_pcc) / (n_q + X_term) = Q_load
%  → (V_peak - V_pcc) = Q_load * (n_q + X_term) / N
delta_V = Q_load * (n_q_eq + X_term) / N;
V_pcc   = p.V_peak - delta_V;
Q_i     = ones(N,1) * (delta_V / (n_q_eq + X_term));

% --- Pack ---
pred.law          = p.law;
pred.topology     = ternary(is_double, 'double', 'single');
pred.omega_pcc    = omega_pcc;
pred.f_pcc        = omega_pcc / (2*pi);
pred.V_pcc_peak   = V_pcc;
pred.V_pcc_LLrms  = V_pcc * sqrt(3)/sqrt(2);
pred.P_per_inv    = P_i(:);
pred.Q_per_inv    = Q_i(:);
pred.P_total      = sum(P_i);
pred.Q_total      = sum(Q_i);
pred.m_p_eq       = m_p_eq;
pred.n_q_eq       = n_q_eq;
pred.delta_w      = delta_w;
pred.delta_V      = delta_V;

% --- Report ---
if opt.verbose
    fprintf('\n[gfm_predict_steady_state] %s, %s topology\n', p.law, pred.topology);
    fprintf('  Δω      : %+.6f rad/s   (Δf = %+.4f Hz)\n', delta_w, delta_w/(2*pi));
    fprintf('  ω_pcc   : %.4f rad/s    (f = %.4f Hz)\n', omega_pcc, pred.f_pcc);
    fprintf('  V_pcc   : %.2f V peak    (= %.2f V LL RMS)\n', V_pcc, pred.V_pcc_LLrms);
    fprintf('  ΔV      : %+.3f V\n', -delta_V);
    fprintf('\n');
    for k = 1:N
        fprintf('  Inv %d:  P_ref=%6.0f W  ->  P_pred=%7.1f W   |   Q_pred=%7.1f VAR\n', ...
            k, P_refs(k), P_i(k), Q_i(k));
    end
    fprintf('  Total :              P=%7.1f W (load %.0f)     Q=%7.1f VAR (load %.0f)\n', ...
        pred.P_total, P_load, pred.Q_total, Q_load);
    fprintf('\n');
end

end


function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
