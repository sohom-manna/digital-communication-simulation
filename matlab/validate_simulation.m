function all_passed = validate_simulation(bpsk, qpsk, cfg)
%VALIDATE_SIMULATION  Automated sanity checks of the BPSK / QPSK simulation results.
%
%   all_passed = VALIDATE_SIMULATION(bpsk, qpsk, cfg)
%
%   Prints one PASS / FAIL line per check and returns true if all passed.
%
%   Statistical comparison with theory: a simulated BER p_hat obtained from
%   n bits has standard error sqrt(p*(1-p)/n) when the true BER is p. The
%   z-score z = (p_hat - p_theory) / standard_error therefore behaves like a
%   standard normal variable if the simulation is correct. A point is accepted
%   if |z| < z_limit. z_limit = 4 is chosen so that a correct simulation
%   practically never fails by chance (about 6 in 100000 per point).
%
%   The z-test of the BPSK-minus-QPSK difference assumes that the two Monte
%   Carlo experiments are statistically independent (separate random streams).
%   Check 6b verifies this on the simulated noise samples themselves.

    z_limit    = 4;      % acceptance limit for |z|
    noise_tol  = 0.10;   % allowed relative error of the measured noise std
    all_passed = true;

    fprintf('\nValidation checks\n-----------------\n');

    ebn0_db  = cfg.ebn0_db;
    ebn0_lin = 10 .^ (ebn0_db / 10);
    [theory_bpsk, theory_qpsk, theory_ser] = theoretical_ber(ebn0_db);

    % ---- 1. valid numbers --------------------------------------------------
    all_ber = [bpsk.ber qpsk.ber];
    ok = all(isfinite([all_ber qpsk.ser])) && all(all_ber > 0) && all(all_ber <= 0.5);
    all_passed = print_check(ok, ...
        'BER / SER values are finite, > 0 (at least one error per point) and <= 0.5') && all_passed;

    % ---- 2. BER falls as Eb/N0 rises ------------------------------------------
    ok = all(diff(bpsk.ber) < 0) && all(diff(qpsk.ber) < 0) && all(diff(qpsk.ser) < 0);
    all_passed = print_check(ok, ...
        'BPSK BER, QPSK BER and QPSK SER decrease monotonically with Eb/N0') && all_passed;

    % ---- 3. agreement with theory (z-scores) ------------------------------------
    z_bpsk = (bpsk.ber - theory_bpsk) ./ sqrt(theory_bpsk .* (1 - theory_bpsk) ./ bpsk.num_bits);
    z_qpsk = (qpsk.ber - theory_qpsk) ./ sqrt(theory_qpsk .* (1 - theory_qpsk) ./ qpsk.num_bits);
    z_ser  = (qpsk.ser - theory_ser)  ./ sqrt(theory_ser  .* (1 - theory_ser)  ./ qpsk.num_symbols);
    all_passed = print_check(max(abs(z_bpsk)) < z_limit, ...
        sprintf('BPSK BER vs theory:  max |z| = %.2f over %d points (limit %g)', ...
                max(abs(z_bpsk)), numel(z_bpsk), z_limit)) && all_passed;
    all_passed = print_check(max(abs(z_qpsk)) < z_limit, ...
        sprintf('QPSK BER vs theory:  max |z| = %.2f over %d points (limit %g)', ...
                max(abs(z_qpsk)), numel(z_qpsk), z_limit)) && all_passed;
    all_passed = print_check(max(abs(z_ser)) < z_limit, ...
        sprintf('QPSK SER vs theory:  max |z| = %.2f over %d points (limit %g)', ...
                max(abs(z_ser)), numel(z_ser), z_limit)) && all_passed;

    % ---- 4. BPSK and Gray QPSK agree at equal Eb/N0 -----------------------------
    z_diff = (bpsk.ber - qpsk.ber) ./ ...
             sqrt(theory_bpsk .* (1 - theory_bpsk) .* (1 ./ bpsk.num_bits + 1 ./ qpsk.num_bits));
    all_passed = print_check(max(abs(z_diff)) < z_limit, ...
        sprintf('BPSK BER = QPSK BER at equal Eb/N0: max |z| of the difference = %.2f', ...
                max(abs(z_diff)))) && all_passed;

    % ---- 5. mappings and constellation -----------------------------------------------
    ok = isequal(bpsk.sample.tx_symbols, 2 * bpsk.sample.tx_bits - 1);
    all_passed = print_check(ok, 'BPSK mapping: bit 0 -> -1, bit 1 -> +1') && all_passed;

    % Expected constellation, written down independently of qpsk_simulation.m
    expected_bits   = [0 0; 0 1; 1 1; 1 0];                       % b0 b1
    expected_points = [-1-1i; -1+1i; 1+1i; 1-1i] / sqrt(2);
    sent_pairs   = reshape(qpsk.sample.tx_bits(1, :), 2, []).';   % one row per symbol
    sent_symbols = qpsk.sample.tx_symbols(1, :).';
    mapping_ok = true;
    for k = 1:4
        this_pair = sent_pairs(:, 1) == expected_bits(k, 1) & sent_pairs(:, 2) == expected_bits(k, 2);
        mapping_ok = mapping_ok && any(this_pair) && ...
                     all(abs(sent_symbols(this_pair) - expected_points(k)) < 1e-12);
    end
    all_passed = print_check(mapping_ok, ...
        'QPSK constellation: each bit pair maps to (+-1 +- j)/sqrt(2) as specified') && all_passed;

    all_passed = print_check(abs(mean(abs(sent_symbols) .^ 2) - 1) < 1e-12, ...
        'QPSK average symbol energy Es = 1') && all_passed;

    gray_ok = true;
    for a = 1:3
        for b = (a + 1):4
            if abs(expected_points(a) - expected_points(b)) < 1.5   % nearest neighbours
                gray_ok = gray_ok && (sum(expected_bits(a, :) ~= expected_bits(b, :)) == 1);
            end
        end
    end
    all_passed = print_check(gray_ok, ...
        'Gray property: nearest-neighbour constellation points differ in exactly one bit') && all_passed;

    % ---- 6. measured noise level matches the Eb/N0 -> sigma conversion ---------------
    expected_sigma_bpsk = sqrt(1 ./ (2 * ebn0_lin));      % Eb = 1,   N0/2 = Eb/(2 Eb/N0)
    expected_sigma_qpsk = sqrt(0.5 ./ (2 * ebn0_lin));    % Eb = 0.5, N0/2 = Eb/(2 Eb/N0)
    measured_bpsk = zeros(size(ebn0_db));
    measured_qpsk = zeros(size(ebn0_db));
    unit_noise_bpsk   = [];     % noise divided by its expected std (unit variance if correct)
    unit_noise_qpsk_i = [];
    unit_noise_qpsk_q = [];
    for p = 1:numel(ebn0_db)
        noise_b = bpsk.sample.rx_symbols(p, :) - bpsk.sample.tx_symbols(p, :);
        noise_q = qpsk.sample.rx_symbols(p, :) - qpsk.sample.tx_symbols(p, :);
        measured_bpsk(p) = std(noise_b);
        measured_qpsk(p) = std([real(noise_q) imag(noise_q)]);
        unit_noise_bpsk   = [unit_noise_bpsk,   noise_b       / expected_sigma_bpsk(p)];
        unit_noise_qpsk_i = [unit_noise_qpsk_i, real(noise_q) / expected_sigma_qpsk(p)];
        unit_noise_qpsk_q = [unit_noise_qpsk_q, imag(noise_q) / expected_sigma_qpsk(p)];
    end
    err_bpsk = max(abs(measured_bpsk ./ expected_sigma_bpsk - 1));
    err_qpsk = max(abs(measured_qpsk ./ expected_sigma_qpsk - 1));
    all_passed = print_check(err_bpsk < noise_tol && err_qpsk < noise_tol, ...
        sprintf('Measured noise std matches sqrt(N0/2): max deviation BPSK %.1f%%, QPSK %.1f%% (limit %.0f%%)', ...
                100 * err_bpsk, 100 * err_qpsk, 100 * noise_tol)) && all_passed;
    all_passed = print_check(all(diff(measured_bpsk) < 0) && all(diff(measured_qpsk) < 0), ...
        'Noise spread of the received symbols grows as Eb/N0 decreases') && all_passed;

    % ---- 6b. independent random streams -------------------------------------------------
    % The sample correlation coefficient of two independent sequences of length n has
    % standard deviation about 1/sqrt(n), so |rho| < z_limit / sqrt(n) for a correct,
    % independent pair. Sharing one seed between the two simulations would give rho = 1.
    rho_limit = z_limit / sqrt(numel(unit_noise_bpsk));
    rho_bi = sample_correlation(unit_noise_bpsk,   unit_noise_qpsk_i);
    rho_bq = sample_correlation(unit_noise_bpsk,   unit_noise_qpsk_q);
    rho_iq = sample_correlation(unit_noise_qpsk_i, unit_noise_qpsk_q);
    rho_max = max(abs([rho_bi rho_bq rho_iq]));
    all_passed = print_check(rho_max < rho_limit, ...
        sprintf('Noise streams independent (BPSK vs QPSK I/Q, QPSK I vs Q): max |rho| = %.4f (limit %.4f)', ...
                rho_max, rho_limit)) && all_passed;

    % ---- 7. reproducibility with a fixed seed -------------------------------------
    short_cfg = cfg;
    short_cfg.ebn0_db        = [0 4];
    short_cfg.bits_per_block = 1e5;
    short_cfg.max_bits       = 1e5;
    other_cfg = short_cfg;
    other_cfg.seed = cfg.seed + 1;

    run_a = bpsk_simulation(short_cfg);  run_b = bpsk_simulation(short_cfg);
    run_c = bpsk_simulation(other_cfg);
    bpsk_repro = isequal(run_a.num_errors, run_b.num_errors) && ...
                 isequal(run_a.sample.rx_symbols, run_b.sample.rx_symbols) && ...
                 ~isequal(run_a.sample.rx_symbols, run_c.sample.rx_symbols);

    run_a = qpsk_simulation(short_cfg);  run_b = qpsk_simulation(short_cfg);
    run_c = qpsk_simulation(other_cfg);
    qpsk_repro = isequal(run_a.num_errors, run_b.num_errors) && ...
                 isequal(run_a.sample.rx_symbols, run_b.sample.rx_symbols) && ...
                 ~isequal(run_a.sample.rx_symbols, run_c.sample.rx_symbols);
    all_passed = print_check(bpsk_repro && qpsk_repro, ...
        'Same seed -> identical results; different seed -> different noise') && all_passed;

    % ---- information only -----------------------------------------------------------
    last = numel(ebn0_db);
    fprintf('  [info] QPSK SER / BER at Eb/N0 = %g dB: %.2f (about 2 expected with Gray coding at high SNR)\n', ...
            ebn0_db(last), qpsk.ser(last) / qpsk.ber(last));

    if all_passed
        fprintf('All validation checks passed.\n');
    else
        fprintf('WARNING: at least one validation check FAILED - investigate before using the results.\n');
    end
end

% ---------------------------------------------------------------------------
function rho = sample_correlation(a, b)
% Pearson correlation coefficient of two equally long vectors.
    a = a(:) - mean(a(:));
    b = b(:) - mean(b(:));
    rho = sum(a .* b) / sqrt(sum(a .^ 2) * sum(b .^ 2));
end

% ---------------------------------------------------------------------------
function ok = print_check(ok, message)
% Print a PASS / FAIL line and pass the result through.
    if ok
        tag = 'PASS';
    else
        tag = 'FAIL';
    end
    fprintf('  [%s] %s\n', tag, message);
end
