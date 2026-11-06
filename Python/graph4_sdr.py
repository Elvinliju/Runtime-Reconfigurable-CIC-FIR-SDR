import os
import sys

if sys.version_info >= (3, 8):
  os.add_dll_directory(r'E:\elvin\python_trial')

import struct
import time
import matplotlib.pyplot as plt
import numpy as np
import serial
from rtlsdr import RtlSdr

PORT = 'COM4'
BAUD = 115200
CENTER_FREQ = 100.0e6
SAMPLE_RATE = 2.048e6
NUM_SAMPLES = 1000

print('=== Graph 4: Live RTL-SDR Airwave Capture & FPGA Processing ===')
try:
  sdr = RtlSdr()
  sdr.sample_rate = SAMPLE_RATE
  sdr.center_freq = CENTER_FREQ
  sdr.gain = 'auto'
  raw_iq = sdr.read_samples(NUM_SAMPLES)
  sdr.close()
  print('RTL-SDR capture successful!')
except Exception as e:
  print(f'SDR Warning ({e}). Using synthetic fallback signal.')
  t = np.linspace(0, 0.1, NUM_SAMPLES)
  raw_iq = np.sin(2 * np.pi * 1000 * t) + 0.3 * np.sin(2 * np.pi * 15000 * t)

real_signal = np.real(raw_iq)
max_val = np.max(np.abs(real_signal))
input_ints = (
    np.int16(real_signal / max_val * 15000)
    if max_val > 0
    else np.zeros(NUM_SAMPLES, dtype=np.int16)
)

try:
  ser = serial.Serial(PORT, BAUD, timeout=3.0)
  time.sleep(2)
except Exception as e:
  print(f'Serial Error: {e}')
  exit()

ser.reset_input_buffer()
ser.reset_output_buffer()

print('Streaming live SDR stream through FPGA hardware filter...')
for sample in input_ints:
  ser.write(bytes([sample & 0xFF, (sample >> 8) & 0xFF]))

time.sleep(0.5)
raw_output = ser.read(ser.in_waiting or 1024)
ser.close()

output_ints = []
for i in range(0, len(raw_output) - 1, 2):
  output_ints.append(struct.unpack('<h', raw_output[i : i + 2])[0])

in_arr = np.array(input_ints, dtype=float)
out_arr = np.array(output_ints, dtype=float)
min_len = min(len(in_arr), len(out_arr))

# Plotting Graph 4
plt.figure(figsize=(10, 5))
plt.plot(
    in_arr[:min_len][:200],
    label='Live RTL-SDR Input Signal (Python)',
    color='gray',
    alpha=0.9,
)
plt.plot(
    out_arr[: 200 // 2],
    label='FPGA Compensated Filter Output (CIC + FIR)',
    color='blue',
    linewidth=2,
)
plt.title(
    'Live SDR Airwave Processing: Hardware Accelerator vs. Raw RF Stream'
)
plt.xlabel('Sample Index')
plt.ylabel('Amplitude (16-bit)')
plt.legend(loc='upper right', frameon=True)
plt.grid(True, linestyle=':', alpha=0.7)
plt.tight_layout()
plt.savefig('graph4_live_sdr.png', dpi=300)
plt.show()
