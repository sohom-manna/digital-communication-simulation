function result = qpsk_simulation(cfg)
%QPSK_SIMULATION  Monte Carlo BER simulation of Gray-coded coherent QPSK over AWGN.
%
%   result = QPSK_SIMULATION(cfg)
%
%   Signal chain, processed one vectorised block at a time:
%       random bits -> serial-to-parallel -> I/Q (Gray) mapping -> + AWGN
%       -> coherent I/Q detection -> parallel-to-serial -> BER
%
%   cfg and result have the same fields as in BPSK_SIMULATION; the result
%   additionally holds a measured symbol error rate (ser).
%
%   Gray-coded constellation (bit pair b0 b1 -> I, Q):
%
%        b0 selects the sign of I          b1 selects the sign of Q
%        bit 0 -> negative                 bit 0 -> negative
%        bit 1 -> positive                 bit 1 -> positive
%
%        01 (-,+)  135 deg  |  11 (+,+)   45 deg
%        -------------------+-------------------
%        00 (-,-)  225 deg  |  10 (+,-)  315 deg
%
%   Going around the circle (11 -> 01 -> 00 -> 10 -> 11) neighbouring points
%   differ in exactly one bit, so the most likely symbol error (to a
%   neighbour) corrupts only one bit.
%
%   Modelling assumptions: baseband-equivalent model at one sample per symbol
%   with perfect carrier phase and timing (coherent detection), same as in
%   BPSK_SIMULATION, so both schemes are compared under identical conditions.

    % ---- Signal normalisation ------------------------------------------------
    bits_per_symbol = 2;                 % QPSK: two bits per symbol
    symbol_energy   = 1;                 % Es = |s|^2 = 1 (each axis has amplitude 1/sqrt(2))
    bit_energy      = symbol_energy / bits_per_symbol;   % Eb = Es / k = 0.5

    assert(mod(cfg.bits_per_block, 2) == 0, ...
        'cfg.bits_per_block must be even: QPSK uses two bits per symbol.');

    num_points    = numel(cfg.ebn0_db);
    num_bits      = zeros(1, num_points);
    num_errors    = zeros(1, num_points);
    num_symbols   = zeros(1, num_points);
    symbol_errors = zeros(1, num_points);
    noise_sigma   = zeros(1, num_points);

    sample.tx_bits    = zeros(num_points, bits_per_symbol * cfg.sample_symbols);
    sample.tx_symbols = zeros(num_points, cfg.sample_symbols);
    sample.rx_symbols = zeros(num_points, cfg.sample_symbols);

    rng(cfg.seed);                       % fixed seed -> reproducible results

    for point = 1:num_points

        % ---- Eb/N0 (dB) -> noise standard deviation --------------------------
        % N0 = Eb / (Eb/N0). The complex noise has total variance N0, split
        % equally between I and Q, so each real component has variance N0/2.
        ebn0_linear = 10 ^ (cfg.ebn0_db(point) / 10);
        noise_psd   = bit_energy / ebn0_linear;
        sigma       = sqrt(noise_psd / 2);           % std dev per real dimension
        noise_sigma(point) = sigma;

        total_bits    = 0;
        total_errors  = 0;
        total_symbol_errors = 0;

        while total_errors < cfg.min_errors && total_bits < cfg.max_bits

            % 1) random information bits (serial stream)
            tx_bits = randi([0 1], 1, cfg.bits_per_block);

            % 2) serial-to-parallel: consecutive bits form a pair (b0, b1)
            %    row 1 = b0 (I bits), row 2 = b1 (Q bits)
            bit_pairs = reshape(tx_bits, 2, []);

            % 3) Gray I/Q mapping: bit 0 -> -1, bit 1 -> +1 on each axis,
            %    scaled by 1/sqrt(2) so that |s|^2 = Es = 1
            i_component = 2 * bit_pairs(1, :) - 1;
            q_component = 2 * bit_pairs(2, :) - 1;
            tx_symbols  = (i_component + 1i * q_component) / sqrt(2);

            % 4) AWGN channel: independent Gaussian noise on I and Q
            num_block_symbols = size(bit_pairs, 2);
            noise = sigma * (randn(1, num_block_symbols) + 1i * randn(1, num_block_symbols));
            rx_symbols = tx_symbols + noise;

            % 5) coherent detection: the sign of each axis decides its bit
            rx_pairs = [real(rx_symbols) > 0; imag(rx_symbols) > 0];

            % 6) parallel-to-serial: interleave (b0, b1) back into one stream
            rx_bits = reshape(rx_pairs, 1, []);

            % 7) count bit errors and symbol errors
            total_errors        = total_errors + sum(rx_bits ~= tx_bits);
            total_symbol_errors = total_symbol_errors + sum(any(rx_pairs ~= bit_pairs, 1));

            if total_bits == 0       % keep the first symbols for plots / checks
                keep = 1:cfg.sample_symbols;
                sample.tx_bits(point, :)    = tx_bits(1:bits_per_symbol * cfg.sample_symbols);
                sample.tx_symbols(point, :) = tx_symbols(keep);
                sample.rx_symbols(point, :) = rx_symbols(keep);
            end
            total_bits = total_bits + cfg.bits_per_block;
        end

        num_bits(point)      = total_bits;
        num_errors(point)    = total_errors;
        num_symbols(point)   = total_bits / bits_per_symbol;
        symbol_errors(point) = total_symbol_errors;
    end

    ber = num_errors ./ num_bits;

    result.ebn0_db       = cfg.ebn0_db;
    result.noise_sigma   = noise_sigma;
    result.num_bits      = num_bits;
    result.num_errors    = num_errors;
    result.ber           = ber;
    result.ber_ci95      = 1.96 * sqrt(ber .* (1 - ber) ./ num_bits);  % normal approx.
    result.num_symbols   = num_symbols;
    result.symbol_errors = symbol_errors;
    result.ser           = symbol_errors ./ num_symbols;
    result.sample        = sample;
end
