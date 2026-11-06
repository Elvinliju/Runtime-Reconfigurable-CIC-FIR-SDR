
# Runtime-Reconfigurable CIC-FIR Compensation Filter with SDR Application

An FPGA-based runtime-reconfigurable CIC-FIR compensation filter for Software Defined Radio (SDR) applications, implemented using Verilog HDL on the Xilinx Basys 3 FPGA development board.

## Overview

This project implements a configurable CIC-FIR filtering architecture for digital signal processing in SDR applications.

A Cascaded Integrator-Comb (CIC) filter performs efficient decimation, while a Finite Impulse Response (FIR) compensation filter corrects the passband droop introduced by the CIC filter.

The system integrates RTL-SDR input, Python-based data transfer, FPGA processing, and output visualization.

## Key Features

- Runtime-selectable decimation ratios: 2, 4, 8, and 16.
- Three-stage CIC filter architecture.
- 15-tap FIR compensation filter.
- FPGA-based real-time signal processing.
- CIC-only and CIC-plus-FIR operating modes.
- RTL-SDR integration with Python-based data transfer and visualization.

## Hardware and Software Requirements

### Hardware
- Xilinx Basys 3 FPGA (Artix-7 XC7A35T)
- RTL-SDR receiver
- USB connection for data transfer

### Software and Tools
- Xilinx Vivado 2022.2
- Verilog HDL
- Python
- RTL-SDR software and libraries

## System Architecture

RTL-SDR Receiver
        |
        v
Python Data Acquisition
        |
        v
UART Data Transfer
        |
        v
Basys 3 FPGA
        |
        v
3-Stage CIC Filter
        |
        v
15-Tap FIR Compensation Filter
        |
        v
UART Output
        |
        v
Python Output Visualization

## Filter Configuration

| Mode | Decimation Ratio |
|------|------------------|
| 00   | R = 2             |
| 01   | R = 4             |
| 10   | R = 8             |
| 11   | R = 16            |

The design supports switching between CIC-only operation and CIC-FIR compensated operation.

## Implementation Results

Measured passband ripple comparison:

| Configuration | Measured Ripple |
|----------------|-----------------|
| CIC Only       | 12.05 dB         |
| CIC + FIR      | 2.42 dB          |

**Measured improvement: 9.63 dB**

The FIR compensation stage significantly reduces the measured passband ripple compared with the CIC-only response under the tested conditions.

## Project Structure

```text
Runtime-Reconfigurable-CIC-FIR-SDR/
|
├── RTL/
|   ├── Verilog source files
|
├── Python/
|   ├── Python interface scripts
|
├── Simulation/
|   ├── Testbenches and simulation files
|
├── Results/
|   ├── Waveforms
|   ├── Output screenshots
|   └── Performance graphs
|
├── Documentation/
|   └── Project report
|
└── README.md
```

*The folder structure above is illustrative; update it to match the files actually uploaded.*

## Applications

- Software Defined Radio (SDR)
- Digital signal processing
- FPGA-based decimation systems
- Reconfigurable digital filters
- Communication signal processing

## Future Improvements

- FPGA resource utilization analysis.
- Timing and maximum operating frequency analysis.
- Further optimization of FIR implementation.
- Extended SDR testing across different signal conditions.

## Author

**Elvin Liju**

B.Tech Electronics Engineering (VLSI Design and Technology)

GitHub: [Elvinliju](https://github.com/Elvinliju)

LinkedIn: [Elvin Liju](https://www.linkedin.com/in/elvin-liju-8273712a0)
