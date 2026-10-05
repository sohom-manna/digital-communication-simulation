function draw_block_diagram(out_file)
%DRAW_BLOCK_DIAGRAM  Draw the conceptual system block diagram and save it as PNG.
%
%   DRAW_BLOCK_DIAGRAM(out_file)
%
%   Random bits with identical statistics (equiprobable 0/1) feed a BPSK chain
%   (left) and a QPSK chain (right). Both chains see an AWGN channel with the
%   same Eb/N0 (separate random streams in the simulation), are detected
%   coherently, and are scored by the same BER analysis, so the two schemes
%   are compared under equivalent conditions.

    blue_fill   = [0.84 0.91 0.97];  blue_edge   = [0.000 0.447 0.741];
    orange_fill = [0.99 0.89 0.84];  orange_edge = [0.850 0.325 0.098];
    gray_fill   = [0.93 0.93 0.93];  gray_edge   = [0.25 0.25 0.25];
    arrow_color = [0.2 0.2 0.2];

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 850 1000], ...
                 'PaperPositionMode', 'auto');
    ax = axes('Parent', fig, 'Position', [0 0 1 1]);
    hold(ax, 'on');
    axis(ax, [-6 100 0 125]);
    axis(ax, 'equal');
    axis(ax, 'off');

    % ---- blocks: draw_box(ax, x, y, width, height, lines, fill, edge) --------
    draw_box(ax, 6, 106, 88, 14, {'Random binary data', ...
        'equiprobable 0/1 bits, same statistics for both systems'}, gray_fill, gray_edge);

    draw_box(ax, 6, 82, 41, 14, {'BPSK modulator', 'bit 0 -> -1,  bit 1 -> +1', ...
        '1 bit per symbol'}, blue_fill, blue_edge);
    draw_box(ax, 53, 82, 41, 14, {'QPSK modulator', 'Gray I/Q mapping', ...
        '2 bits per symbol'}, orange_fill, orange_edge);

    draw_box(ax, 6, 58, 88, 14, {'AWGN channel:  r = s + n', ...
        'same E_b/N_0 for both systems;  n ~ N(0, N_0/2) per real dimension'}, ...
        gray_fill, gray_edge);

    draw_box(ax, 6, 34, 41, 14, {'Coherent BPSK detector', 'decide bit = 1 if r > 0'}, ...
        blue_fill, blue_edge);
    draw_box(ax, 53, 34, 41, 14, {'Coherent QPSK detector', 'sign of I and of Q,', ...
        'then parallel-to-serial'}, orange_fill, orange_edge);

    draw_box(ax, 6, 16, 88, 10, {'Recovered bits'}, gray_fill, gray_edge);

    draw_box(ax, 6, 0.5, 88, 11, {'BER analysis', ...
        'compare with transmitted bits, Monte Carlo average, plot vs theory'}, ...
        gray_fill, gray_edge);

    % ---- arrows ------------------------------------------------------------
    draw_arrow(ax, 26.5, 106, 26.5, 96, arrow_color);     % source -> BPSK modulator
    draw_arrow(ax, 73.5, 106, 73.5, 96, arrow_color);     % source -> QPSK modulator
    draw_arrow(ax, 26.5, 82, 26.5, 72, arrow_color);      % modulators -> channel
    draw_arrow(ax, 73.5, 82, 73.5, 72, arrow_color);
    draw_arrow(ax, 26.5, 58, 26.5, 48, arrow_color);      % channel -> detectors
    draw_arrow(ax, 73.5, 58, 73.5, 48, arrow_color);
    draw_arrow(ax, 26.5, 34, 26.5, 26, arrow_color);      % detectors -> recovered bits
    draw_arrow(ax, 73.5, 34, 73.5, 26, arrow_color);
    draw_arrow(ax, 50, 16, 50, 11.5, arrow_color);        % recovered bits -> BER analysis

    % transmitted bits are also needed as the reference for the BER analysis
    plot(ax, [6 1.5 1.5], [113 113 6], '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.3);
    draw_arrow(ax, 1.5, 6, 6, 6, [0.45 0.45 0.45]);
    text(-2.2, 60, 'transmitted bits (reference)', 'Parent', ax, 'Rotation', 90, ...
         'FontSize', 10, 'HorizontalAlignment', 'center', 'Color', [0.35 0.35 0.35]);

    print(fig, '-dpng', '-r150', out_file);
    close(fig);
end

% ---------------------------------------------------------------------------
function draw_box(ax, x, y, w, h, lines, face_color, edge_color)
% Rounded rectangle with centred text; the first line is bold.
    rectangle('Parent', ax, 'Position', [x y w h], 'Curvature', [0.12 0.12], ...
              'FaceColor', face_color, 'EdgeColor', edge_color, 'LineWidth', 1.8);
    num_lines = numel(lines);
    line_gap  = 3.6;
    first_y   = y + h / 2 + (num_lines - 1) * line_gap / 2;
    for k = 1:num_lines
        if k == 1
            weight = 'bold';  size_pt = 13;
        else
            weight = 'normal';  size_pt = 10.5;
        end
        text(x + w / 2, first_y - (k - 1) * line_gap, lines{k}, 'Parent', ax, ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
             'FontWeight', weight, 'FontSize', size_pt);
    end
end

% ---------------------------------------------------------------------------
function draw_arrow(ax, x1, y1, x2, y2, color)
% Straight arrow from (x1,y1) to (x2,y2) with a filled triangular head.
    head_length = 2.6;
    head_width  = 1.3;
    direction = [x2 - x1, y2 - y1];
    direction = direction / norm(direction);
    normal    = [-direction(2), direction(1)];
    tip       = [x2 y2];
    base      = tip - head_length * direction;
    plot(ax, [x1 base(1)], [y1 base(2)], '-', 'Color', color, 'LineWidth', 1.8);
    patch('Parent', ax, ...
          'XData', [tip(1), base(1) + head_width * normal(1), base(1) - head_width * normal(1)], ...
          'YData', [tip(2), base(2) + head_width * normal(2), base(2) - head_width * normal(2)], ...
          'FaceColor', color, 'EdgeColor', color);
end
