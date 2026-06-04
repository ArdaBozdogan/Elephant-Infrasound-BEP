function f0 = estimate_f0_hysteresis(fil1_sig, fs, vH_frac, vL_frac)
% ESTIMATE_F0_HYSTERESIS:  Estimates fundamental frequency using a
% software hysteresis comparator on the FIL1-filtered signal.
%
% f0 = estimate_f0_hysteresis(fil1_sig, fs, vH_frac, vL_frac)
%
% INPUTS:
%    fil1_sig  - bandpass filtered signal from FIL1 (column vector)
%    fs        - sampling frequency (Hz)
%    vH_frac   - upper threshold as fraction of signal peak (e.g. 0.3)
%    vL_frac   - lower threshold as fraction of signal peak (e.g. -0.3)
%
% OUTPUT:
%    f0        - estimated fundamental frequency (Hz)
%
%   The thresholds are scaled relative to the peak amplitude of the
%   input signal. This makes the estimator robust to recordings with
%   different amplitude levels.

    %Scale thresholds relative to peak amplitude
    peak = max(abs(fil1_sig));
    VH   =  vH_frac * peak;   % upper threshold (positive side)
    VL   =  vL_frac * peak;   % lower threshold (negative side)

    %Hysteresis comparator (software implementation)
    comp_out = zeros(size(fil1_sig));  % comparator output: 0 or 1
    state    = 0;                      % initial state: LOW

    for n = 1:length(fil1_sig)
        if state == 0
            %Currently LOW: transition HIGH only if signal exceeds VH
            if fil1_sig(n) >= VH
                state = 1;
            end
        else
            %Currently HIGH: transition LOW only if signal drops below VL
            if fil1_sig(n) <= VL
                state = 0;
            end
        end
        comp_out(n) = state;
    end

    %To detect rising edges (LOW -> HIGH transitions)
    rising_edges = find(diff(comp_out) == 1);
    rising_edges = rising_edges(2:end);

    %This statement is because we need at least 2 rising edges to estimate a period
    if length(rising_edges) < 2
        warning('Not enough rising edges detected. Check thresholds or signal quality.');
        f0 = NaN;
        return;
    end

    %This is to estimate period from average inter-edge spacing
    %and averaging over all detected periods improves robustness
    periods_samples = diff(rising_edges);        %in samples
    mean_period_s   = mean(periods_samples) / fs; %to convert to seconds
    f0              = 1 / mean_period_s;

    fprintf('Detected %d rising edges\n', length(rising_edges));
    fprintf('Estimated f0 = %.2f Hz\n', f0);
end