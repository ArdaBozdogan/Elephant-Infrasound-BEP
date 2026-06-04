import numpy as np
def estimate_f0_hysteresis (fil1_sig, fs, vH_frac, vL_frac):
    """

    ESTIMATE_F0_HYSTERESIS: Estimates fundamental frequency using 
    a software hysteresis comparator on the FIL1-filtered signal.

    f0 = estimate_f0_hysteresis(fil1_sig, fs, vH_frac, vL_frac)

    INPUTS:
        fil1_sig  - bandpass filtered signal from FIL1
        fs        - sampling frequency (Hz)
        vH_frac   - upper threshold as fraction of signal peak 
        vL_frac   - lower threshold as fraction of signal peak 

    OUTPUT:
        f0        - estimated fundamental frequency (Hz)

    The thresholds are scaled relative to the peak amplitude of the
    input signal. This makes the estimator robust to recordings with
    different amplitude levels.

    """

    #This is to scale thresholds relative to peak amplitude
    peak = max(abs(fil1_sig))
    VH   =  vH_frac * peak   #upper threshold (positive side)
    VL   =  vL_frac * peak   #lower threshold (negative side)

    #Hysteresis comparator (software implementation)
    comp_out = np.zeros(len(fil1_sig))  #comparator output: 0 or 1
    state    = 0                        #initial state: LOW

    for n in range(len(fil1_sig)):
        if state == 0:
            #Currently low: transition high only if signal exceeds VH
            if fil1_sig[n] >= VH:
                state = 1
            
        else:
            #Currently high: transition low only if signal drops below VL
            if fil1_sig[n] <= VL:
                state = 0
            
        
        comp_out[n] = state;
    

    #This is to detect rising edges (Low to high transitions)
    rising_edges = np.where(np.diff(comp_out) == 1)[0]
    rising_edges = rising_edges[1:]

    
    if len(rising_edges) < 2: #We need at least 2 rising edges to estimate a period
        print('Not enough rising edges detected. Check thresholds or signal quality.')
        f0 = float('nan')
        return f0
    

    #This is to estimate period from average inter-edge spacing
    # and averaging over all detected periods improves robustness
    periods_samples = np.diff(rising_edges)        #in samples
    mean_period_s   = np.mean(periods_samples) / fs #to convert to seconds
    f0              = 1 / mean_period_s

    print(f"Detected {len(rising_edges)} rising edges")
    print(f"Estimated f0 = {f0:.2f} Hz")
    return f0
