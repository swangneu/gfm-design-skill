function test_gfm_design()
%TEST_GFM_DESIGN  Smoke harness for the GFM design scripts.
%
%   Verifies the numerical invariants the design tools must satisfy. None
%   of these tests touch Simulink - they exercise gfm_design_from_specs,
%   gfm_predict_steady_state, gfm_inner_loop_tuning, and gfm_smallsignal
%   only.
%
%   Usage from MATLAB:
%     >> addpath('<path-to-skill>/scripts');
%     >> test_gfm_design;
%
%   Errors at the end with a non-zero failure count. Otherwise prints a
%   one-line "all passed" summary.
%
%   What each test guards against (the bugs that motivated writing it):
%     T1 - schema fields a typical GFM Simulink build script relies on.
%     T2 - P-sharing sign + balance: sum(P_i) = P_load and omega drops under load.
%     T3 - every law's small-signal linearization is internally stable.
%     T4 - droop swing dynamics are in a physically sensible band.
%     T5 - inner I PI pole-zero cancellation: Kp_i/Ki_i = L_f/R_f.
%     T6 - VSG-to-droop equivalence: 1/D_vsg matches m_p (per design choice).
%     T7 - dVOC-to-droop slope equivalence: 2*eta/(3*V*^2) ~= m_p and 1/(3*alpha*V*) ~= n_q.

nPass = 0;
nFail = 0;

% ---- T1: gfm_design_from_specs returns expected schema ----
try
    p = gfm_design_from_specs('law','droop','topology','single');
    must_have = {'m_p','n_q','f_pwr_filt','w_pwr_filt','V_peak','L_f','R_f', ...
                 'C_f','L_2','L_g','Kp_i','Ki_i','Kp_v','Ki_v','law'};
    for k = 1:numel(must_have)
        if ~isfield(p, must_have{k})
            error('gfm_design_from_specs missing field: %s', must_have{k});
        end
    end
    nPass = nPass+1; fprintf('[PASS] T1: droop schema fields present\n');
catch e
    nFail = nFail+1; fprintf(2, '[FAIL] T1: %s\n', e.message);
end

% ---- T2: power balance + delta omega sign in gfm_predict_steady_state ----
try
    p = gfm_design_from_specs('law','droop','topology','double', ...
        'P_ref1', 5e3, 'P_ref2', 3e3);
    % Case A: load > setpoints means omega must drop below omega_n, P_i > P_ref_i.
    pred = gfm_predict_steady_state(p, 'load_P', 10e3, 'verbose', false);
    if abs(pred.P_total - 10e3) > 1e-3
        error('Power balance A: expected 10000 W, got %.3f W', pred.P_total);
    end
    if pred.omega_pcc >= p.w_n
        error('Sign A: load>setpoints should give omega<omega_n, got %.4f vs omega_n=%.4f', ...
            pred.omega_pcc, p.w_n);
    end
    if any(pred.P_per_inv <= [p.P_ref1; p.P_ref2])
        error('Sign A: under overload every unit must take MORE than its P_ref');
    end
    % Case B: load < setpoints means omega rises, P_i < P_ref_i.
    pred = gfm_predict_steady_state(p, 'load_P', 6e3, 'verbose', false);
    if abs(pred.P_total - 6e3) > 1e-3
        error('Power balance B: expected 6000 W, got %.3f W', pred.P_total);
    end
    if pred.omega_pcc <= p.w_n
        error('Sign B: load<setpoints should give omega>omega_n, got %.4f vs omega_n=%.4f', ...
            pred.omega_pcc, p.w_n);
    end
    nPass = nPass+1; fprintf('[PASS] T2: P-sharing balance + delta omega sign correct (both directions)\n');
catch e
    nFail = nFail+1; fprintf(2, '[FAIL] T2: %s\n', e.message);
end

% ---- T3: all laws give all-LHP poles on a stable plant ----
laws = {'droop','vsg','dvoc','psc'};
for k = 1:numel(laws)
    try
        p = gfm_design_from_specs('law',laws{k},'topology','single');
        [~, info] = gfm_smallsignal(p, 'plot','none');
        re = real(info.poles);
        if any(re >= -1e-9)
            error('Law %s has non-LHP pole(s): Re = %s', ...
                laws{k}, mat2str(re, 4));
        end
        nPass = nPass+1; fprintf('[PASS] T3.%d (%s): small-signal stable, poles Re <= %.3g\n', ...
            k, laws{k}, max(re));
    catch e
        nFail = nFail+1; fprintf(2, '[FAIL] T3.%d (%s): %s\n', k, laws{k}, e.message);
    end
end

% ---- T4: droop swing dynamics in a sensible band ----
try
    p = gfm_design_from_specs('law','droop','topology','single');
    tau_p   = 1 / p.w_pwr_filt;
    X_tot   = 2*pi*p.f_n * (p.L_f + p.L_2 + p.L_g);
    K_theta = 1.5 * p.V_peak^2 / X_tot;        % must match gfm_smallsignal
    omega_n = sqrt(p.m_p * K_theta / tau_p);
    zeta    = 1 / (2 * sqrt(p.m_p * K_theta * tau_p));
    fprintf('       droop swing: omega_n = %.2f rad/s (%.2f Hz), zeta = %.2f\n', ...
        omega_n, omega_n/(2*pi), zeta);
    if ~(omega_n > 20 && omega_n < 60)
        error('omega_swing %.2f rad/s outside expected 20-60 rad/s band', omega_n);
    end
    if ~(zeta > 0.3 && zeta < 5)
        error('zeta %.2f outside expected 0.3-5 band', zeta);
    end
    nPass = nPass+1; fprintf('[PASS] T4: droop swing dynamics in physical band\n');
catch e
    nFail = nFail+1; fprintf(2, '[FAIL] T4: %s\n', e.message);
end

% ---- T5: inner I PI pole-zero cancellation ----
try
    p = gfm_design_from_specs('law','droop','topology','single');
    ratio_actual = p.Ki_i / p.Kp_i;        % should equal R_f/L_f
    ratio_target = p.R_f / p.L_f;
    err = abs(ratio_actual - ratio_target) / max(ratio_target, eps);
    if err > 1e-9
        error('Inner I pole-zero cancellation off by %.3g (Ki/Kp=%.6g vs R/L=%.6g)', ...
            err, ratio_actual, ratio_target);
    end
    nPass = nPass+1; fprintf('[PASS] T5: inner I PI cancels plant pole (Ki/Kp = R_f/L_f)\n');
catch e
    nFail = nFail+1; fprintf(2, '[FAIL] T5: %s\n', e.message);
end

% ---- T6: VSG-to-droop equivalence ----
try
    p = gfm_design_from_specs('law','vsg','topology','double');
    err = abs(1/p.D_vsg - p.m_p) / p.m_p;
    if err > 1e-12
        error('VSG D_vsg should equal 1/m_p; got 1/D=%.6g vs m_p=%.6g', ...
            1/p.D_vsg, p.m_p);
    end
    H_check = 0.5 * p.J_vsg * p.w_n^2 / p.S_rated;
    if abs(H_check - p.H_inertia) > 1e-9
        error('VSG H_inertia consistency: 0.5*J*omega^2/S = %.6g vs H = %.6g', ...
            H_check, p.H_inertia);
    end
    nPass = nPass+1; fprintf('[PASS] T6: VSG-to-droop equivalence holds (D = 1/m_p, J = 2HS/omega^2)\n');
catch e
    nFail = nFail+1; fprintf(2, '[FAIL] T6: %s\n', e.message);
end

% ---- T7: dVOC slope equivalence ----
try
    p = gfm_design_from_specs('law','dvoc','topology','double');
    m_p_eq = 2 * p.eta / (3 * p.V_peak^2);
    n_q_eq = 1 / (3 * p.alpha * p.V_peak);
    % With eta_scale = 0.25 (double topology default), m_p_eq = 0.25*m_p_target.
    if abs(m_p_eq - p.eta_scale * p.m_p) / p.m_p > 1e-9
        error('dVOC m_p_eq mismatch: 2*eta/(3*V^2) = %.6g vs eta_scale*m_p = %.6g', ...
            m_p_eq, p.eta_scale*p.m_p);
    end
    if abs(n_q_eq - p.n_q) / p.n_q > 1e-9
        error('dVOC n_q_eq mismatch: 1/(3*alpha*V) = %.6g vs n_q = %.6g', n_q_eq, p.n_q);
    end
    nPass = nPass+1; fprintf('[PASS] T7: dVOC slope equivalences hold (2*eta/(3*V^2) ~ m_p, 1/(3*alpha*V) = n_q)\n');
catch e
    nFail = nFail+1; fprintf(2, '[FAIL] T7: %s\n', e.message);
end

% ---- Summary ----
fprintf('\n=== test_gfm_design: %d passed, %d failed ===\n', nPass, nFail);
if nFail > 0
    error('test_gfm_design:fail', '%d test(s) failed', nFail);
end

end
