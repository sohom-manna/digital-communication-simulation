function ber_comparison(bpsk, qpsk, theory, results_dir)
%BER_COMPARISON  Create the BER figures and save them as PNG files.
%
%   BER_COMPARISON(bpsk, qpsk, theory, results_dir)
%
%   Inputs
%       bpsk, qpsk    result structs from bpsk_simulation / qpsk_simulation
%       theory        struct with a dense Eb/N0 grid and the theoretical curves
%                     (fields ebn0_db, ber_bpsk, ber_qpsk, ser_qpsk)
%       results_dir   folder that receives the PNG files
%
%   Files written
%       bpsk_ber_vs_ebn0.png   simulated vs theoretical BPSK BER
%       qpsk_ber_vs_ebn0.png   simulated vs theoretical QPSK BER (and SER)
%       ber_comparison.png     BPSK vs QPSK, left: vs Eb/N0, right: vs Es/N0
%
%   Markers are simulation results, lines are theory. Whiskers on the markers
%   of the single-scheme figures are 95% confidence intervals of the Monte
%   Carlo estimate. The right panel of ber_comparison.png re-plots the SAME
%   simulated points on an Es/N0 axis using Es/N0 = k * Eb/N0, where k is the
%   number of bits per symbol; no extra simulation is involved.

    blue   = [0.000 0.447 0.741];      % BPSK
    orange = [0.850 0.325 0.098];      % QPSK
    purple = [0.494 0.184 0.556];      % QPSK symbol error rate
    dark   = [0.15 0.15 0.15];         % theory

    ber_axis_limits = [1e-6 1];

    % ======================= Figure 1: BPSK =============================
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 600], ...
                 'PaperPositionMode', 'auto');
    ax = axes('Parent', fig);
    set(ax, 'YScale', 'log');
    hold(ax, 'on');

    h_theory = plot(ax, theory.ebn0_db, theory.ber_bpsk, '-', 'Color', dark, 'LineWidth', 1.8);
    h_sim    = plot_with_ci(ax, bpsk.ebn0_db, bpsk.ber, bpsk.ber_ci95, blue, 'o', 6);

    style_ber_axes(ax, [-0.2 10.2], ber_axis_limits, 'E_b/N_0 (dB)');
    title(ax, 'BPSK over AWGN: bit error rate vs E_b/N_0', 'FontSize', 14);
    leg = legend(ax, [h_theory h_sim], ...
        {'Theory: Q(sqrt(2E_b/N_0))', 'Simulation (95% CI)'}, 'Location', 'southwest');
    set(leg, 'FontSize', 11);
    add_note(ax, sprintf('Every point has >= %d bit errors. 95%% CI bars are hidden where smaller than the markers.', ...
                         min(bpsk.num_errors)));

    print(fig, '-dpng', '-r150', fullfile(results_dir, 'bpsk_ber_vs_ebn0.png'));
    close(fig);

    % ======================= Figure 2: QPSK =============================
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 600], ...
                 'PaperPositionMode', 'auto');
    ax = axes('Parent', fig);
    set(ax, 'YScale', 'log');
    hold(ax, 'on');

    h_theory_ser = plot(ax, theory.ebn0_db, theory.ser_qpsk, '--', 'Color', purple, 'LineWidth', 1.5);
    h_theory_ber = plot(ax, theory.ebn0_db, theory.ber_qpsk, '-', 'Color', dark, 'LineWidth', 1.8);
    h_sim_ser    = plot_with_ci(ax, qpsk.ebn0_db, qpsk.ser, ...
                       1.96 * sqrt(qpsk.ser .* (1 - qpsk.ser) ./ qpsk.num_symbols), purple, 's', 6);
    h_sim_ber    = plot_with_ci(ax, qpsk.ebn0_db, qpsk.ber, qpsk.ber_ci95, orange, 'o', 6);

    style_ber_axes(ax, [-0.2 10.2], ber_axis_limits, 'E_b/N_0 (dB)');
    ylabel(ax, 'Error rate', 'FontSize', 13);
    title(ax, 'Gray-coded QPSK over AWGN: error rate vs E_b/N_0', 'FontSize', 14);
    leg = legend(ax, [h_theory_ber h_sim_ber h_theory_ser h_sim_ser], ...
        {'BER theory: Q(sqrt(2E_b/N_0))', 'BER simulation (95% CI)', ...
         'SER theory: 1-(1-P_b)^2', 'SER simulation (95% CI)'}, 'Location', 'southwest');
    set(leg, 'FontSize', 11);
    add_note(ax, sprintf('Every point has >= %d bit errors. 95%% CI bars are hidden where smaller than the markers.', ...
                         min(qpsk.num_errors)));

    print(fig, '-dpng', '-r150', fullfile(results_dir, 'qpsk_ber_vs_ebn0.png'));
    close(fig);

    % ================= Figure 3: BPSK vs QPSK comparison =================
    bits_per_symbol_bpsk = 1;
    bits_per_symbol_qpsk = 2;
    % Es/N0 = k * Eb/N0  ->  in dB: Es/N0 = Eb/N0 + 10*log10(k)
    shift_bpsk_db = 10 * log10(bits_per_symbol_bpsk);     % 0 dB
    shift_qpsk_db = 10 * log10(bits_per_symbol_qpsk);     % 3.01 dB

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1400 600], ...
                 'PaperPositionMode', 'auto');

    % ---- left panel: equal Eb/N0 -------------------------------------------
    ax = subplot(1, 2, 1);
    set(ax, 'YScale', 'log');
    hold(ax, 'on');
    h_th  = plot(ax, theory.ebn0_db, theory.ber_bpsk, '-', 'Color', dark, 'LineWidth', 1.8);
    h_bp  = plot(ax, bpsk.ebn0_db, bpsk.ber, 'o', 'Color', blue, 'MarkerSize', 12, ...
                 'LineWidth', 1.8, 'MarkerFaceColor', 'w');
    h_qp  = plot(ax, qpsk.ebn0_db, qpsk.ber, 'd', 'Color', orange, 'MarkerSize', 6, ...
                 'LineWidth', 1.8, 'MarkerFaceColor', orange);
    style_ber_axes(ax, [-0.2 10.2], ber_axis_limits, 'E_b/N_0 (dB)');
    title(ax, {'Equal energy per bit', 'BER vs E_b/N_0'}, 'FontSize', 14);
    pos = get(ax, 'Position');
    set(ax, 'Position', [pos(1) 0.12 pos(3) 0.70]);          % leave room for the 2-line title
    leg = legend(ax, [h_th h_bp h_qp], ...
        {'Theory (BPSK and Gray QPSK)', 'BPSK simulation', 'QPSK simulation'}, ...
        'Location', 'southwest');
    set(leg, 'FontSize', 11);

    % ---- right panel: equal Es/N0 (same data, shifted x axis) ----------------
    ax = subplot(1, 2, 2);
    set(ax, 'YScale', 'log');
    hold(ax, 'on');
    h_th_b = plot(ax, theory.ebn0_db + shift_bpsk_db, theory.ber_bpsk, '-', 'Color', blue, 'LineWidth', 1.8);
    h_th_q = plot(ax, theory.ebn0_db + shift_qpsk_db, theory.ber_qpsk, '-', 'Color', orange, 'LineWidth', 1.8);
    h_bp   = plot(ax, bpsk.ebn0_db + shift_bpsk_db, bpsk.ber, 'o', 'Color', blue, 'MarkerSize', 9, ...
                  'LineWidth', 1.8, 'MarkerFaceColor', 'w');
    h_qp   = plot(ax, qpsk.ebn0_db + shift_qpsk_db, qpsk.ber, 'd', 'Color', orange, 'MarkerSize', 7, ...
                  'LineWidth', 1.8, 'MarkerFaceColor', orange);

    % horizontal gap between the two theory curves at BER = 1e-3
    target_log_ber = -3;
    % (sample points reversed so that log10(BER) is increasing, as interp1 expects)
    ebn0_at_target = interp1(fliplr(log10(theory.ber_bpsk)), fliplr(theory.ebn0_db), target_log_ber);
    plot(ax, ebn0_at_target + [shift_bpsk_db shift_qpsk_db], [1e-3 1e-3], 'k-', 'LineWidth', 1.5);
    plot(ax, ebn0_at_target + [shift_bpsk_db shift_qpsk_db], [1e-3 1e-3], 'k|', 'MarkerSize', 10, 'LineWidth', 1.5);
    text(ebn0_at_target + shift_qpsk_db + 0.35, 1e-3, ...
         sprintf('%.2f dB', shift_qpsk_db - shift_bpsk_db), 'Parent', ax, ...
         'FontSize', 12, 'VerticalAlignment', 'middle');

    style_ber_axes(ax, [-0.2 13.2], ber_axis_limits, 'E_s/N_0 (dB)');
    title(ax, {'Equal energy per symbol', 'same simulated points re-plotted vs E_s/N_0 = k E_b/N_0'}, ...
          'FontSize', 14);
    pos = get(ax, 'Position');
    set(ax, 'Position', [pos(1) 0.12 pos(3) 0.70]);
    leg = legend(ax, [h_th_b h_th_q h_bp h_qp], ...
        {'BPSK theory', 'QPSK theory', 'BPSK simulation', 'QPSK simulation'}, ...
        'Location', 'southwest');
    set(leg, 'FontSize', 11);

    print(fig, '-dpng', '-r150', fullfile(results_dir, 'ber_comparison.png'));
    close(fig);
end

% ---------------------------------------------------------------------------
function handle = plot_with_ci(ax, x, y, ci, color, marker, marker_size)
% Plot Monte Carlo estimates as markers with vertical 95% CI whiskers.
% The whiskers are one line object made of NaN-separated segments.
    ci_low  = max(y - ci, realmin);                % keep the log axis valid
    ci_high = y + ci;
    cap     = 0.12;                                % half width of the whisker caps (dB)
    gap     = nan(size(x));
    % per point: vertical bar, lower cap, upper cap (columns -> flattened in order)
    whisker_x = [x;      x;       gap; x - cap; x + cap; gap; x - cap; x + cap; gap];
    whisker_y = [ci_low; ci_high; gap; ci_low;  ci_low;  gap; ci_high; ci_high; gap];
    plot(ax, whisker_x(:).', whisker_y(:).', '-', 'Color', color, 'LineWidth', 1.5);
    handle = plot(ax, x, y, marker, 'Color', color, 'MarkerSize', marker_size, ...
                  'LineWidth', 1.6, 'MarkerFaceColor', 'w');
end

% ---------------------------------------------------------------------------
function style_ber_axes(ax, x_limits, y_limits, x_label)
% Common formatting of the semilogarithmic BER axes.
    set(ax, 'XLim', x_limits, 'YLim', y_limits, 'FontSize', 12, 'Box', 'on', ...
            'XGrid', 'on', 'YGrid', 'on', 'YMinorGrid', 'on', 'XMinorGrid', 'off');
    xlabel(ax, x_label, 'FontSize', 13);
    ylabel(ax, 'Bit error rate (BER)', 'FontSize', 13);
end

% ---------------------------------------------------------------------------
function add_note(ax, note_text)
% Small grey note in the upper right corner of the axes.
    text(0.98, 0.97, note_text, 'Parent', ax, 'Units', 'normalized', 'FontSize', 10, ...
         'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'Color', [0.35 0.35 0.35]);
end
