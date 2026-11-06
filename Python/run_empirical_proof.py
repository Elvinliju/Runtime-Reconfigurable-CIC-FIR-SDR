import time
import numpy as np
import serial
import matplotlib.pyplot as plt

# UART Configuration
PORT = 'COM4'
BAUD = 115200

# Test Parameters
DECIM_RATIO = 2  # R = 2 as tested previously
NUM_SAMPLES = 512

# Generate multi-tone test frequencies across passband
fs = 2048000 / DECIM_RATIO  # Effective output sample rate indicator
freqs_kHz = np.array([5.0, 12.5, 20.0])  # Test frequencies in kHz


def generate_multitone_signal(frequencies, num_samples):
  t = np.arange(num_samples)
  signal = np.zeros(num_samples)
  for f in frequencies:
    # Scale amplitude safely to avoid overflow (max amplitude ~12000)
    signal += 4000 * np.sin(2 * np.pi * (f * 1000 / 2048000) * t)
  return np.clip(signal, -32768, 32767).astype(np.int16)


def transmit_and_receive(ser, input_samples):
  output_samples = []
  ser.reset_input_buffer()
  ser.reset_output_buffer()

  for sample in input_samples:
    # Send 16-bit sample as Low Byte then High Byte
    low_byte = sample & 0xFF
    high_byte = (sample >> 8) & 0xFF
    ser.write(bytes([low_byte, high_byte]))

    # Read back 2-byte response from FPGA UART TX
    res_low = ser.read(1)
    res_high = ser.read(1)
    if len(res_low) == 1 and len(res_high) == 1:
      val = res_low[0] | (res_high[0] << 8)
      # Convert unsigned 16-bit back to signed 16-bit
      if val >= 32768:
        val -= 65536
      output_samples.append(val)
    else:
      output_samples.append(0)

  return np.array(output_samples)


def measure_amplitude(output_signal, test_freq, sampling_rate):
  # Least-squares sinusoidal amplitude fit for robust measurement
  N = len(output_signal)
  t = np.arange(N) / sampling_rate
  omega = 2 * np.pi * test_freq

  # Construct design matrix for sine and cosine
  A = np.column_stack([np.cos(omega * t), np.sin(omega * t)])
  coef, _, _, _ = np.linalg.lstsq(A, output_signal, rcond=None)

  amplitude = np.sqrt(coef[0] ** 2 + coef[1] ** 2)
  return amplitude


print('=== CIC-FIR Empirical Proof Capture Tool ===')
print(f'Opening UART port {PORT} at {BAUD} baud...')

try:
  ser = serial.Serial(PORT, BAUD, timeout=0.1)
except Exception as e:
  print(f'Error opening serial port: {e}')
  exit()

test_signal = generate_multitone_signal(freqs_kHz, NUM_SAMPLES)

# --- TEST A: CIC Only ---
print('\n--- TEST A: CIC-ONLY CAPTURE ---')
input(
    '>>> ACTION: Flip SW3 (Pin W17) to HIGH (Bypass ON = CIC Only) and press'
    ' Enter...'
)
print('Streaming test samples to FPGA...')
raw_cic_output = transmit_and_receive(ser, test_signal)
print('CIC-Only capture complete!')

# --- TEST B: CIC + FIR Compensated ---
print('\n--- TEST B: CIC + 15-TAP FIR CAPTURE ---')
input(
    '>>> ACTION: Flip SW3 (Pin W17) to LOW (Bypass OFF = CIC + FIR) and press'
    ' Enter...'
)
print('Streaming test samples to FPGA...')
raw_fir_output = transmit_and_receive(ser, test_signal)
print('CIC + FIR capture complete!')

ser.close()

# Compute measured amplitudes across frequencies
cic_gains = []
fir_gains = []

effective_fs = 100000 / DECIM_RATIO  # Base evaluation clock reference

for f in freqs_kHz:
  amp_cic = measure_amplitude(raw_cic_output, f * 1000, effective_fs)
  amp_fir = measure_amplitude(raw_fir_output, f * 1000, effective_fs)
  cic_gains.append(amp_cic)
  fir_gains.append(amp_fir)

# Normalize to 0 dB at lowest frequency (5 kHz reference)
cic_gains = 20 * np.log10(np.array(cic_gains) / cic_gains[0] + 1e-9)
fir_gains = 20 * np.log10(np.array(fir_gains) / fir_gains[0] + 1e-9)

# Calculate Passband Ripple
cic_ripple = np.max(cic_gains) - np.min(cic_gains)
fir_ripple = np.max(fir_gains) - np.min(fir_gains)

print('\n========================================')
print('           EXPERIMENT RESULTS           ')
print('========================================')
print(f'Frequencies tested: {freqs_kHz} kHz')
print(f'CIC-Only Passband Ripple     : {cic_ripple:.2f} dB')
print(f'CIC+FIR Passband Ripple      : {fir_ripple:.2f} dB')
print(
    f'Ripple Reduction Improvement : {(cic_ripple - fir_ripple):.2f} dB'
    ' flattening'
)
print('========================================')

# --- PLOTTING PROOF GRAPH ---
plt.figure(figsize=(9, 5))
plt.plot(
    freqs_kHz,
    cic_gains,
    color='red',
    linestyle='--',
    linewidth=2,
    marker='x',
    label=f'Measured CIC-Only (Ripple: {cic_ripple:.2f} dB)',
)
plt.plot(
    freqs_kHz,
    fir_gains,
    color='blue',
    linewidth=2.5,
    marker='o',
    label=f'Measured CIC + 15-Tap FIR (Ripple: {fir_ripple:.2f} dB)',
)

plt.title('Empirical Hardware Proof: Passband Droop Flattened by 15-Tap FIR')
plt.xlabel('Passband Frequency (kHz)')
plt.ylabel('Normalized Magnitude Response (dB)')
plt.grid(True, linestyle=':', alpha=0.7)
plt.ylim(-5, 2)
plt.legend(loc='lower left', frameon=True)
plt.tight_layout()
plt.show()
