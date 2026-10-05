function plot_constellation(qpsk, target_ebn0_db, out_file)
%PLOT_CONSTELLATION  Received QPSK constellation at several Eb/N0 values.
%
%   PLOT_CONSTELLATION(qpsk, target_ebn0_db, out_file)
%
%   qpsk            result struct from qpsk_simulation (uses qpsk.sample)
%   target_ebn0_db  Eb/N0 values to show (must be part of the simulated sweep)
%   out_file        PNG file to write
%
%   The plotted points are the first received symbols of the simulation run
%   itself (not a separate demo). Colour = transmitted symbol, black dots =
%   ideal constellation points, dashed lines = decision boundaries (I = 0,
%   Q = 0). A received point lying in a quadrant of a different colour is a
%   symbol error. Bit labels b0 b1 follow the Gray mapping of qpsk_simulation.

    % Ideal points: sign of I and Q for each transmitted bit pair (b0 b1)
    bit_labels  = {'11', '01', '00', '10'};
    i_sign      = [ 1, -1, -1,  1];
    q_sign      = [ 1,  1, -1, -1];
    ideal_point = (i_sign + 1i * q_sign) / sqrt(2);

    colors = [0.000 0.447 0.741;     % 11
              0.929 0.694 0.125;     % 01
              0.466 0.674 0.188;     % 00
              0.850 0.325 0.098];    % 10

    axis_limit = 2;
    num_panels = numel(target_ebn0_db);

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1500 520], ...
                 'PaperPositionMode', 'auto');

    for panel = 1:num_panels
        [~, point] = min(abs(qpsk.ebn0_db - target_ebn0_db(panel)));
        tx = qpsk.sample.tx_symbols(point, :);
        rx = qpsk.sample.rx_symbols(point, :);

        ax = subplot(1, num_panels, panel);
        hold(ax, 'on');

        % received symbols, coloured by the transmitted symbol
        for k = 1:4
            sent_k = (sign(real(tx)) == i_sign(k)) & (sign(imag(tx)) == q_sign(k));
            plot(ax, real(rx(sent_k)), imag(rx(sent_k)), '.', 'Color', colors(k, :), 'MarkerSize', 7);
        end

        % decision boundaries and ideal points
        plot(ax, [-axis_limit axis_limit], [0 0], 'k--', 'LineWidth', 1);
        plot(ax, [0 0], [-axis_limit axis_limit], 'k--', 'LineWidth', 1);
        plot(ax, real(ideal_point), imag(ideal_point), 'ko', 'MarkerSize', 10, ...
             'MarkerFaceColor', 'k', 'LineWidth', 1.5);

        % Gray bit labels b0 b1 in each quadrant
        for k = 1:4
            text(1.35 * i_sign(k), 1.75 * q_sign(k), bit_labels{k}, 'Parent', ax, ...
                 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 14, ...
                 'Color', colors(k, :) * 0.75);
        end

        % symbol errors among the plotted symbols (wrong quadrant)
        wrong_quadrant = (sign(real(rx)) ~= sign(real(tx))) | (sign(imag(rx)) ~= sign(imag(tx)));
        num_shown = numel(tx);

        set(ax, 'XLim', [-axis_limit axis_limit], 'YLim', [-axis_limit axis_limit], ...
                'FontSize', 12, 'Box', 'on', 'XGrid', 'on', 'YGrid', 'on');
        axis(ax, 'square');
        xlabel(ax, 'In-phase (I)', 'FontSize', 13);
        ylabel(ax, 'Quadrature (Q)', 'FontSize', 13);
        title(ax, {sprintf('E_b/N_0 = %g dB', qpsk.ebn0_db(point)), ...
                   sprintf('%d of %d plotted symbols in error', sum(wrong_quadrant), num_shown)}, ...
              'FontSize', 14);
    end

    print(fig, '-dpng', '-r150', out_file);
    close(fig);
end
