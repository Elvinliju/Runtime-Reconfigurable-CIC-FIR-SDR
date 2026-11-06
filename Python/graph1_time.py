import struct
import time
import matplotlib.pyplot as plt
import numpy as np
import serial

PORT = 'COM4'
BAUD = 115200
NUM_SAMPLES = 256

print('=== Graph 1: CIC Input & Output Time-Domain Capture ===')
t = np.arange(NUM_SAMPLES)
# Generate a clean test tone
test_signal = (8000 * np.sin(2 * np.pi * 0.05 * t)).astype(np.int16)

try:
  ser = serial.Serial(PORT, BAUD, timeout=3.0)
  time.sleep(2)
except Exception as e:
  print(f'Serial Error: {e}')
  exit()

ser.reset_input_buffer()
ser.reset_output_buffer()

print('Streaming samples to FPGA...')
for sample in test_signal:
  ser.write(bytes([sample & 0xFF, (sample >> 8) & 0xFF]))

time.sleep(0.5)
raw_output = ser.read(ser.in_waiting or 1024)
ser.close()

output_ints = []
for i in range(0, len(raw_output) - 1, 2):
  output_ints.append(struct.unpack('<h', raw_output[i : i + 2])[0])

out_arr = np.array(output_ints, dtype=float)
in_arr = np.array(test_signal, dtype=float)

# Save to CSV for report appendix
np.savetxt(
    'cic_time_data.csv',
    np.column_stack(
        (in_arr[: len(out_arr)], out_arr[: len(in_arr)])
    ),  # simplified alignment
    delimiter=',',
    header='Input_Sample,Output_Sample',
    comments='',
)
print('Saved data to cic_time_data.csv')

# Plotting Graph 1
plt.figure(figsize=(10, 4.5))
plt.plot(
    in_arr[:120],
    label='Input Test Samples (Python)',
    color='gray',
    linestyle='--',
    marker='.',
)
plt.plot(
    out_arr[:60],
    label='FPGA CIC Decimated Output',
    color='blue',
    linewidth=2,
    marker='o',
)
plt.title(
    'Time-Domain Waveform: Input vs 3-Stage CIC Decimated Output (Basys 3 FPGA)'
)
plt.xlabel('Sample Index')
plt.ylabel('Amplitude (16-bit Signed)')
plt.legend(loc='upper right')
plt.grid(True, linestyle=':', alpha=0.7)
plt.tight_layout()
plt.savefig('graph1_time_domain.png', dpi=300)
plt.show()
