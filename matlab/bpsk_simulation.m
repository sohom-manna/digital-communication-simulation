function result = bpsk_simulation(cfg)
%BPSK_SIMULATION  Monte Carlo BER simulation of coherent BPSK over an AWGN channel.
%
%   result = BPSK_SIMULATION(cfg)
%
%   Signal chain, processed one vectorised block at a time:
%       random bits -> BPSK mapping -> + AWGN -> coherent detection -> BER
%
%   Required fields of cfg
%       ebn0_db         Eb/N0 values to simulate, in dB (vector)
%       bits_per_block  bits per vectorised Monte Carlo block (N_BITS)
%       min_errors      stop an Eb/N0 point once this many bit errors are counted
%       max_bits        hard limit on the bits simulated per Eb/N0 point
%       seed            seed of the random number generator
%       sample_symbols  number of symbols stored for plots and validation
%
%   Fields of the returned struct (one entry per Eb/N0 point)
%       ebn0_db, noise_sigma, num_bits, num_errors, ber, ber_ci95,
%       num_symbols, symbol_errors, ser   (for BPSK: symbol = bit)
%       sample.tx_bits, sample.tx_symbols, sample.rx_symbols
%
%   Stopping rule: an Eb/N0 point keeps adding blocks of cfg.bits_per_block bits
%   until at least cfg.min_errors bit errors were counted (or cfg.max_bits was
%   reached). Low-BER points therefore get more bits, so every point has a
%   comparable relative accuracy of about 1/sqrt(min_errors).
%
%   Modelling assumptions: baseband-equivalent model at one sample per symbol,
%   i.e. the matched-filter / correlator output sampled at the symbol instant,
%   with perfect carrier phase and timing (coherent detection).

    % ---- Signal normalisation ------------------------------------------------
    bits_per_symbol = 1;                 % BPSK: one bit per symbol
    symbol_energy   = 1;                 % Es = 1 because the amplitudes are +1 / -1
    bit_energy      = symbol_energy / bits_per_symbol;   % Eb = Es / k = 1

    num_points = numel(cfg.ebn0_db);
    num_bits   = zeros(1, num_points);
    num_errors = zeros(1, num_points);
    noise_sigma = zeros(1, num_points);

    sample.tx_bits    = zeros(num_points, cfg.sample_symbols);
    sample.tx_symbols = zeros(num_points, cfg.sample_symbols);
    sample.rx_symbols = zeros(num_points, cfg.sample_symbols);

    rng(cfg.seed);                       % fixed seed -> reproducible results

    for point = 1:num_points

        % ---- Eb/N0 (dB) -> noise standard deviation --------------------------
        ebn0_linear = 10 ^ (cfg.ebn0_db(point) / 10);
        noise_psd   = bit_energy / ebn0_linear;      % N0 = Eb / (Eb/N0)
        sigma       = sqrt(noise_psd / 2);           % real noise: variance N0/2
        noise_sigma(point) = sigma;

        total_bits   = 0;
        total_errors = 0;

        while total_errors < cfg.min_errors && total_bits < cfg.max_bits

            % 1) random information bits
            tx_bits = randi([0 1], 1, cfg.bits_per_block);

            % 2) BPSK mapping: bit 0 -> -1, bit 1 -> +1
            tx_symbols = 2 * tx_bits - 1;

            % 3) AWGN channel: add zero-mean Gaussian noise, variance sigma^2
            noise      = sigma * randn(1, cfg.bits_per_block);
            rx_symbols = tx_symbols + noise;

            % 4) coherent detection: threshold at 0 (ML rule for equal priors)
            rx_bits = double(rx_symbols > 0);

            % 5) count bit errors
            total_errors = total_errors + sum(rx_bits ~= tx_bits);

            if total_bits == 0       % keep the first symbols for plots / checks
                keep = 1:cfg.sample_symbols;
                sample.tx_bits(point, :)    = tx_bits(keep);
                sample.tx_symbols(point, :) = tx_symbols(keep);
                sample.rx_symbols(point, :) = rx_symbols(keep);
            end
            total_bits = total_bits + cfg.bits_per_block;
        end

        num_bits(point)   = total_bits;
        num_errors(point) = total_errors;
    end

    ber = num_errors ./ num_bits;

    result.ebn0_db       = cfg.ebn0_db;
    result.noise_sigma   = noise_sigma;
    result.num_bits      = num_bits;
    result.num_errors    = num_errors;
    result.ber           = ber;
    result.ber_ci95      = 1.96 * sqrt(ber .* (1 - ber) ./ num_bits);  % normal approx.
    result.num_symbols   = num_bits;           % one bit per symbol
    result.symbol_errors = num_errors;
    result.ser           = ber;
    result.sample        = sample;
end
