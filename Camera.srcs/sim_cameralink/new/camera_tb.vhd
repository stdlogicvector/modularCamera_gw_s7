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

signal XCLKp			: std_logic := '0';
signal XCLKn			: std_logic := '1';

signal Xp				: std_logic_vector(3 downto 0) := (others => '0');
signal Xn				: std_logic_vector(3 downto 0) := (others => '1');

signal CCp				: std_logic_vector(3 downto 0) := (others => '0');
signal CCn				: std_logic_vector(3 downto 0) := (others => '1');
	
signal uart_tx			: std_logic := '1';
signal uart_rx			: std_logic := '1';

signal uart_rx_char		: std_logic_vector(7 downto 0) := x"00";

begin

sim : process
begin
	wait for 5us;
	
	uart_puts("{W030000}", uart_tx, 921600);
	
	wait for 1us;
	
	uart_puts("{W020190}", uart_tx, 921600);
	
	wait for 1us;
	
	uart_puts("{W070001}", uart_tx, 921600);
	
	wait for 1us;
	
	uart_puts("{W050064}", uart_tx, 921600);
	
	wait for 1us;
	
	uart_puts("{W060064}", uart_tx, 921600);
	
	wait for 1us;
	
	uart_puts("{W010313}", uart_tx, 921600);
	
	wait for 1ms;
	
	uart_puts("{W010002}", uart_tx, 921600);
			
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

sensor : entity work.cameralink_sim
generic map (
	FILE_BASE		=> CWD & "test",
	FILE_EXT		=> ".pgm",
	WIDTH			=> 120,
	HEIGHT			=> 80,
	CLOCK_MHZ		=> 80.0, --MHz
	CHANNELS		=> 3,
	BPP				=> 8,
	N				=> 7,	-- SERDES Factor
	D				=> 4,	-- Data Lines
	LINE_PAUSE		=> 100ns,
	FRAME_PAUSE		=> 1us,
	INTERLEAVED		=> false,
	CLOCK_PATTERN	=> "1100011",
	SCALE			=> 1
)
port map (
	RST_I			=> '0',
	
	XCLKp_O			=> XCLKp,
	XCLKn_O			=> XCLKn,

	Xp_O			=> Xp,
	Xn_O			=> Xn,
		
	CCp_I			=> CCp,
	CCn_I			=> CCn,
	
	SERTFGp_O		=> open,
	SERTFGn_O		=> open,
	
	SERTCp_I		=> '1',
	SERTCn_I		=> '0'
);

cam : entity work.camera_cameralink
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
	-- Clock is inverted on PCB
	XCLKp_I			=> XCLKp,
	XCLKn_I			=> XCLKn,
	
	-- Data lines are inverted on PCB
	Xp_I			=> Xn,
	Xn_I			=> Xp,
	
	CCp_O			=> CCp,
	CCn_O			=> CCn,
	
	SERTFGp_I		=> '1',
	SERTFGn_I		=> '0',
	
	SERTCp_O		=> open,
	SERTCn_O		=> open,
	
	-- Misc.
	LED_O			=> open	
);

end Testbench;
