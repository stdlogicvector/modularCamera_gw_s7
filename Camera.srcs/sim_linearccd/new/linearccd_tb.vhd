library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use work.util.all;

entity camera_tb is
Generic (
	SIMULATION			: boolean := TRUE;
	UART_BAUDRATE		: integer := 921600;
	CWD					: string := "V:/vhdl/modularCamera/Camera.srcs/sim_1/new/"
);
--  Port ( );
end camera_tb;

architecture Testbench of camera_tb is

signal clk50			: std_logic := '0';
signal clk100			: std_logic := '0';
	
signal uart_tx			: std_logic := '1';
signal uart_rx			: std_logic := '1';

signal uart_rx_char		: std_logic_vector(7 downto 0) := x"00";

begin

sim : process
begin
	wait for 300us;
	
	uart_puts("{W060003}", uart_tx, 921600);
		
	wait for 1us;
	
	uart_puts("{W010001}", uart_tx, 921600);
			
	wait;
end process;

clk_50 : process
begin
	clock(50.0, 0ns, clk50);
end process;

rx_0 : process
begin
	uart_getc(uart_rx_char, uart_rx, 921600); 
end process;

cam : entity work.camera_linearCCD
generic map (
	CCDTYPE			=> "ILX506",
	UART_BAUDRATE	=> UART_BAUDRATE,
	SIMULATION		=> SIMULATION
)
port map (
	CLK50_I			=> clk50,
	
	-- Flash
	FLASH_CS_O		=> open,
--	FLASH_SCK_O		=> open,
	FLASH_DQ_IO		=> open,
	
	-- FX3
	FX3_CLOCK_O		=> open,
	FX3_CTL_IO		=> open,
	FX3_DATA_O		=> open,
		
	UART_TX_O		=> uart_rx,
	UART_RX_I		=> uart_tx,
	UART_CTS_I		=> '0',
	UART_RTS_O		=> open,
		
	-- Sensor
	SENS_CTL_O		=> open,
	
	-- ADCs	
	SENS_CS_O		=> open,
	SENS_SCK_O		=> open,
	SENS_SDO_I		=> (others => '0'),
	
	-- Misc.
	LED_O			=> open,
	DBG_O			=> open	
);

end Testbench;
