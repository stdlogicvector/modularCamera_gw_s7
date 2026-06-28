# ModularCamera Gateware (Spartan 7)

This repository contains the VHDL code for the Spartan7 of the modularCamera system as a Vivado 2025.1 project.

## Structure

To accomodate the different sensors, there is a toplevel file for each. But the structure is always similiar and contains the following:

- Sensor Data Interface: Receive data from the sensor and convert it to AXI4-Stream format. Also does stuff like triggering or clocking.
- Data Processing: Do something with the data (e.g. convert colors, upscale, ROI, etc.)
- Output: Output the AXI4-Stream to either the FX3 USB3 or the Gigabit Ethernet
- Sensor Configuration Interface: SPI or I2C interface for controlling the sensor.
- Sensor Initalisation Sequence: Most sensors need several registers configured upon power-up. This block automatically goes through a stored sequence.
- command handler: Decodes and interprets commands received via the UART from the FX3 or via Ethernet.
- Internal Registers: Configurable values to control the workings of the FPGA.
- Trigger Generator: Generates Trigger and Exposure signals with configurable timing.
- Test Image Generator: Generates several known data patterns that can be used for testing.
