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

signal sens_nreset		: std_logic := '0';
signal sens_pclk		: std_logic := '0';
signal sens_fval		: std_logic := '0';
signal sens_lval		: std_logic := '0';
signal sens_trigger		: std_logic := '0';
signal sens_strobe		: std_logic := '0';

signal sens_data		: std_logic_vector(9 downto 0);

begin

sim : process
begin
	wait for 10us;
	
--	uart_puts("{r1E}", uart_tx, 921600);	
--	wait for 200us;
	
--	uart_puts("{w1E4006}", uart_tx, 921600);	
--	wait for 1us;
	
	uart_puts("{W010010}", uart_tx, 921600);
	wait for 10us;
		
	uart_puts("{W060064}", uart_tx, 921600);	
	wait for 1us;
			
	uart_puts("{W010011}", uart_tx, 921600);
	wait for 1us;
			
	wait;
end process;

clk_50 : process
begin
	clock(50.0, 0ns, clk50);
end process;

clk_pxl : process
begin
	clock(57.0, 3ns, sens_pclk);
end process;

sens : process
begin
	sens_lval <= '0';
	sens_fval <= '0';
	wait for 1ms;	--3.3ms;
		
	wait until rising_edge(sens_pclk);
	sens_fval <= '1';
	
	for l in 0 to 100-1 loop
		wait for 33.0us;
		wait until rising_edge(sens_pclk);
		sens_lval <= '1';
		
		for p in 0 to 1024-1 loop
			sens_data <= random_vec(0, 2**10-1, 10);
			wait until rising_edge(sens_pclk);
		end loop;
		sens_lval <= '0';	
		
	end loop;
	
	wait for 500ns;
	wait until rising_edge(sens_pclk);
	
end process;

rx_0 : process
begin
	uart_getc(uart_rx_char, uart_rx, 921600); 
end process;

cam : entity work.camera_ev76c560
generic map (
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
	SENS_nRESET_O	=> sens_nreset,
	
	SENS_CLK_O		=> open,
	
	SENS_PCLK_I		=> sens_pclk,
	SENS_LVAL_I		=> sens_lval,
	SENS_FVAL_I		=> sens_fval,
	SENS_STROBE_I	=> sens_strobe,
	SENS_DATA_I		=> sens_data,
	
	SENS_TRIGGER_O	=> sens_trigger,
	
	SENS_EN_CLK_O	=> open,
	SENS_EN_1V8_O	=> open,
	SENS_EN_3V3_O	=> open,
	
	SENS_nCS_O 		=> open,
	SENS_SCK_O 		=> open,
	SENS_MOSI_O 	=> open,
	SENS_MISO_I		=> '0',
	
	-- Misc.
	LED_O			=> open,
	DBG_O			=> open	
);


end Testbench;
