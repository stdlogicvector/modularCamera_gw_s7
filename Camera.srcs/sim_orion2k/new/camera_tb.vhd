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

signal uart_tx						: std_logic := '1';
signal uart_rx						: std_logic := '1';

signal uart_rx_char					: std_logic_vector(7 downto 0) := x"00";

signal sens_cs						: std_logic := '0';
signal sens_sck						: std_logic := '0';
signal sens_miso					: std_logic := '0';
signal sens_mosi					: std_logic := '0';

signal mclk_p, mclk_n				: std_logic;
signal readout						: std_logic := '0';
	
signal lval							: std_logic_vector(1 downto 0);

signal dataclk_p, dataclk_n			: std_logic;
signal seg1_lsb_a_p, seg1_lsb_a_n	: std_logic;
signal seg1_lsb_b_p, seg1_lsb_b_n	: std_logic;
signal seg1_msb_a_p, seg1_msb_a_n	: std_logic;
signal seg1_msb_b_p, seg1_msb_b_n	: std_logic;
signal seg2_lsb_a_p, seg2_lsb_a_n	: std_logic;
signal seg2_lsb_b_p, seg2_lsb_b_n	: std_logic;
signal seg2_msb_a_p, seg2_msb_a_n	: std_logic;
signal seg2_msb_b_p, seg2_msb_b_n	: std_logic;

begin

sim : process
begin
	wait for 50us;
	
	uart_puts("{W000001}", uart_tx, 921600);
 	wait for 10us;
	
	uart_puts("{w100C}", uart_tx, 921600);
 	wait for 10us;
 	
 	uart_puts("{w1009}", uart_tx, 921600);
 	wait for 10us;
			
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

sensor : entity work.orion2k_sim
generic map (
	PIXELS			=> 2128,
	RESOLUTION		=> 11,
	PATTERN			=> x"9CA7"
)
port map (
	MCLKp_I			=> mclk_p,
	MCLKn_I			=> mclk_n,
	RST_I			=> '0',
	
	READOUT_I		=> readout,
	
	CLKp_O			=> dataclk_n,
	CLKn_O			=> dataclk_p,
	
	LVAL_O			=> lval,
		
	SEG1_LSB_Ap_O	=> seg1_lsb_a_n,
	SEG1_LSB_An_O	=> seg1_lsb_a_p,
	
	SEG1_LSB_Bp_O	=> seg1_lsb_b_n,
	SEG1_LSB_Bn_O	=> seg1_lsb_b_p,
	
	SEG1_MSB_Ap_O	=> seg1_msb_a_n,
	SEG1_MSB_An_O	=> seg1_msb_a_p,
	
	SEG1_MSB_Bp_O	=> seg1_msb_b_p,
	SEG1_MSB_Bn_O	=> seg1_msb_b_n,
	
	SEG2_LSB_Ap_O	=> seg2_lsb_a_n,
	SEG2_LSB_An_O	=> seg2_lsb_a_p,
	
	SEG2_LSB_Bp_O	=> seg2_lsb_b_n,
	SEG2_LSB_Bn_O	=> seg2_lsb_b_p,
	
	SEG2_MSB_Ap_O	=> seg2_msb_a_n,
	SEG2_MSB_An_O	=> seg2_msb_a_p,
	
	SEG2_MSB_Bp_O	=> seg2_msb_b_p,
	SEG2_MSB_Bn_O	=> seg2_msb_b_n
);

cam : entity work.camera_orion2k
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
		
	-- Orion2k
	SENS_MCLKp_O	=> mclk_p,
	SENS_MCLKn_O	=> mclk_n,

	SENS_LVAL_I		=> lval,
	
	SENS_DCLKp_I	=> dataclk_p,
	SENS_DCLKn_I	=> dataclk_n,

	SENS_DATAp_I	=> seg2_msb_b_p & seg2_lsb_b_p & seg2_msb_a_p & seg2_lsb_a_p & seg1_msb_b_p & seg1_lsb_b_p & seg1_msb_a_p & seg1_lsb_a_p,
	SENS_DATAn_I	=> seg2_msb_b_n & seg2_lsb_b_n & seg2_msb_a_n & seg2_lsb_a_n & seg1_msb_b_n & seg1_lsb_b_n & seg1_msb_a_n & seg1_lsb_a_n,
	
	SENS_CS_O		=> sens_cs,
	SENS_SCK_O		=> sens_sck,
	SENS_MOSI_O		=> sens_mosi,
	SENS_MISO_I		=> sens_miso,
	
	SENS_UPDATE_O	=> open,
	SENS_RST_LOGIC_O=> open,
	SENS_RST_PLL_O	=> open,
	SENS_RST_SPI_O	=> open,
	
	SENS_READOUT_O	=> readout,
	SENS_ADCONV_O	=> open,
	SENS_SAMPLE_O	=> open,
	SENS_RST_CDS_O	=> open,
	SENS_RST_CVC_O	=> open,
	
	SENS_EXT_SYNC_O	=> open,
	
	-- Misc.
	LED_O			=> open,
	DBG_O			=> open	
);

end Testbench;
