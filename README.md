# Elephant-Infrasound-BEP
This system is a DSP pipeline that enables sonification of elephant infrasound. The system is based on the system developed by Erik Larsen and Ronald Aarts. 

## Pipeline
HFIL (high-pass 90 Hz) → FIL1 (bandpass 10–90 Hz) → NLD (full-wave integrator with zero-crossing resets) → FIL2 (bandpass 90–180 Hz) → gain stage. 
HFIL and the gain+FIL2 output are summed for the final signal.

## Files
- `ULTRABASS_ALGO_NOVELTY.m` — main MATLAB pipeline (synthetic and real recording modes)
- `ULTRABASS_ALGO_python.py` — Python equivalent of the main MATLAB pipeline
- `estimate_f0_hysteresis.m` / `estimate_f0_hysteresis.py` — fundamental frequency estimator using a software hysteresis comparator
- `pi_pipeline.py` — real-time deployment pipeline for Raspberry Pi 4B

## Dependencies
MATLAB with Signal Processing Toolbox. Python: `numpy`, `scipy`, `sounddevice`.

## Usage
In the MATLAB script, switch between synthetic mode and real recording mode by commenting/uncommenting the relevant input block at the top. For Python, replace the hardcoded WAV file path in the main block with your own. For the Pi, Bluetooth output requires manual PulseAudio sink configuration each session.

## Hardware (for deployment)
Raspberry Pi 4B, Jordan ATD4-S microphone (infrasound microphone), Bose SoundLink Micro speaker.

