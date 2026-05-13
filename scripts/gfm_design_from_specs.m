function p = gfm_design_from_specs(varargin)
%GFM_DESIGN_FROM_SPECS  Build a GFM parameter struct from high-level specs.
%
%   p = gfm_design_from_specs('law','droop', ...)
%   returns a struct in the schema the repo's build_gfm_* files expect.
%
%   Common name-value pairs (all optional; defaults match the repo baseline):
%     'law'          - 'droop' | 'vsg' | 'dvoc' | 'psc'   (default 'droop')
%     'topology'     - 'single' | 'double'               (default 'single')
%     'f_n'          - grid frequency Hz                 (default 60)
%     'V_LL_rms'     - line-line RMS V                   (default 480)
%     'S_rated'      - VA per inverter                   (default 10e3)
%     'V_dc'         - DC bus V                          (default 800)
%     'droop_w_pct'  - %% w-droop at rated P             (default 1)
%     'droop_v_pct'  - %% V-droop at rated Q             (default 5)
%     'f_pwr_filt'   - power LPF cutoff Hz               (default 5)
%     'f_sw'         - PWM carrier Hz                    (default 10e3)
%     'f_bw_i'       - inner I PI bandwidth Hz target    (default 1000)
%     'f_bw_v'       - outer V PI bandwidth Hz target    (default 100)
%
%   Law-specific (apply only when 'law' matches):
%     VSG:    'H_inertia'  - virtual inertia constant s  (default 2.0)
%     dVOC:   'eta_scale'  - dispatch-loop de-tune        (default 0.25 for
%                            double, 1 for single)
%             'kappa'      - rotation angle rad           (default pi/2)
%     PSC:    'R_v'        - virtual resistance Ohm       (default 0.5)
%
%   Plant overrides (LCL + grid Z):
%     'L_f','R_f','C_f','R_d','L_2','R_2','L_g','R_g'    (defaults: repo)
%
%   Setpoints (per inverter):
%     'P_ref1','P_ref2','Q_ref'                          (defaults: 5e3,3e3,0)
%
%   Returns the same field schema as the repo's existing gfm_params.m files,
%   plus law-specific fields. Use gfm_generate_variant to write it to disk.

opt = parseOptions(varargin{:});

p = struct();

% --- Grid ---
p.f_n      = opt.f_n;
p.w_n      = 2*pi*opt.f_n;
p.V_LL_rms = opt.V_LL_rms;
p.V_ph_rms = opt.V_LL_rms / sqrt(3);
p.V_peak   = p.V_ph_rms   * sqrt(2);

% --- Rated power ---
p.S_rated  = opt.S_rated;
p.I_peak   = p.S_rated*sqrt(2) / (sqrt(3)*p.V_LL_rms);

% --- DC bus ---
p.V_dc     = opt.V_dc;

% --- LCL filter ---
p.L_f      = opt.L_f;
p.R_f      = opt.R_f;
p.C_f      = opt.C_f;
p.R_d      = opt.R_d;
p.L_2      = opt.L_2;
p.R_2      = opt.R_2;

% --- Grid impedance ---
p.L_g      = opt.L_g;
p.R_g      = opt.R_g;

% --- Switching / sampling ---
p.f_sw     = opt.f_sw;
p.Ts_power = opt.Ts_power;
p.Ts_ctrl  = opt.Ts_ctrl;

% --- Setpoints ---
switch lower(opt.topology)
    case 'single'
        p.P_ref    = opt.P_ref1;
        p.Q_ref    = opt.Q_ref;
        p.t_step1  = opt.t_step1_single;
        p.P_step1  = opt.P_step1_single;
        p.t_step2  = opt.t_step2_single;
        p.P_step2  = opt.P_step2_single;
    case 'double'
        p.P_ref1   = opt.P_ref1;
        p.P_ref2   = opt.P_ref2;
        p.Q_ref    = opt.Q_ref;
        p.t_step1_1 = opt.t_step1_1;  p.P_step1_1 = opt.P_step1_1;
        p.t_step2_1 = opt.t_step2_1;  p.P_step2_1 = opt.P_step2_1;
        p.t_step1_2 = opt.t_step1_2;  p.P_step1_2 = opt.P_step1_2;
        p.t_step2_2 = opt.t_step2_2;  p.P_step2_2 = opt.P_step2_2;
    otherwise
        error('gfm_design_from_specs:badTopology', ...
              'topology must be ''single'' or ''double'', got ''%s''', opt.topology);
end

% --- Power measurement LPF (common) ---
p.f_pwr_filt = opt.f_pwr_filt;
p.w_pwr_filt = 2*pi*opt.f_pwr_filt;

% --- Droop slopes (always present; even VSG/dVOC reference them) ---
p.m_p      = (opt.droop_w_pct/100) * p.w_n   / p.S_rated;
p.n_q      = (opt.droop_v_pct/100) * p.V_peak / p.S_rated;

% --- Inner V/I PI gains (always populated; baseline can ignore them) ---
[p.Kp_i, p.Ki_i, p.Kp_v, p.Ki_v] = innerLoopGains(p, opt.f_bw_i, opt.f_bw_v);

% --- Law-specific fields ---
p.law = lower(opt.law);
switch p.law
    case 'droop'
        % No extra fields; droop uses m_p, n_q, f_pwr_filt directly.
    case 'vsg'
        p.H_inertia = opt.H_inertia;
        p.J_vsg     = 2 * opt.H_inertia * p.S_rated / p.w_n^2;
        % Match droop slope: D_vsg = 1 / m_p
        p.D_vsg     = 1 / p.m_p;
        p.K_q       = p.n_q;            % reuse droop slope for Q-V
    case 'dvoc'
        % Match droop slopes via slow-manifold equivalence
        p.kappa     = opt.kappa;
        if isnan(opt.eta_scale)
            % Default: 1 for single inverter, 0.25 for double
            if strcmpi(opt.topology, 'double')
                p.eta_scale = 0.25;
            else
                p.eta_scale = 1.0;
            end
        else
            p.eta_scale = opt.eta_scale;
        end
        p.eta       = p.eta_scale * 1.5 * p.m_p * p.V_peak^2;
        p.alpha     = 1 / (3 * p.n_q * p.V_peak);
    case 'psc'
        p.k_p       = p.m_p;            % steady-state matches droop
        p.R_v       = opt.R_v;
    otherwise
        error('gfm_design_from_specs:badLaw', ...
              'law must be droop|vsg|dvoc|psc, got ''%s''', opt.law);
end

% --- Virtual impedance (off by default; user can enable) ---
p.R_v_pcc  = opt.R_v_pcc;
p.L_v_pcc  = opt.L_v_pcc;

% --- Simulation horizon ---
p.t_stop   = opt.t_stop;

% --- Sanity checks (warnings, not errors) ---
sanityChecks(p);

end


% =====================================================================
function opt = parseOptions(varargin)
ip = inputParser;
% Top-level
ip.addParameter('law',          'droop');
ip.addParameter('topology',     'single');
% Grid / plant
ip.addParameter('f_n',          60);
ip.addParameter('V_LL_rms',     480);
ip.addParameter('S_rated',      10e3);
ip.addParameter('V_dc',         800);
ip.addParameter('f_sw',         10e3);
ip.addParameter('Ts_power',     1e-6);
ip.addParameter('Ts_ctrl',      1e-4);
% LCL + grid Z (repo defaults)
ip.addParameter('L_f',          4e-3);
ip.addParameter('R_f',          0.05);
ip.addParameter('C_f',          5e-6);
ip.addParameter('R_d',          5);
ip.addParameter('L_2',          1e-3);
ip.addParameter('R_2',          0.05);
ip.addParameter('L_g',          1e-3);
ip.addParameter('R_g',          0.1);
% Droop %
ip.addParameter('droop_w_pct',  1);
ip.addParameter('droop_v_pct',  5);
ip.addParameter('f_pwr_filt',   5);
% Bandwidth targets
ip.addParameter('f_bw_i',       1000);
ip.addParameter('f_bw_v',       100);
% Setpoints
ip.addParameter('P_ref1',       5e3);
ip.addParameter('P_ref2',       3e3);
ip.addParameter('Q_ref',        0);
% Single-topology step schedule
ip.addParameter('t_step1_single', 0.4);
ip.addParameter('P_step1_single', 8e3);
ip.addParameter('t_step2_single', 0.9);
ip.addParameter('P_step2_single', 3e3);
% Double-topology step schedule (steps disabled by default)
ip.addParameter('t_step1_1',  Inf);  ip.addParameter('P_step1_1', 8e3);
ip.addParameter('t_step2_1',  Inf);  ip.addParameter('P_step2_1', 3e3);
ip.addParameter('t_step1_2',  Inf);  ip.addParameter('P_step1_2', 5e3);
ip.addParameter('t_step2_2',  Inf);  ip.addParameter('P_step2_2', 2e3);
% Law-specific
ip.addParameter('H_inertia',    2.0);
ip.addParameter('kappa',        pi/2);
ip.addParameter('eta_scale',    NaN);          % NaN -> auto-pick by topology
ip.addParameter('R_v',          0.5);
% Virtual impedance overlay
ip.addParameter('R_v_pcc',      0);
ip.addParameter('L_v_pcc',      0);
% Sim
ip.addParameter('t_stop',       1.5);

ip.parse(varargin{:});
opt = ip.Results;
end


% =====================================================================
function [Kp_i, Ki_i, Kp_v, Ki_v] = innerLoopGains(p, f_bw_i, f_bw_v)
% Bandwidth-driven PI gains. Pole-zero cancel the L/R pole for inner I loop.

w_bw_i = 2*pi*f_bw_i;
Kp_i   = w_bw_i * p.L_f;
Ki_i   = w_bw_i * p.R_f;

% Outer V loop on the capacitor branch. Heuristic scaling; verify on Bode.
w_bw_v = 2*pi*f_bw_v;
Kp_v   = w_bw_v * p.C_f * 100;      % units chosen to keep Kp_v O(1) for repo plant
Ki_v   = Kp_v * w_bw_v / 5;
end


% =====================================================================
function sanityChecks(p)
% Warn on bandwidth-ladder violations and out-of-range LCL.

L_eq  = (p.L_f*p.L_2)/(p.L_f+p.L_2);
f_res = 1/(2*pi*sqrt(L_eq*p.C_f));

if f_res > p.f_sw/2
    warning('gfm_design_from_specs:f_res_high', ...
        'LCL resonance %.0f Hz > f_sw/2 = %.0f Hz. Ripple will pass.', ...
        f_res, p.f_sw/2);
end
if f_res < 10*p.f_n
    warning('gfm_design_from_specs:f_res_low', ...
        'LCL resonance %.0f Hz < 10*f_n = %.0f Hz. Fundamental attenuated.', ...
        f_res, 10*p.f_n);
end
if p.f_pwr_filt > 20  % crude
    warning('gfm_design_from_specs:lpf_high', ...
        'f_pwr_filt = %.1f Hz is high; swing dynamics may oscillate.', p.f_pwr_filt);
end
% Inner-loop bandwidth target check (derived from Kp_i/L_f)
f_bw_i_actual = p.Kp_i / p.L_f / (2*pi);
if f_bw_i_actual > p.f_sw/4
    warning('gfm_design_from_specs:bw_i_high', ...
        'Inner I bandwidth %.0f Hz > f_sw/4 = %.0f Hz.', f_bw_i_actual, p.f_sw/4);
end
end
