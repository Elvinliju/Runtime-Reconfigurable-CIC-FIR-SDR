import os
import sys

# Explicitly add current directory for DLL loading (Python 3.8+)
if sys.version_info >= (3, 8):
    os.add_dll_directory(r'E:\elvin\python_trial')

import struct
import time
import matplotlib.pyplot as plt
import numpy as np
import serial
from rtlsdr import RtlSdr

# Configuration
PORT = 'COM4'
BAUD = 115200
CENTER_FREQ = 100.0e6  # 100 MHz FM band
SAMPLE_RATE = 2.048e6  # 2.048 MSPS
NUM_SAMPLES = 1000

print('Initializing RTL-SDR...')
try:
    sdr = RtlSdr()
    sdr.sample_rate = SAMPLE_RATE
    sdr.center_freq = CENTER_FREQ
    sdr.gain = 'auto'
    raw_iq = sdr.read_samples(NUM_SAMPLES)
    sdr.close()
    print('RTL-SDR capture successful!')
except Exception as e:
    print(f'SDR Error: {e}')
    t = np.linspace(0, 0.1, NUM_SAMPLES)
    raw_iq = np.sin(2 * np.pi * 1000 * t) + 0.3 * np.sin(2 * np.pi * 15000 * t)

# Extract real component and quantize to 16-bit signed integers
real_signal = np.real(raw_iq)
max_val = np.max(np.abs(real_signal))
if max_val > 0:
    input_ints = np.int16(real_signal / max_val * 15000)
else:
    input_ints = np.zeros(NUM_SAMPLES, dtype=np.int16)

print(f'Connecting to FPGA on {PORT} at {BAUD} baud...')
try:
    ser = serial.Serial(PORT, BAUD, timeout=3.0)
    time.sleep(2)
except Exception as e:
    print(f'Error opening serial port: {e}')
    exit()

print(
    f'Streaming {len(input_ints)} samples through UART to FPGA CIC-FIR'
    ' filter...'
)
ser.reset_input_buffer()
ser.reset_output_buffer()

for sample in input_ints:
    byte_low = sample & 0xFF
    byte_high = (sample >> 8) & 0xFF
    ser.write(bytes([byte_low, byte_high]))

time.sleep(0.5)

raw_output = ser.read(ser.in_waiting or 1024)
ser.close()

# Unpack received bytes into 16-bit integers
output_ints = []
for i in range(0, len(raw_output) - 1, 2):
    res_sample = struct.unpack('<h', raw_output[i : i + 2])[0]
    output_ints.append(res_sample)

print(f'Received {len(output_ints)} filtered samples. Plotting results...')

# Plotting time-domain comparison
in_arr = np.array(input_ints, dtype=float)
out_arr = np.array(output_ints, dtype=float)

plt.figure(figsize=(10, 5))
plt.plot(in_arr[: len(out_arr) * 2], label='Raw Input (Python)', color='gray')
plt.plot(
    out_arr,
    label='Filtered Output (FPGA Decimated x2)',
    color='blue',
    linewidth=1.5,
)
plt.title('RTL-SDR Live Stream through Basys 3 FPGA CIC-FIR Filter')
plt.xlabel('Sample Index')
plt.ylabel('Amplitude')
plt.legend()
plt.grid(True)
plt.show()
