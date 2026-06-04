% Switch between SYNTHETIC MODE and REAL RECORDING MODE by commenting/
% uncommenting the relevant input block below.

%% INPUT: SYNTHETIC MODE
% fs = 44100;
% t  = (0:1/fs:1)';
% f0 = 10;
% A  = 2;
% sig = A * sin(2*pi*f0*t);

% INPUT: REAL RECORDING MODE (time-varying c)
[sig, fs_in] = audioread("C:\Users\Arda\Desktop\SCHOOL\BEP\Limberger_ETAL_2026_RUMBLES\infrasound\2024-08-02T19-14-49.211823_infrasound.wav");
%This path can be replaced with the path in the user's laptop, this one is
%specific to the author's computer
fs = 44100;
sig = resample(sig, fs, fs_in);
disp(fs_in); disp(fs);
disp(size(sig));
t = (0:length(sig)-1)' / fs;
figure;
pwelch(sig, [], [], [], fs);
set(gca, 'FontSize', 12);

%% HFIL: High-pass filter (direct path)
fc_hi = 90;
[z,p,k] = butter(4, fc_hi/(fs/2), 'high');
SOS = zp2sos(z,p,k);
hfil_sig = sosfilt(SOS, sig);

figure;
plot(t, sig, 'k', t, hfil_sig, 'g', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Amplitude');
legend('Original Signal', 'Filtered Signal (HFIL)'); grid on;
set(gca, 'FontSize', 12);

%% FIL1: Bandpass filter (processing path)
fil1_lp = fc_hi;
fil1_hp = 10;
[z,p,k] = butter(4, [fil1_hp fil1_lp]/(fs/2), 'bandpass');
SOS = zp2sos(z,p,k);
fil1_sig = sosfilt(SOS, sig);

figure;
plot(t, sig, 'k', t, fil1_sig, 'g', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Amplitude');
legend('Original Signal', 'Filtered Signal (FIL1)'); grid on;
set(gca, 'FontSize', 12);

%% NLD: Non-linear device (full-wave integrator)
nld_sig = zeros(size(fil1_sig));

% Narrow pre-filter for f0 estimation only (10-30 Hz)
[z,p,k] = butter(4, [10 30]/(fs/2), 'bandpass');
SOS_narrow = zp2sos(z,p,k);
fil1_narrow = sosfilt(SOS_narrow, fil1_sig);

% SYNTHETIC MODE: single static c
% (comment this block out when using real recording mode)
% f0_est = estimate_f0_hysteresis(fil1_narrow, fs, 0.3, -0.3);
% c = (pi * f0_est) / fs;
% 
% for n = 2:length(fil1_sig)
%     if fil1_sig(n-1) < 0 && fil1_sig(n) >= 0
%         nld_sig(n) = 0;
%     else
%         nld_sig(n) = nld_sig(n-1) + c * abs(fil1_sig(n));
%     end
% end

% REAL RECORDING MODE: time-varying c (uncomment when using real recording)
window_len  = 2 * fs;
num_windows = floor(length(fil1_narrow) / window_len);
f0_windows  = zeros(1, num_windows);
t_windows   = zeros(1, num_windows);
last_valid_f0 = 20;

for w = 1:num_windows
    win_start      = (w-1) * window_len + 1;
    win_end        = win_start + window_len - 1;
    window         = fil1_narrow(win_start:win_end);

    if rms(window) > 0.08
        f0_windows(w) = estimate_f0_hysteresis(window, fs, 0.3, -0.3);
        last_valid_f0 = f0_windows(w);
    else
        f0_windows(w) = last_valid_f0;
    end

    t_windows(w)   = ((win_start + win_end) / 2) / fs;
end

% f0 tracking plot
figure;
plot(t_windows, f0_windows, 'ro-', 'LineWidth', 2, 'MarkerFaceColor', 'r');
xlabel('Time (s)'); ylabel('Estimated f0 (Hz)');
title('Time-varying f0 estimate');
ylim([0 40]); grid on;
set(gca, 'FontSize', 12);

disp('f0 per window (Hz):'); disp(f0_windows);

c_windows = (pi * f0_windows) / fs;
t_samples  = (0:length(fil1_narrow)-1)' / fs;
c_vec      = interp1(t_windows, c_windows, t_samples, 'linear', 'extrap');

for n = 2:length(fil1_sig)
    if fil1_sig(n-1) < 0 && fil1_sig(n) >= 0
        nld_sig(n) = 0;
    else
        nld_sig(n) = nld_sig(n-1) + c_vec(n) * abs(fil1_sig(n));
    end
end

%% SYNTHETIC VERIFICATION PLOTS (should be ran in synthetic mode only)
% NLD output PSD
% figure;
% [Pxx, F] = pwelch(nld_sig, [], [], [], fs);
% plot(F, 10*log10(Pxx), 'LineWidth', 2);
% xlim([0 300]);
% xlabel('Frequency (Hz)'); ylabel('Power/Frequency (dB/Hz)');
% title('NLD output spectrum');
% grid on; set(gca, 'FontSize', 12);
% 
% % Harmonic amplitude decay
% N = length(nld_sig);
% NLD_FFT = abs(fft(nld_sig)) / N;
% NLD_FFT = NLD_FFT(1:ffloor(N/2)+1);
% NLD_FFT(2:end-1) = 2 * NLD_FFT(2:end-1);
% freq_axis = (0:floor(N/2)) * fs / N;
% 
% harmonics      = 1:20;
% harmonic_freqs = harmonics * f0_est;
% harmonic_amps  = interp1(freq_axis, NLD_FFT, harmonic_freqs);
% amp_1          = harmonic_amps(1);
% 
% figure;
% semilogy(harmonics, harmonic_amps,          'bo-', 'LineWidth', 2); hold on;
% semilogy(harmonics, amp_1 ./ harmonics,     'r--', 'LineWidth', 2);
% semilogy(harmonics, amp_1 ./ harmonics.^2,  'k--', 'LineWidth', 2);
% legend('Measured', '1/n', '1/n^2');
% xlabel('Harmonic number n'); ylabel('Amplitude');
% title('Harmonic amplitude decay'); grid on;
% set(gca, 'FontSize', 12);
% 
% % Synthetic NLD test at estimated f0
% t_test        = (0:length(fil1_sig)-1)' / fs;
% fil1_sig_test = 0.5 * sin(2*pi*f0_est*t_test);
% nld_test      = zeros(size(fil1_sig_test));
% 
% for n = 2:length(fil1_sig_test)
%     if fil1_sig_test(n-1) < 0 && fil1_sig_test(n) >= 0
%         nld_test(n) = 0;
%     else
%         nld_test(n) = nld_test(n-1) + c * abs(fil1_sig_test(n));
%     end
% end
% 
% [Pxx_test, F_test] = pwelch(nld_test, [], [], [], fs);
% figure;
% plot(F_test, 10*log10(Pxx_test), 'LineWidth', 2);
% xlim([0 300]);
% xlabel('Frequency (Hz)'); ylabel('Power/Frequency (dB/Hz)');
% title('NLD output - synthetic sine at estimated f0');
% grid on; set(gca, 'FontSize', 12);
% 
% % Time-domain integrator output
% figure;
% plot(t, fil1_sig, 'k', t, nld_sig, 'g', 'LineWidth', 2);
% xlabel('Time (s)'); ylabel('Amplitude');
% legend('FIL1 Output', 'Integrator Output'); grid on;
% set(gca, 'FontSize', 12);
% 
% figure;
% plot(t, fil1_sig, 'k', t, nld_sig, 'g', 'LineWidth', 2);
% xlim([0 0.5]);
% legend('FIL1 Output', 'Integrator Output'); grid on;
% set(gca, 'FontSize', 12);

%% FIL2: Second bandpass filter (for harmonic selection)
fil2_hp = fil1_lp;
fil2_lp = 2 * fil2_hp;
[z,p,k] = butter(4, [fil2_hp fil2_lp]/(fs/2), 'bandpass');
SOS = zp2sos(z,p,k);
fil2_sig = sosfilt(SOS, nld_sig);

figure;
plot(t, sig, 'k', t, fil2_sig, 'g', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Amplitude');
legend('Original Signal', 'Filtered Signal (FIL2)'); grid on;
set(gca, 'FontSize', 12);

figure;
[Pxx_fil2, F_fil2] = pwelch(fil2_sig, hann(8192), [], 16384, fs);
plot(F_fil2, 10*log10(Pxx_fil2), 'LineWidth', 2);
xlim([0 300]);
xlabel('Frequency (Hz)'); ylabel('Power/Frequency (dB/Hz)');
title('FIL2 output spectrum');
grid on; set(gca, 'FontSize', 12);

%% Gain stage + summation
G = 1;
final_sig = G * fil2_sig + hfil_sig;
final_sig = final_sig / max(abs(final_sig)) * 0.99;

figure;
plot(t, sig, 'k', t, final_sig, 'g', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Amplitude');
legend('Original Signal', 'Final Signal'); grid on;
set(gca, 'FontSize', 12);

%% Playback (should be uncommented when wanting to perceive the sound)
% sound(final_sig, fs);
% audiowrite('02T19_experiment.wav', final_sig, fs);

%% REAL RECORDING ANALYSIS PLOTS (should be uncommented when using real recording) -
bg_start  = round(0  * fs) + 1;  bg_end   = round(7  * fs);
call_start = round(8 * fs) + 1;  call_end = round(15 * fs);
final_bg   = final_sig(bg_start:bg_end);
final_call = final_sig(call_start:call_end);

[Pxx_bg,   F_bg]   = pwelch(final_bg,   [], [], [], fs);
[Pxx_call, F_call] = pwelch(final_call, [], [], [], fs);

figure;
plot(F_bg,   10*log10(Pxx_bg),   'b', 'LineWidth', 2, 'DisplayName', 'Background (0-7s)');
hold on;
plot(F_call, 10*log10(Pxx_call), 'r', 'LineWidth', 2, 'DisplayName', 'Call (8-15s)');
xlim([0 200]);
xlabel('Frequency (Hz)'); ylabel('Power/Frequency (dB/Hz)');
legend; grid on;
xline(90, '--k', 'f_l = 90 Hz', 'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
set(gca, 'FontSize', 12);

%% Path isolation: HFIL-only vs full output (G=1) during call segment
% This plots the HFIL direct path alone against the full output,
% which is to assess how much of the above-90 Hz elevation
% during the call comes from the direct path vs FIL2 contribution.

hfil_call = hfil_sig(call_start:call_end);
[Pxx_hfil, F_hfil] = pwelch(hfil_call, [], [], [], fs);

figure;
plot(F_bg,   10*log10(Pxx_bg),   'k--', 'LineWidth', 1.5, 'DisplayName', 'Background (0–7s)');
hold on;
plot(F_hfil, 10*log10(Pxx_hfil), 'b',   'LineWidth', 2,   'DisplayName', 'HFIL only – call (8–15s)');
plot(F_call, 10*log10(Pxx_call), 'r',   'LineWidth', 2,   'DisplayName', 'Full output – call (8–15s)');
xlim([0 200]);
xlabel('Frequency (Hz)'); ylabel('Power/Frequency (dB/Hz)');
legend; grid on;
xline(90, '--k', 'f_l = 90 Hz', 'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
set(gca, 'FontSize', 12);


% Configuration comparison (should be uncommented when using real recording)
% fc_values = [40, 90]; colors = ['b','r'];
% labels = {'f_c = 40 Hz', 'f_c = 90 Hz'};
% call_start = round(8*fs)+1; call_end = round(15*fs);
% figure; hold on;
% for i = 1:2
%     fc_cfg = fc_values(i);
%     [z,p,k] = butter(4, fc_cfg/(fs/2), 'high');
%     hfil_cfg = sosfilt(zp2sos(z,p,k), sig);
%     [z,p,k] = butter(4, [10 fc_cfg]/(fs/2), 'bandpass');
%     fil1_cfg = sosfilt(zp2sos(z,p,k), sig);
%     f0_cfg = estimate_f0_hysteresis(fil1_cfg, fs, 0.3, -0.3);
%     c_cfg  = (pi * f0_cfg) / fs;
%     nld_cfg = zeros(size(fil1_cfg));
%     for n = 2:length(fil1_cfg)
%         if fil1_cfg(n-1) < 0 && fil1_cfg(n) >= 0; nld_cfg(n) = 0;
%         else; nld_cfg(n) = nld_cfg(n-1) + c_cfg * abs(fil1_cfg(n)); end
%     end
%     [z,p,k] = butter(4, [fc_cfg 2*fc_cfg]/(fs/2), 'bandpass');
%     fil2_cfg = sosfilt(zp2sos(z,p,k), nld_cfg);
%     final_cfg = fil2_cfg + hfil_cfg;
%     [Pxx_cfg, F_cfg] = pwelch(final_cfg(call_start:call_end), [], [], [], fs);
%     plot(F_cfg, 10*log10(Pxx_cfg), colors(i), 'LineWidth', 2, 'DisplayName', labels{i});
% end
% xlim([0 200]); xlabel('Frequency (Hz)'); ylabel('Power/Frequency (dB/Hz)');
% legend; grid on;
% xline(90,'--k','f_l = 90 Hz','LabelVerticalAlignment','bottom','HandleVisibility','off');
% xline(40,':k', 'f_c = 40 Hz','LabelVerticalAlignment','bottom','HandleVisibility','off');
% set(gca, 'FontSize', 12);