function [Kp_i, Ki_i, Kp_v, Ki_v] = gfm_inner_loop_tuning(p, varargin)
%GFM_INNER_LOOP_TUNING  Bandwidth-driven PI gains for inner V/I loops.
%
%   [Kp_i, Ki_i, Kp_v, Ki_v] = gfm_inner_loop_tuning(p)
%   returns gains targeting f_bw_i = 1 kHz and f_bw_v = 100 Hz.
%
%   Optional name-value:
%     'f_bw_i'  - inner current loop target bandwidth (Hz). Default 1000.
%     'f_bw_v'  - outer voltage loop target bandwidth (Hz). Default 100.
%     'plot'    - true to draw Bode plot of inner I plant + loop. Default false.
%
%   Method:
%     Inner I: plant 1/(L_f*s + R_f). PI cancels the plant pole at Ki/Kp = R_f/L_f.
%             Then T(s) = Kp/(L_f*s + Kp) → bandwidth = Kp/L_f.
%             Kp_i = w_bw_i * L_f ;  Ki_i = w_bw_i * R_f.
%     Outer V: heuristic; assumes inner I closed at f_bw_i, plant ≈ 1/(C_f*s).
%             Kp_v = w_bw_v * C_f * scale ;  Ki_v = Kp_v * w_bw_v / 5.
%
%   The outer-V scale factor depends on per-unit conventions; the default
%   here is calibrated for the repo's 480 V / 10 kVA plant. Re-tune via
%   gfm_smallsignal.m if accuracy matters.

ip = inputParser;
ip.addParameter('f_bw_i', 1000, @(x)isnumeric(x)&&x>0);
ip.addParameter('f_bw_v', 100,  @(x)isnumeric(x)&&x>0);
ip.addParameter('plot',   false,@islogical);
ip.parse(varargin{:});
opt = ip.Results;

if opt.f_bw_v > opt.f_bw_i/5
    warning('gfm_inner_loop_tuning:bw_ladder', ...
        'f_bw_v=%g Hz should be << f_bw_i=%g Hz (5x separation).', ...
        opt.f_bw_v, opt.f_bw_i);
end
if opt.f_bw_i > p.f_sw/4
    warning('gfm_inner_loop_tuning:bw_i_high', ...
        'f_bw_i=%g Hz > f_sw/4=%g Hz.', opt.f_bw_i, p.f_sw/4);
end

w_bw_i = 2*pi*opt.f_bw_i;
Kp_i   = w_bw_i * p.L_f;
Ki_i   = w_bw_i * p.R_f;

w_bw_v = 2*pi*opt.f_bw_v;
Kp_v   = w_bw_v * p.C_f * 100;       % heuristic scale
Ki_v   = Kp_v * w_bw_v / 5;

% --- Optional Bode of inner I plant + closed loop ---
if opt.plot
    s = tf('s');
    plant = 1 / (p.L_f * s + p.R_f);
    Cpi   = Kp_i + Ki_i/s;
    open  = plant * Cpi;
    closed = feedback(open, 1);

    figure;
    bode(plant, 'b', open, 'r', closed, 'k');
    grid on;
    legend('Plant 1/(L*s+R)', 'Open loop C*P', 'Closed loop', 'Location','best');
    title(sprintf('Inner current loop: target f_{bw} = %g Hz', opt.f_bw_i));
end

end
