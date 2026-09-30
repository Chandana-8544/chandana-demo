# AXI4-Lite Interface – SystemVerilog

## Project Overview

This project implements and verifies an AXI4-Lite interface using
SystemVerilog.

The project contains a Design Under Test (DUT) and a SystemVerilog
testbench for simulation-based verification.

## Design

The AXI4-Lite interface includes:

- Clock and reset
- Write address channel
- Write data channel
- Write response channel
- Read address channel
- Read data channel
- VALID/READY handshake signals

## Verification

A SystemVerilog testbench is used to apply transactions to the DUT
and verify the interface behavior.

The design was simulated using Xilinx Vivado.

## Files

- `axi_lite_interface.sv` - AXI4-Lite DUT
- `tb_axi_lite_interface.sv` - SystemVerilog testbench
- `waveform.png` - Simulation waveform

## Tools Used

- SystemVerilog
- Xilinx Vivado
- GitHub

## Author

Paanaganti Chandana
