import numpy as np
import matplotlib.pyplot as plt
from scipy.io import wavfile
from scipy.signal import resample_poly
from scipy.signal import butter, zpk2sos, sosfilt
from estimate_f0_hysteresis import estimate_f0_hysteresis


def process_buffer(sig, fs):

    #HFIL: highpass at 90 Hz
    z, p, k = butter(4, 90/(fs/2), 'high', output='zpk')
    SOS_hfil = zpk2sos(z, p, k)
    hfil_sig = sosfilt(SOS_hfil, sig)

    #FIL1: bandpass 10-90 Hz
    z, p, k = butter(4, [10/(fs/2), 90/(fs/2)], 'bandpass', output='zpk')
    SOS_fil1 = zpk2sos(z, p, k)
    fil1_sig = sosfilt(SOS_fil1, sig)

    #Narrow pre-filter for f0 estimation: bandpass 10-30 Hz
    z, p, k = butter(4, [10/(fs/2), 30/(fs/2)], 'bandpass', output='zpk')
    SOS_narrow = zpk2sos(z, p, k)
    fil1_narrow = sosfilt(SOS_narrow, fil1_sig)


    #This is to estimate f0 per 2-second window while holding last valid value during silence
    window_len = 2 * fs
    num_windows = len(fil1_narrow) // window_len
    f0_windows = np.zeros(num_windows)
    t_windows = np.zeros(num_windows)
    last_valid_f0 = 20.0

    for w in range(num_windows):
        win_start = w * window_len
        win_end = win_start + window_len
        window = fil1_narrow[win_start:win_end]
        rms = np.sqrt(np.mean(window**2))
        if rms > 0.08:
            f0_windows[w] = estimate_f0_hysteresis(window, fs, 0.3, -0.3)
            last_valid_f0 = f0_windows[w]
        else:
            f0_windows[w] = last_valid_f0
        t_windows[w] = ((win_start + win_end) / 2) / fs


    #This is to compute c per window and interpolate to sample resolution
    c_windows = (np.pi * f0_windows) / fs
    t_samples = np.arange(len(fil1_narrow)) / fs
    c_vec = np.interp(t_samples, t_windows, c_windows)

    #NLD
    resets = np.where((fil1_sig[:-1] < 0) & (fil1_sig[1:] >= 0))[0]

    nld_sig = np.zeros(len(fil1_sig))
    weighted = c_vec * np.abs(fil1_sig)

    
    resets = np.append(resets, len(fil1_sig)) #To add a dummy value at the end
                                              #to show no more real values after
                                              #the last real one

    prev = 0
    for i, r in enumerate(resets):
        segment = weighted[prev:r]
        nld_sig[prev:r] = np.cumsum(segment)
        if r < len(fil1_sig):
            nld_sig[r] = 0
        prev = r


    #FIL2: bandpass 90-180 Hz
    z, p, k = butter(4, [90/(fs/2), 180/(fs/2)], 'bandpass', output='zpk')
    SOS_fil2 = zpk2sos(z, p, k)
    fil2_sig = sosfilt(SOS_fil2, nld_sig)

    #Gain + sum
    G = 1
    final_sig = G * fil2_sig + hfil_sig

    max_val = np.max(np.abs(final_sig))
    if max_val > 0.99:
        final_sig = final_sig / max_val * 0.99

    return final_sig

if __name__ == "__main__":
    fs_in, sig = wavfile.read(r"C:\Users\Arda\Desktop\SCHOOL\BEP\Limberger_ETAL_2026_RUMBLES\infrasound\2024-08-02T19-14-49.211823_infrasound.wav")
    sig = sig.astype(np.float64) / 32768.0
    fs = 44100
    sig = resample_poly(sig, fs, fs_in)
    final_sig = process_buffer(sig, fs)
    
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))

    #Raw signal spectrogram
    ax1.specgram(sig, NFFT=8192, Fs=fs, noverlap=7168, cmap='jet', vmin=-80, vmax=-30)
    ax1.set_ylim(0, 200)
    ax1.set_title('Raw signal')
    ax1.set_ylabel('Frequency (Hz)')
    ax1.set_xlabel('Time (s)')

    #Processed signal spectrogram
    ax2.specgram(final_sig, NFFT=8192, Fs=fs, noverlap=7168, cmap='jet', vmin=-80, vmax=-30)
    ax2.set_ylim(0, 200)
    ax2.set_title('Processed signal')
    ax2.set_ylabel('Frequency (Hz)')
    ax2.set_xlabel('Time (s)')

    plt.tight_layout()
    plt.show()
