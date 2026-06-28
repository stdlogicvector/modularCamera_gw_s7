## Camera

# Config
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
#set_property CONFIG_MODE SPIx4 [current_design]
#set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLDOWN [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPPOWERDOWN ENABLE [current_design]

# 50MHz Clock
set_property PACKAGE_PIN G11 [get_ports CLK50_I]
set_property IOSTANDARD LVCMOS33 [get_ports CLK50_I]
create_clock -period 20.000 -name CLK50_I -waveform {0.000 10.000} [get_ports {CLK50_I}]

# Flash SPI (BANK14, HR, 3.3V)
set_property PACKAGE_PIN C11 [get_ports FLASH_CS_O]
set_property IOSTANDARD LVCMOS33 [get_ports FLASH_CS_O]
#set_property PACKAGE_PIN A8 [get_ports {FLASH_SCK_O}]		#CCLK Pin not directly available
#set_property IOSTANDARD LVCMOS33 [get_ports {FLASH_SCK_O}]
set_property PACKAGE_PIN B11 [get_ports {FLASH_DQ_IO[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FLASH_DQ_IO[0]}]
set_property PACKAGE_PIN B12 [get_ports {FLASH_DQ_IO[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FLASH_DQ_IO[1]}]
set_property PACKAGE_PIN D10 [get_ports {FLASH_DQ_IO[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FLASH_DQ_IO[2]}]
set_property PACKAGE_PIN C10 [get_ports {FLASH_DQ_IO[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FLASH_DQ_IO[3]}]

# LED on FPGA Module
set_property PACKAGE_PIN M10 [get_ports LED_O]
set_property IOSTANDARD LVCMOS33 [get_ports LED_O]

# UART (BANK14, 3.3V) # RX = FPGA -> FX3, TX = FX3 -> FPGA
set_property PACKAGE_PIN A13 [get_ports {UART_TX_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {UART_TX_O}]
set_property PACKAGE_PIN A12 [get_ports {UART_RX_I}]
set_property IOSTANDARD LVCMOS33 [get_ports {UART_RX_I}]
set_property PULLUP true [get_ports {UART_RX_I}]
set_property PACKAGE_PIN B10 [get_ports {UART_RTS_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {UART_RTS_O}]
set_property PACKAGE_PIN A10 [get_ports {UART_CTS_I}]
set_property IOSTANDARD LVCMOS33 [get_ports {UART_CTS_I}]

# FX3 (HR BANK14, 3.3V)
# CTL
set_property PACKAGE_PIN J14 [get_ports {FX3_CTL_IO[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_CTL_IO[0]}]
set_property PACKAGE_PIN K12 [get_ports {FX3_CTL_IO[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_CTL_IO[1]}]
set_property PACKAGE_PIN H11 [get_ports {FX3_CTL_IO[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_CTL_IO[2]}]
set_property PACKAGE_PIN H12 [get_ports {FX3_CTL_IO[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_CTL_IO[3]}]

# Clock
set_property PACKAGE_PIN J12 [get_ports {FX3_CLOCK_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_CLOCK_O}]

# Data
set_property PACKAGE_PIN P10 [get_ports {FX3_DATA_O[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[0]}]
set_property PACKAGE_PIN P11 [get_ports {FX3_DATA_O[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[1]}]
set_property PACKAGE_PIN M14 [get_ports {FX3_DATA_O[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[2]}]
set_property PACKAGE_PIN N11 [get_ports {FX3_DATA_O[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[3]}]
set_property PACKAGE_PIN M11 [get_ports {FX3_DATA_O[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[4]}]
set_property PACKAGE_PIN N10 [get_ports {FX3_DATA_O[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[5]}]
set_property PACKAGE_PIN P13 [get_ports {FX3_DATA_O[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[6]}]
set_property PACKAGE_PIN M13 [get_ports {FX3_DATA_O[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[7]}]

set_property PACKAGE_PIN N14 [get_ports {FX3_DATA_O[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[8]}]
set_property PACKAGE_PIN L12 [get_ports {FX3_DATA_O[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[9]}]
set_property PACKAGE_PIN P12 [get_ports {FX3_DATA_O[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[10]}]
set_property PACKAGE_PIN L14 [get_ports {FX3_DATA_O[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[11]}]
set_property PACKAGE_PIN M12 [get_ports {FX3_DATA_O[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[12]}]
set_property PACKAGE_PIN L13 [get_ports {FX3_DATA_O[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[13]}]
set_property PACKAGE_PIN K11 [get_ports {FX3_DATA_O[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[14]}]
set_property PACKAGE_PIN J13 [get_ports {FX3_DATA_O[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[15]}]

set_property PACKAGE_PIN H14 [get_ports {FX3_DATA_O[16]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[16]}]
set_property PACKAGE_PIN G14 [get_ports {FX3_DATA_O[17]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[17]}]
set_property PACKAGE_PIN C14 [get_ports {FX3_DATA_O[18]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[18]}]
set_property PACKAGE_PIN E12 [get_ports {FX3_DATA_O[19]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[19]}]
set_property PACKAGE_PIN E13 [get_ports {FX3_DATA_O[20]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[20]}]
set_property PACKAGE_PIN D13 [get_ports {FX3_DATA_O[21]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[21]}]
set_property PACKAGE_PIN D12 [get_ports {FX3_DATA_O[22]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[22]}]
set_property PACKAGE_PIN F12 [get_ports {FX3_DATA_O[23]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[23]}]

set_property PACKAGE_PIN H13 [get_ports {FX3_DATA_O[24]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[24]}]
set_property PACKAGE_PIN C12 [get_ports {FX3_DATA_O[25]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[25]}]
set_property PACKAGE_PIN D14 [get_ports {FX3_DATA_O[26]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[26]}]
set_property PACKAGE_PIN B13 [get_ports {FX3_DATA_O[27]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[27]}]
set_property PACKAGE_PIN B14 [get_ports {FX3_DATA_O[28]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[28]}]
set_property PACKAGE_PIN J11 [get_ports {FX3_DATA_O[29]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[29]}]
set_property PACKAGE_PIN F14 [get_ports {FX3_DATA_O[30]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[30]}]
set_property PACKAGE_PIN F13 [get_ports {FX3_DATA_O[31]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FX3_DATA_O[31]}]

# Sensor (HR BANK 34, 3.3V)
# Debug pins
set_property PACKAGE_PIN P5 [get_ports {DBG_O[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DBG_O[0]}]
set_property PACKAGE_PIN N4 [get_ports {DBG_O[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DBG_O[1]}]

# SPI
set_property PACKAGE_PIN B1 [get_ports {SENS_nCS_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_nCS_O}]
set_property PACKAGE_PIN B5 [get_ports {SENS_SCK_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_SCK_O}]
set_property PACKAGE_PIN A5 [get_ports {SENS_MOSI_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_MOSI_O}]
set_property PACKAGE_PIN B2 [get_ports {SENS_MISO_I}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_MISO_I}]

# Enables
set_property PACKAGE_PIN C4 [get_ports {SENS_EN_PIX_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_EN_PIX_O}]
set_property PACKAGE_PIN M2 [get_ports {SENS_EN_3V3_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_EN_3V3_O}]
set_property PACKAGE_PIN J3 [get_ports {SENS_EN_1V8_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_EN_1V8_O}]
set_property PACKAGE_PIN P2 [get_ports {SENS_EN_CLK_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_EN_CLK_O}]

# Trigger
set_property PACKAGE_PIN B6 [get_ports {SENS_TRIG_O[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_TRIG_O[0]}]
set_property PACKAGE_PIN A4 [get_ports {SENS_TRIG_O[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_TRIG_O[1]}]
set_property PACKAGE_PIN C3 [get_ports {SENS_TRIG_O[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_TRIG_O[2]}]

# Reset
set_property PACKAGE_PIN B3 [get_ports {SENS_nRESET_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_nRESET_O}]

# Monitor
set_property PACKAGE_PIN A3 [get_ports {SENS_MONITOR_I[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_MONITOR_I[0]}]
set_property PACKAGE_PIN A2 [get_ports {SENS_MONITOR_I[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_MONITOR_I[1]}]

# Clock
set_property PACKAGE_PIN N1 [get_ports {SENS_CLOCK_O}]
set_property IOSTANDARD LVCMOS33 [get_ports {SENS_CLOCK_O}]
set_property PACKAGE_PIN D1 [get_ports {SENS_CLOCKp_I}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_CLOCKp_I}]
set_property PACKAGE_PIN C1 [get_ports {SENS_CLOCKn_I}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_CLOCKn_I}]
set_property PACKAGE_PIN P4 [get_ports {SENS_CLOCKp_O}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_CLOCKp_O}]
set_property PACKAGE_PIN P3 [get_ports {SENS_CLOCKn_O}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_CLOCKn_O}]

# Data
set_property PACKAGE_PIN E2 [get_ports {SENS_DATAp_I[0]}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_DATAp_I[0]}]
set_property PACKAGE_PIN D2 [get_ports {SENS_DATAn_I[0]}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_DATAn_I[0]}]

set_property PACKAGE_PIN G1 [get_ports {SENS_DATAp_I[1]}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_DATAp_I[1]}]
set_property PACKAGE_PIN F1 [get_ports {SENS_DATAn_I[1]}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_DATAn_I[1]}]

set_property PACKAGE_PIN H4 [get_ports {SENS_DATAp_I[2]}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_DATAp_I[2]}]
set_property PACKAGE_PIN H3 [get_ports {SENS_DATAn_I[2]}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_DATAn_I[2]}]

set_property PACKAGE_PIN J2 [get_ports {SENS_DATAp_I[3]}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_DATAp_I[3]}]
set_property PACKAGE_PIN J1 [get_ports {SENS_DATAn_I[3]}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_DATAn_I[3]}]

set_property PACKAGE_PIN M1 [get_ports {SENS_SYNCp_I}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_SYNCp_I}]
set_property PACKAGE_PIN L1 [get_ports {SENS_SYNCn_I}]
set_property IOSTANDARD LVDS_33 [get_ports {SENS_SYNCn_I}]

