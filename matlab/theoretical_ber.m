function [ber_bpsk, ber_qpsk, ser_qpsk] = theoretical_ber(ebn0_db)
%THEORETICAL_BER  Theoretical error rates of coherent BPSK and Gray-coded QPSK in AWGN.
%
%   [ber_bpsk, ber_qpsk, ser_qpsk] = THEORETICAL_BER(ebn0_db)
%
%   Input
%       ebn0_db    Eb/N0 in dB (scalar or vector)
%
%   Output (same size as ebn0_db)
%       ber_bpsk   bit error rate of coherent BPSK
%       ber_qpsk   bit error rate of Gray-coded coherent QPSK
%       ser_qpsk   symbol error rate of coherent QPSK
%
%   Only base MATLAB is needed: the Gaussian Q-function is written with erfc
%   (the built-in qfunc belongs to a toolbox and is deliberately not used).
%
%   Formulas
%       Q(x)     = 0.5 * erfc(x / sqrt(2))
%       BPSK     Pb = Q( sqrt(2 Eb/N0) )
%       QPSK     Pb = Q( sqrt(2 Eb/N0) )              (same as BPSK, see below)
%                Ps = 1 - (1 - Pb)^2 = 2 Pb - Pb^2
%
%   Why QPSK has the same BER as BPSK at equal Eb/N0:
%   QPSK sends two independent BPSK streams on the orthogonal I and Q axes.
%   Each axis carries one bit with energy Eb, and the noise on each axis has
%   variance N0/2, so every bit sees exactly the BPSK decision problem.

    ebn0_linear = 10 .^ (ebn0_db / 10);           % dB -> linear ratio

    q_function = @(x) 0.5 * erfc(x / sqrt(2));    % Gaussian tail probability

    ber_bpsk = q_function(sqrt(2 * ebn0_linear));
    ber_qpsk = q_function(sqrt(2 * ebn0_linear));

    % A QPSK symbol is correct only if both its I bit and its Q bit are correct.
    ser_qpsk = 1 - (1 - ber_qpsk) .^ 2;
end
