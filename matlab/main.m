%% Digital Communication System Simulation: BPSK and QPSK over AWGN
%
% Runs the complete experiment:
%   1. Monte Carlo BER simulation of BPSK and QPSK over an AWGN channel
%   2. Theoretical BER curves
%   3. Figures (results/ and figures/), numerical table (results/ber_results.csv)
%   4. Automated validation checks
%
% Run from MATLAB:   run('matlab/main.m')   (from the repository root)
%               or:  cd matlab; main
% Run from Octave:   octave --no-gui matlab/main.m
%
% Only base MATLAB (no toolboxes) is required.

clear; close all;

%% ---------------------------- Simulation parameters ---------------------------
cfg.ebn0_db        = 0:1:10;   % Eb/N0 sweep in dB
cfg.bits_per_block = 1e6;      % N_BITS: bits per vectorised Monte Carlo block (must be even)
cfg.min_errors     = 100;      % stop an Eb/N0 point once this many bit errors are counted
cfg.max_bits       = 1e8;      % never simulate more than this many bits per Eb/N0 point
cfg.seed           = 42;       % random seed (fixed -> reproducible); BPSK uses seed, QPSK seed + 1
cfg.sample_symbols = 2000;     % received symbols kept for the constellation plot / checks

constellation_ebn0_db = [0 5 10];       % Eb/N0 values shown in the constellation diagram
theory_ebn0_db        = 0:0.1:10;       % dense grid for smooth theory curves

%% ---------------------------------- Paths ---------------------------------------
matlab_dir  = fileparts(mfilename('fullpath'));
project_dir = fileparts(matlab_dir);
results_dir = fullfile(project_dir, 'results');
figures_dir = fullfile(project_dir, 'figures');
addpath(matlab_dir);
if ~exist(results_dir, 'dir'), mkdir(results_dir); end
if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end

% Octave only: the Qt toolkit gives MATLAB-like figures (MATLAB ignores this block).
if exist('OCTAVE_VERSION', 'builtin') ~= 0
    if any(strcmp(available_graphics_toolkits(), 'qt'))
        graphics_toolkit('qt');
    else
        warning(['Octave Qt graphics toolkit not available; saving figures with another ' ...
                 'toolkit may fail. On headless Linux run:  xvfb-run -a octave --no-gui matlab/main.m']);
    end
end

%% ----------------------------- Monte Carlo simulation ---------------------------
fprintf('Digital communication simulation: BPSK and QPSK over AWGN\n');
fprintf('Eb/N0 = %g ... %g dB, %g bits per block, >= %d errors per point, seed %d\n\n', ...
        cfg.ebn0_db(1), cfg.ebn0_db(end), cfg.bits_per_block, cfg.min_errors, cfg.seed);

% Each scheme gets its own random stream (seed and seed + 1). With a single shared
% seed both simulations would draw identical bits and identical noise values, which
% correlates their BER estimates and makes the BPSK-vs-QPSK comparison less meaningful.
cfg_bpsk = cfg;                      % seed 42
cfg_qpsk = cfg;
cfg_qpsk.seed = cfg.seed + 1;        % seed 43

tic;
bpsk = bpsk_simulation(cfg_bpsk);
fprintf('BPSK simulation finished in %.1f s\n', toc);

tic;
qpsk = qpsk_simulation(cfg_qpsk);
fprintf('QPSK simulation finished in %.1f s\n\n', toc);

%% ------------------------------- Theoretical BER ---------------------------------
[theory_bpsk, theory_qpsk, theory_ser] = theoretical_ber(cfg.ebn0_db);   % at the simulated points

theory.ebn0_db  = theory_ebn0_db;                                        % dense grid for plots
[theory.ber_bpsk, theory.ber_qpsk, theory.ser_qpsk] = theoretical_ber(theory_ebn0_db);

%% ------------------------------- Console summary --------------------------------
fprintf('%6s | %11s %11s | %11s %11s | %11s %11s | %9s %9s\n', ...
        'Eb/N0', 'BPSK BER', 'theory', 'QPSK BER', 'theory', ...
        'QPSK SER', 'theory', 'BPSK bits', 'QPSK bits');
for p = 1:numel(cfg.ebn0_db)
    fprintf('%4g dB | %11.4e %11.4e | %11.4e %11.4e | %11.4e %11.4e | %9.2e %9.2e\n', ...
            cfg.ebn0_db(p), bpsk.ber(p), theory_bpsk(p), qpsk.ber(p), theory_qpsk(p), ...
            qpsk.ser(p), theory_ser(p), bpsk.num_bits(p), qpsk.num_bits(p));
end

%% ------------------------------ Numerical results (CSV) ---------------------------
csv_path = fullfile(results_dir, 'ber_results.csv');
fid = fopen(csv_path, 'w');
fprintf(fid, ['scheme,ebn0_db,bits_simulated,bit_errors,ber_simulated,ber_ci95_halfwidth,' ...
              'ber_theoretical,symbols_simulated,symbol_errors,ser_simulated,ser_theoretical\n']);
for p = 1:numel(cfg.ebn0_db)
    fprintf(fid, 'BPSK,%g,%d,%d,%.6e,%.3e,%.6e,%d,%d,%.6e,%.6e\n', cfg.ebn0_db(p), ...
            bpsk.num_bits(p), bpsk.num_errors(p), bpsk.ber(p), bpsk.ber_ci95(p), theory_bpsk(p), ...
            bpsk.num_symbols(p), bpsk.symbol_errors(p), bpsk.ser(p), theory_bpsk(p));
end
for p = 1:numel(cfg.ebn0_db)
    fprintf(fid, 'QPSK,%g,%d,%d,%.6e,%.3e,%.6e,%d,%d,%.6e,%.6e\n', cfg.ebn0_db(p), ...
            qpsk.num_bits(p), qpsk.num_errors(p), qpsk.ber(p), qpsk.ber_ci95(p), theory_qpsk(p), ...
            qpsk.num_symbols(p), qpsk.symbol_errors(p), qpsk.ser(p), theory_ser(p));
end
fclose(fid);

%% ----------------------------------- Figures -------------------------------------
ber_comparison(bpsk, qpsk, theory, results_dir);
plot_constellation(qpsk, constellation_ebn0_db, fullfile(results_dir, 'constellation_diagram.png'));
draw_block_diagram(fullfile(figures_dir, 'system_block_diagram.png'));
fprintf('\nFigures and CSV written to:\n  %s\n  %s\n', results_dir, figures_dir);

%% -------------------------------- Validation ---------------------------------------
validate_simulation(bpsk, qpsk, cfg);
