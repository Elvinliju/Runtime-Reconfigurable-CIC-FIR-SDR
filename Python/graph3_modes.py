import struct
import time
import matplotlib.pyplot as plt
import numpy as np
import serial

PORT = 'COM4'
BAUD = 115200
NUM_SAMPLES = 500

print('=== Graph 3: Multi-Decimation Mode Verification (R = 2, 4, 8, 16) ===')
r_modes = [2, 4, 8, 16]
measured_output_counts = []

try:
  ser = serial.Serial(PORT, BAUD, timeout=3.0)
  time.sleep(2)
except Exception as e:
  print(f'Serial Error: {e}')
  exit()

test_signal = (
    5000 * np.sin(2 * np.pi * np.arange(NUM_SAMPLES) * 0.02)
).astype(np.int16)

for r in r_modes:
  input(
      f'\n>>> ACTION: Set FPGA switches V17/V16 for Decimation Ratio R = {r}'
      ' and press Enter...'
  )
  ser.reset_input_buffer()
  ser.reset_output_buffer()

  for sample in test_signal:
    ser.write(bytes([sample & 0xFF, (sample >> 8) & 0xFF]))

  time.sleep(0.5)
  raw_output = ser.read(ser.in_waiting or 2048)

  out_count = len(raw_output) // 2
  measured_output_counts.append(out_count)
  print(
      f'Decimation R = {r:2d} | Sent: {NUM_SAMPLES} samples | Received'
      f' Output Samples: {out_count}'
  )

ser.close()

# Save summary to CSV
np.savetxt(
    'decimation_summary.csv',
    np.column_stack((r_modes, measured_output_counts)),
    delimiter=',',
    header='Decimation_Ratio,Received_Sample_Count',
    comments='',
)

# Plotting Graph 3
plt.figure(figsize=(9, 4.5))
plt.plot(
    r_modes,
    measured_output_counts,
    marker='s',
    color='purple',
    linewidth=2.5,
    markersize=8,
)
plt.title(
    'FPGA Output Sample Count vs. Decimation Ratio (R = 2, 4, 8, 16 Validation)'
)
plt.xlabel('Decimation Factor (R)')
plt.ylabel('Received Sample Count (Through UART)')
plt.xticks(r_modes)
plt.grid(True, linestyle=':', alpha=0.7)
plt.tight_layout()
plt.savefig('graph3_decimation_modes.png', dpi=300)
plt.show()
