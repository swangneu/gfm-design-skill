function gfm_generate_variant(targetFolder, varargin)
%GFM_GENERATE_VARIANT  Scaffold a new GFM variant folder (params + build + run).
%
%   gfm_generate_variant('my_new_variant', 'law', 'droop', 'topology', 'single')
%
%   Creates targetFolder with three files matching the repo's existing pattern:
%     gfm_params.m              - parameter struct (assignin 'p' in base ws)
%     build_gfm_<law>_<topo>.m  - programmatic Simulink model builder
%     run_gfm_<law>_<topo>_sim.m - sim + plot + summary wrapper
%
%   The user then runs:
%     >> cd my_new_variant
%     >> build_gfm_<law>_<topo>    % generates the .slx
%     >> run_gfm_<law>_<topo>_sim  % simulates and writes runs/<timestamp>/
%
%   Required name-value arguments:
%     'law'      - 'droop' | 'vsg' | 'dvoc' | 'psc'
%     'topology' - 'single' | 'double'
%
%   Optional name-value (all forwarded to gfm_design_from_specs):
%     'overwrite' - true to clobber existing targetFolder (default false)
%     'repo_root' - path to repo root (default: parent of this script's
%                   parent's parent, i.e. d:\AI\GFM)
%     Plus all options of gfm_design_from_specs (droop_w_pct, H_inertia,
%     eta_scale, kappa, R_v, ...). See `help gfm_design_from_specs`.
%
%   Supported (law, topology) combinations in this version:
%     - droop, single   (base: <repo>/single/)
%     - droop, double   (base: <repo>/double/)
%     - vsg,   double   (base: <repo>/double_vsg/)
%     - dvoc,  double   (base: <repo>/double_dvoc/)
%
%   For new combinations (vsg+single, dvoc+single, psc+*) this function
%   errors with a clear message pointing to the controller-code template
%   you need to add under references/<law>-design.md. Adding a new combo
%   means writing a controller-code template (a function returning the
%   MATLAB Function block's code string) and registering it below.
%
%   Example - clone the droop baseline with steeper droop:
%     >> gfm_generate_variant('single_steep', ...
%            'law','droop','topology','single', ...
%            'droop_w_pct', 3, 'droop_v_pct', 8);
%
%   See also: gfm_design_from_specs, gfm_predict_steady_state.

% ---- Parse args ----
ip = inputParser;
ip.KeepUnmatched = true;
ip.addRequired('targetFolder', @ischar);
ip.addParameter('law',         '', @ischar);
ip.addParameter('topology',    '', @ischar);
ip.addParameter('overwrite',   false, @islogical);
ip.addParameter('repo_root',   '', @ischar);
ip.parse(targetFolder, varargin{:});

law      = lower(ip.Results.law);
topology = lower(ip.Results.topology);
if isempty(law) || isempty(topology)
    error('gfm_generate_variant:missingArgs', ...
        'Both ''law'' and ''topology'' are required.');
end

repoRoot = ip.Results.repo_root;
if isempty(repoRoot)
    % Default: this file is at <repo>/.claude/skills/gfm-design/scripts/<this>
    % so repo root = ../../../..
    thisDir  = fileparts(mfilename('fullpath'));
    repoRoot = fullfile(thisDir, '..', '..', '..', '..');
    repoRoot = char(java.io.File(repoRoot).getCanonicalPath());
end

% ---- Resolve base variant folder ----
[baseFolder, baseBuildFile, baseRunFile, baseModelName] = ...
    resolveBase(repoRoot, law, topology);

% ---- Validate target folder ----
if exist(targetFolder, 'dir')
    if ~ip.Results.overwrite
        error('gfm_generate_variant:exists', ...
            'Target folder %s already exists. Pass ''overwrite'', true to clobber.', ...
            targetFolder);
    end
    fprintf('[gen] Overwriting existing folder: %s\n', targetFolder);
else
    [ok, msg] = mkdir(targetFolder);
    if ~ok, error('gfm_generate_variant:mkdir', msg); end
end

% ---- Build parameter struct via design tool ----
% Forward all extra name-value pairs to gfm_design_from_specs.
extraArgs = unmatchedToCellArray(ip.Unmatched);
p = gfm_design_from_specs('law', law, 'topology', topology, extraArgs{:});

% ---- Write gfm_params.m from p ----
paramsPath = fullfile(targetFolder, 'gfm_params.m');
writeParamsFile(paramsPath, p, law, topology);
fprintf('[gen] Wrote %s\n', paramsPath);

% ---- Decide new file/model names ----
newModelName  = sprintf('gfm_%s_%s', law, topology);
newBuildFunc  = sprintf('build_gfm_%s_%s', law, topology);
newRunFunc    = sprintf('run_gfm_%s_%s_sim', law, topology);
newBuildFile  = [newBuildFunc '.m'];
newRunFile    = [newRunFunc '.m'];

% ---- Copy build_*.m with substitutions ----
% Substitution order matters: when baseBuildFunc *contains* baseModelName as
% a substring (e.g. 'build_gfm_droop_inverter' contains 'gfm_droop_inverter'),
% the function-name substitution must run first.
buildSrc  = fullfile(baseFolder, baseBuildFile);
buildDst  = fullfile(targetFolder, newBuildFile);
baseBuildFunc = strrep(baseBuildFile, '.m', '');
substitutions = { ...
    baseBuildFunc,         newBuildFunc; ...
    upper(baseBuildFunc),  upper(newBuildFunc); ...
    baseModelName,         newModelName};
copyAndSubstitute(buildSrc, buildDst, substitutions);
fprintf('[gen] Wrote %s\n', buildDst);

% ---- Copy run_*_sim.m with substitutions ----
runSrc = fullfile(baseFolder, baseRunFile);
runDst = fullfile(targetFolder, newRunFile);
baseRunFunc = strrep(baseRunFile, '.m', '');
substitutions = { ...
    baseRunFunc,         newRunFunc; ...
    upper(baseRunFunc),  upper(newRunFunc); ...
    baseBuildFunc,       newBuildFunc; ...
    upper(baseBuildFunc),upper(newBuildFunc); ...
    baseModelName,       newModelName};
copyAndSubstitute(runSrc, runDst, substitutions);
fprintf('[gen] Wrote %s\n', runDst);

% ---- Summary ----
fprintf('\n[gen] Variant ready in %s\n', targetFolder);
fprintf('[gen] Next steps:\n');
fprintf('        cd %s\n', targetFolder);
fprintf('        %s    %% builds .slx\n', newBuildFunc);
fprintf('        %s    %% simulates and writes runs/<ts>/\n', newRunFunc);
fprintf('[gen] After sim, switch to the gfm-validation skill to verify.\n');

end


% =====================================================================
function [baseFolder, baseBuildFile, baseRunFile, baseModelName] = ...
    resolveBase(repoRoot, law, topology)

% Map (law, topology) -> existing reference variant.
% New combinations require adding a controller-code template; see SKILL.md.
key = sprintf('%s+%s', law, topology);
switch key
    case 'droop+single'
        baseFolder    = fullfile(repoRoot, 'single');
        baseBuildFile = 'build_gfm_droop_inverter.m';
        baseRunFile   = 'run_gfm_sim.m';
        baseModelName = 'gfm_droop_inverter';
    case 'droop+double'
        baseFolder    = fullfile(repoRoot, 'double');
        baseBuildFile = 'build_gfm_double_inverter.m';
        baseRunFile   = 'run_gfm_double_sim.m';
        baseModelName = 'gfm_droop_double';
    case 'vsg+double'
        baseFolder    = fullfile(repoRoot, 'double_vsg');
        baseBuildFile = 'build_gfm_double_vsg.m';
        baseRunFile   = 'run_gfm_double_vsg_sim.m';
        baseModelName = 'gfm_vsg_double';
    case 'dvoc+double'
        baseFolder    = fullfile(repoRoot, 'double_dvoc');
        baseBuildFile = 'build_gfm_double_dvoc.m';
        baseRunFile   = 'run_gfm_double_dvoc_sim.m';
        baseModelName = 'gfm_dvoc_double';
    otherwise
        error('gfm_generate_variant:unsupportedCombo', ...
            ['No reference variant for (law=%s, topology=%s).\n' ...
             'Supported: droop+single, droop+double, vsg+double, dvoc+double.\n' ...
             'To add a new combination:\n' ...
             '  1. Pick the closest existing base folder.\n' ...
             '  2. Copy that folder and rename it to your target.\n' ...
             '  3. Replace the makeControllerCode function body using\n' ...
             '     the math from references/%s-design.md.\n' ...
             '  4. Update gfm_params.m fields per the chosen law.\n' ...
             '  5. Register the new (law, topology) here in resolveBase().'], ...
            law, topology, law);
end

if ~exist(baseFolder, 'dir')
    error('gfm_generate_variant:baseNotFound', ...
        'Base folder does not exist: %s\nPass ''repo_root'' if running outside the repo.', ...
        baseFolder);
end
end


% =====================================================================
function writeParamsFile(filePath, p, law, topology)
% Emit a gfm_params.m matching the repo's style, populated from struct p.

fid = fopen(filePath, 'w');
if fid < 0
    error('gfm_generate_variant:fopen', 'Cannot open for write: %s', filePath);
end
clean = onCleanup(@() fclose(fid));

fprintf(fid, 'function p = gfm_params()\n');
fprintf(fid, '%%GFM_PARAMS  Auto-generated by gfm_generate_variant.\n');
fprintf(fid, '%%   Law=%s, Topology=%s. Returns struct p and assigns ''p'' in base ws.\n\n', ...
    law, topology);
fprintf(fid, 'p = struct();\n\n');

% --- Grid ---
fprintf(fid, '%% --- Grid ---\n');
W('f_n',      p.f_n);
W('w_n',      p.w_n,      '2*pi*p.f_n');
W('V_LL_rms', p.V_LL_rms);
W('V_ph_rms', p.V_ph_rms, 'p.V_LL_rms/sqrt(3)');
W('V_peak',   p.V_peak,   'p.V_ph_rms*sqrt(2)');
fprintf(fid, '\n');

% --- Rated power ---
fprintf(fid, '%% --- Rated power ---\n');
W('S_rated', p.S_rated);
W('I_peak',  p.I_peak,   'p.S_rated*sqrt(2)/(sqrt(3)*p.V_LL_rms)');
fprintf(fid, '\n');

% --- DC bus ---
fprintf(fid, '%% --- DC bus ---\n');
W('V_dc',    p.V_dc);
fprintf(fid, '\n');

% --- LCL ---
fprintf(fid, '%% --- LCL filter ---\n');
W('L_f', p.L_f);  W('R_f', p.R_f);
W('C_f', p.C_f);  W('R_d', p.R_d);
W('L_2', p.L_2);  W('R_2', p.R_2);
fprintf(fid, '\n');

% --- Grid impedance ---
fprintf(fid, '%% --- Grid impedance ---\n');
W('L_g', p.L_g);  W('R_g', p.R_g);
fprintf(fid, '\n');

% --- Switching ---
fprintf(fid, '%% --- Switching / sampling ---\n');
W('f_sw',     p.f_sw);
W('Ts_power', p.Ts_power);
W('Ts_ctrl',  p.Ts_ctrl);
fprintf(fid, '\n');

% --- Setpoints (topology-dependent) ---
fprintf(fid, '%% --- Setpoints ---\n');
if strcmpi(topology, 'single')
    W('P_ref',   p.P_ref);
    W('Q_ref',   p.Q_ref);
    fprintf(fid, '\n%% --- P_ref step schedule ---\n');
    W('t_step1', p.t_step1);  W('P_step1', p.P_step1);
    W('t_step2', p.t_step2);  W('P_step2', p.P_step2);
else
    W('P_ref1',  p.P_ref1);   W('P_ref2', p.P_ref2);
    W('Q_ref',   p.Q_ref);
    fprintf(fid, '\n%% --- P_ref step schedule (Inf disables) ---\n');
    W('t_step1_1', p.t_step1_1);  W('P_step1_1', p.P_step1_1);
    W('t_step2_1', p.t_step2_1);  W('P_step2_1', p.P_step2_1);
    W('t_step1_2', p.t_step1_2);  W('P_step1_2', p.P_step1_2);
    W('t_step2_2', p.t_step2_2);  W('P_step2_2', p.P_step2_2);
end
fprintf(fid, '\n');

% --- Power LPF ---
fprintf(fid, '%% --- Power LPF ---\n');
W('f_pwr_filt', p.f_pwr_filt);
W('w_pwr_filt', p.w_pwr_filt, '2*pi*p.f_pwr_filt');
fprintf(fid, '\n');

% --- Droop slopes (always present) ---
fprintf(fid, '%% --- Droop slopes ---\n');
W('m_p', p.m_p, sprintf('%g * p.w_n / p.S_rated', p.m_p * p.S_rated / p.w_n));
W('n_q', p.n_q, sprintf('%g * p.V_peak / p.S_rated', p.n_q * p.S_rated / p.V_peak));
fprintf(fid, '\n');

% --- Inner V/I PI gains ---
fprintf(fid, '%% --- Inner V/I PI gains ---\n');
W('Kp_i', p.Kp_i);  W('Ki_i', p.Ki_i);
W('Kp_v', p.Kp_v);  W('Ki_v', p.Ki_v);
fprintf(fid, '\n');

% --- Law-specific fields ---
fprintf(fid, '%% --- Law-specific (law=%s) ---\n', law);
switch law
    case 'droop'
        % nothing extra
    case 'vsg'
        W('H_inertia', p.H_inertia);
        W('J_vsg',     p.J_vsg, '2*p.H_inertia*p.S_rated/p.w_n^2');
        W('D_vsg',     p.D_vsg, '1/p.m_p');
        W('K_q',       p.K_q,   'p.n_q');
    case 'dvoc'
        W('kappa',     p.kappa);
        W('eta_scale', p.eta_scale);
        W('eta',       p.eta,   'p.eta_scale*1.5*p.m_p*p.V_peak^2');
        W('alpha',     p.alpha, '1/(3*p.n_q*p.V_peak)');
    case 'psc'
        W('k_p',       p.k_p,   'p.m_p');
        W('R_v',       p.R_v);
end
fprintf(fid, '\n');

% --- Law tag (used at runtime to dispatch controllers if needed) ---
fprintf(fid, 'p.law = ''%s'';\n\n', law);

% --- Virtual impedance overlay ---
if isfield(p, 'R_v_pcc') && p.R_v_pcc ~= 0
    fprintf(fid, '%% Virtual impedance overlay (resistive)\n');
    W('R_v_pcc', p.R_v_pcc);
end
if isfield(p, 'L_v_pcc') && p.L_v_pcc ~= 0
    fprintf(fid, '%% Virtual impedance overlay (inductive)\n');
    W('L_v_pcc', p.L_v_pcc);
end

% --- Simulation ---
fprintf(fid, '%% --- Simulation ---\n');
W('t_stop',  p.t_stop);
fprintf(fid, '\n');

fprintf(fid, 'assignin(''base'',''p'',p);\n');
fprintf(fid, 'end\n');

    % --- Nested writer ---
    function W(name, val, expr)
        if nargin < 3, expr = ''; end
        if isempty(expr)
            fprintf(fid, 'p.%-12s = %s;\n', name, formatScalar(val));
        else
            fprintf(fid, 'p.%-12s = %s;\n', name, expr);
        end
    end
end


% =====================================================================
function s = formatScalar(x)
% Compact scalar formatting that round-trips for double values.
if isinf(x)
    if x > 0, s = 'Inf'; else, s = '-Inf'; end
elseif isnan(x)
    s = 'NaN';
elseif x == floor(x) && abs(x) < 1e9
    s = sprintf('%d', int64(x));
else
    s = sprintf('%.12g', x);
end
end


% =====================================================================
function copyAndSubstitute(srcPath, dstPath, subs)
% subs: Nx2 cell array of {oldStr, newStr; ...} pairs, applied in order.
txt = fileread(srcPath);
for k = 1:size(subs, 1)
    oldStr = subs{k,1};
    newStr = subs{k,2};
    if ~isempty(oldStr) && ~strcmp(oldStr, newStr)
        txt = strrep(txt, oldStr, newStr);
    end
end
fid = fopen(dstPath, 'w');
if fid < 0
    error('gfm_generate_variant:fopen', 'Cannot open: %s', dstPath);
end
fwrite(fid, txt);
fclose(fid);
end


% =====================================================================
function ca = unmatchedToCellArray(unmatched)
% Convert inputParser Unmatched struct -> {name,value,name,value,...} pairs.
fns = fieldnames(unmatched);
ca  = cell(1, 2*numel(fns));
for k = 1:numel(fns)
    ca{2*k-1} = fns{k};
    ca{2*k}   = unmatched.(fns{k});
end
end
