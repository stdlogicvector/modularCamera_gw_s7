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
--  CWD                 : string := "D:/Documents/Code/vhdl/modularCamera/Camera.srcs/sim_1/new/"
);
--  Port ( );
end camera_tb;

architecture Testbench of camera_tb is

signal clk50			: std_logic := '0';
signal clk100			: std_logic := '0';

signal sens_clk			: std_logic := '0';
signal sens_trig		: std_logic := '0';
signal sens_dval		: std_logic := '0';
signal sens_data		: std_logic_vector(31 downto 0) := (others => '0');
signal sens_gpio		: std_logic_vector( 2 downto 0) := (others => 'Z');
signal sens_cs			: std_logic := '0';
signal sens_sck			: std_logic := '0';
signal sens_miso		: std_logic := '0';
signal sens_mosi		: std_logic := '0';

signal uart_tx			: std_logic := '1';
signal uart_rx			: std_logic := '1';

signal uart_rx_char		: std_logic_vector(7 downto 0) := x"00";

begin

sim : process
begin
	wait for 5us;
	
	uart_puts("{w00081234}", uart_tx, 921600);
	
	wait for 10us;
	
	uart_puts("{r0008}", uart_tx, 921600);
	
	wait for 10us;
	
	uart_puts("{W060A05}", uart_tx, 921600);
	
	wait for 10us;
	
	uart_puts("{W010501}", uart_tx, 921600);
	
	wait for 1ms;
	
	uart_puts("{W010000}", uart_tx, 921600);
	
	wait for 10us;
	
	uart_puts("{W010503}", uart_tx, 921600);
	
	wait for 1ms;
	
	uart_puts("{W010000}", uart_tx, 921600);
			
	wait;
end process;

clk_50 : process
begin
	clock(50.0, 0ns, clk50);
end process;

clk_100 : process
begin
	clock(100.0, 3ns, clk100);
end process;

rx_0 : process
begin
	uart_getc(uart_rx_char, uart_rx, 921600); 
end process;

spi : process(sens_sck)
begin
	if rising_edge(sens_sck) then
		sens_miso <= random_bit;
	end if;
end process;

sensor : entity work.aisc110c_sim
generic map (
	FILE_BASE		=> CWD & "test",
	FILE_EXT		=> ".pgm",
	WIDTH			=> 80,
	HEIGHT			=> 120,
	CHANNELS		=> 4,
	BPP				=> 8,
	PREAMBLE		=> 2,
	INTERLEAVED		=> false,
	SCALE			=> 1
)
port map (
	CLK_I			=> clk100,
	RST_I			=> '0',
	
	TRIGGER_I		=> sens_gpio(0),
	
	CLK_O			=> sens_clk,
	DVAL_O			=> sens_dval,
	FSYNC_O			=> sens_gpio(2), -- GPIO1 has no contact on Sensor PCBv1
	DATA_O			=> sens_data	
);

cam : entity work.camera_aisc110c
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
	SENS_CLOCK_I	=> sens_clk,
	SENS_DVAL_I		=> sens_dval,
	SENS_DATA_I		=> sens_data,
	
	SENS_GP_IO		=> sens_gpio,
	SENS_CS_O		=> sens_cs,
	SENS_SCK_O		=> sens_sck,
	SENS_MOSI_O		=> sens_mosi,
	SENS_MISO_I		=> sens_miso,
	
	-- Misc.
	LED_O			=> open	
);

end Testbench;
