# Methodology

This document explains the model, the equations and the statistics behind the simulation in `matlab/`. Every equation here corresponds to a line of code, so each step can be traced from theory to implementation.

## 1. What is simulated

The simulation is a **baseband-equivalent, symbol-rate model**: one complex (QPSK) or real (BPSK) number per transmitted symbol.

For a coherent receiver with perfect carrier phase and symbol timing, the matched-filter (correlator) output sampled at the symbol instant is

$$r = s + n,$$

where $s$ is the transmitted symbol and $n$ is Gaussian noise. Detecting on $r$ is equivalent to detecting on the full passband waveform, so a waveform-level simulation would give the same error statistics. The model deliberately does **not** include:

- carrier generation, pulse shaping or oversampling (the matched-filter output is simulated directly),
- carrier-phase, frequency or timing recovery (synchronisation is assumed perfect, which is what "coherent" means here),
- fading, interference or channel coding.

## 2. Eb/N0, Es/N0 and SNR

| Symbol | Meaning |
|---|---|
| $E_b$ | energy per information **bit** |
| $E_s$ | energy per **symbol**, $E_s = k\,E_b$ |
| $k$ | bits per symbol: $k=1$ for BPSK, $k=2$ for QPSK |
| $N_0$ | one-sided noise power spectral density (noise power per Hz) |

$$\frac{E_s}{N_0} = k\,\frac{E_b}{N_0}\qquad\Longleftrightarrow\qquad \left(\frac{E_s}{N_0}\right)_{\rm dB} = \left(\frac{E_b}{N_0}\right)_{\rm dB} + 10\log_{10}k .$$

**This project uses $E_b/N_0$ as its independent variable.** Reasons:

1. It normalises for the number of bits per symbol, so schemes with different $k$ are compared at equal *energy per information bit*. This is the fair basis for comparing BPSK with QPSK.
2. It is independent of bandwidth and sampling rate, which a symbol-rate simulation does not model anyway.
3. Theoretical BER formulas are standardly written in $E_b/N_0$.

**$E_s/N_0$** appears only once, in the right panel of `results/ber_comparison.png`. There the *same* simulated points are re-plotted with $E_s/N_0 = E_b/N_0 + 10\log_{10}k$ to show how the choice of axis changes the picture. No additional simulation is involved.

**SNR** (signal power / noise power) is *not* used. Its value depends on the bandwidth over which noise power is measured and on whether the signal is treated as real or complex, which is a common source of factor-of-2 mistakes. $E_b/N_0$ avoids that ambiguity.

## 3. AWGN channel and the $E_b/N_0 \to \sigma$ conversion

The channel adds noise that is

- **additive** ($r = s + n$),
- **white** (independent from symbol to symbol),
- **Gaussian**, zero mean.

Each *real* noise component has variance

$$\sigma^2 = \frac{N_0}{2}.$$

For QPSK the noise is complex, $n = n_I + j\,n_Q$, with $n_I, n_Q$ independent and each $\mathcal N(0,\sigma^2)$, so the total noise power is $\mathbb E|n|^2 = 2\sigma^2 = N_0$.

**Normalisation.** The signal is normalised to unit symbol energy, $E_s = 1$ (BPSK amplitudes $\pm 1$, QPSK $|s|=1$). Then $E_b = E_s/k$ and, for a requested $E_b/N_0$ (linear):

$$N_0 = \frac{E_b}{E_b/N_0},\qquad \sigma = \sqrt{\frac{N_0}{2}} .$$

| Scheme | $E_s$ | $E_b$ | $\sigma^2$ |
|---|---|---|---|
| BPSK | 1 | 1 | $\dfrac{1}{2\,(E_b/N_0)}$ |
| QPSK | 1 | 1/2 | $\dfrac{1}{4\,(E_b/N_0)}$ |

In code (`bpsk_simulation.m`, `qpsk_simulation.m`): `noise_psd = bit_energy / ebn0_linear; sigma = sqrt(noise_psd / 2);`, followed by `sigma * randn(...)`.

`validate_simulation.m` checks this conversion independently: it measures the standard deviation of `received - transmitted` and compares it with the formulas in the table above.

## 4. BPSK

**Mapping:** bit 0 $\to -1$, bit 1 $\to +1$ (so $E_s = E_b = 1$).

**Detection:** decide bit 1 if $r>0$, otherwise bit 0. This is the maximum-likelihood rule for equiprobable bits and symmetric noise.

**Theoretical BER.** Given a transmitted $+\sqrt{E_b}$, an error occurs when the noise pushes $r$ below zero:

$$P_b = \Pr\!\left(n < -\sqrt{E_b}\right) = Q\!\left(\frac{\sqrt{E_b}}{\sqrt{N_0/2}}\right) = Q\!\left(\sqrt{\frac{2E_b}{N_0}}\right) = \tfrac12\,\mathrm{erfc}\!\left(\sqrt{\frac{E_b}{N_0}}\right),$$

with $Q(x)=\tfrac12\,\mathrm{erfc}(x/\sqrt2)$. The code uses the `erfc` form (base MATLAB), not the toolbox function `qfunc`.

## 5. QPSK

**Serial-to-parallel.** The bit stream is split into consecutive pairs $(b_0,b_1)$: `reshape(bits, 2, [])`. Row 1 holds the $b_0$ bits, row 2 the $b_1$ bits.

**Gray-coded I/Q mapping.** $b_0$ sets the sign of the in-phase component and $b_1$ the sign of the quadrature component (bit 0 $\to -$, bit 1 $\to +$):

$$s = \frac{(2b_0-1) + j\,(2b_1-1)}{\sqrt2}$$

| bits $b_0 b_1$ | I | Q | phase |
|:---:|:---:|:---:|:---:|
| 11 | $+1/\sqrt2$ | $+1/\sqrt2$ | 45° |
| 01 | $-1/\sqrt2$ | $+1/\sqrt2$ | 135° |
| 00 | $-1/\sqrt2$ | $-1/\sqrt2$ | 225° |
| 10 | $+1/\sqrt2$ | $-1/\sqrt2$ | 315° |

All four points have $|s|^2 = 1 = E_s$. Going around the circle (11 → 01 → 00 → 10 → 11), neighbouring points differ in exactly one bit: that is the **Gray property**. The most likely symbol error (the noise carries the received point into a *neighbouring* decision region) therefore flips only one bit.

**Coherent detection.** The I and Q decisions are independent: $\hat b_0 = [\mathrm{Re}(r)>0]$, $\hat b_1 = [\mathrm{Im}(r)>0]$. The decided pairs are interleaved back into one serial stream (parallel-to-serial) and compared with the transmitted bits.

**Theoretical BER and SER.** Each axis carries one bit with amplitude $\sqrt{E_s/2}=\sqrt{E_b}$ and noise variance $N_0/2$. This is the BPSK decision problem, so each bit is in error with the same probability

$$p = Q\!\left(\sqrt{\frac{2E_b}{N_0}}\right),$$

and the two bits of a symbol are in error independently. Hence the **bit error rate equals the BPSK one**,

$$P_b^{\rm QPSK} = p = P_b^{\rm BPSK}\quad\text{at equal } E_b/N_0 ,$$

while the symbol is correct only if both bits are correct:

$$P_s^{\rm QPSK} = 1-(1-p)^2 = 2p - p^2 .$$

At high SNR $P_s \approx 2p$, i.e. $\mathrm{SER}/\mathrm{BER}\to 2$: almost every symbol error corrupts exactly one of its two bits. The simulation reports this ratio as an information line.

**Equal BER vs. equal $E_s/N_0$.** QPSK puts two bits into each symbol, so at equal *energy per bit* each of its bits sees the same noise-to-signal ratio as a BPSK bit. At equal *energy per symbol* the QPSK bits only get $E_s/2$ each, and the BER curve moves right by $10\log_{10}2 \approx 3.01$ dB. The 3.01 dB marker in `ber_comparison.png` comes from this relationship in the theory curves. It is not a measured performance gain. The practical benefit of QPSK (two bits per symbol, hence half the symbol rate and bandwidth for the same bit rate) is a standard result, but it is **not simulated** here because the model has no pulse shaping or bandwidth.

## 6. Monte Carlo estimation

Each BER estimate is $\hat p = e/n$ ($e$ errors in $n$ bits). If the bit errors are independent with probability $p$:

- standard error: $\sqrt{p(1-p)/n}$,
- 95 % confidence interval (normal approximation): $\hat p \pm 1.96\sqrt{\hat p(1-\hat p)/n}$,
- relative standard error $\approx 1/\sqrt{e}$ when $p \ll 1$.

**Block processing and stopping rule.** Bits are generated in vectorised blocks of `cfg.bits_per_block` (= `N_BITS`, default $10^6$). For each $E_b/N_0$ point, blocks are added until

- at least `cfg.min_errors` (default 100) bit errors have been counted, **or**
- `cfg.max_bits` (default $10^8$) bits have been simulated.

A fixed $10^6$ bits would give only about 4 errors at 10 dB (BER $\approx 3.9\cdot10^{-6}$), too few for a useful estimate. With the stopping rule every point has at least about 100 errors, i.e. roughly 10 % relative standard error (about ±20 % at 95 % confidence), and low-BER points automatically receive more bits. The stopping condition is evaluated only at block boundaries. Because the number of simulated bits then depends on the random errors, the estimator is in principle very slightly biased; with this block-wise rule that effect is small compared with the statistical uncertainty. The actual number of bits and errors of every point is stored in `results/ber_results.csv`.

**Reproducibility.** `rng(cfg.seed)` (Mersenne Twister) is called at the start of each simulation function. For a fixed seed, the results are exactly reproducible within the same MATLAB/Octave version. Different environments seed and transform the random numbers differently, so they give slightly different (but statistically equivalent) numbers.

**Independent random streams.** `main.m` passes `cfg.seed` to the BPSK simulation and `cfg.seed + 1` to the QPSK simulation. With one shared seed both functions would draw the same bits and the same Gaussian values, so the two BER estimates would be correlated and the comparison between them would be partly an artefact. Separate seeds make the two Monte Carlo experiments statistically independent, which is also the assumption behind the $z$-test of the BPSK-minus-QPSK difference in §7.

## 7. Validation (`validate_simulation.m`)

| Check | How |
|---|---|
| Valid numbers | all BER/SER finite, $>0$ and $\le 0.5$ |
| BER decreases with $E_b/N_0$ | strictly decreasing for BPSK BER, QPSK BER, QPSK SER |
| Agreement with theory | $z = (\hat p - p_{\rm th})/\sqrt{p_{\rm th}(1-p_{\rm th})/n}$ must satisfy $\lvert z\rvert<4$ at every point (BPSK BER, QPSK BER, QPSK SER) |
| BPSK = QPSK at equal $E_b/N_0$ | $z$-score of the *difference* of the two simulated BERs, $\lvert z\rvert<4$ (assumes independent streams, see next row) |
| BPSK mapping | transmitted symbols equal $2\cdot\text{bit}-1$ |
| QPSK constellation | each bit pair maps to the expected point $(\pm1\pm j)/\sqrt2$ (table written independently in the validator); $E_s=1$ |
| Gray property | nearest-neighbour points differ in exactly one bit |
| AWGN level | measured noise standard deviation within 10 % of $\sqrt{N_0/2}$ from §3, and growing as $E_b/N_0$ falls |
| Independent streams | sample correlation coefficient $\rho$ between the BPSK noise, the QPSK I noise and the QPSK Q noise: $\lvert\rho\rvert<4/\sqrt{n}$ (independent sequences of length $n$ have $\rho\approx\mathcal N(0,1/n)$; a shared seed would give $\rho=1$) |
| Reproducibility | same seed gives identical output, a different seed gives different noise |

A correct simulation has $z\sim\mathcal N(0,1)$ at each point, so $\lvert z\rvert\ge4$ would occur by chance only about 6 times in 100 000 per point; the limit therefore flags real errors without false alarms. This is a statistical comparison. It does not "force" the curves to match theory.

## 8. Limitations

- Symbol-rate baseband-equivalent model with perfect synchronisation (see §1).
- AWGN only: no fading, interference, phase noise or non-linearities.
- Uncoded transmission with equiprobable independent bits.
- BER range limited to about $10^{-6}$ by the Monte Carlo cost (about $3\cdot10^{7}$ bits per point at 10 dB).
