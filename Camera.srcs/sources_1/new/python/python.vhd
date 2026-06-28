library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use work.types.all;

entity python is
Generic (
	MCLK_DIFF		: boolean := false;
	CLOCK_MHZ		: real :=  72.0;	-- MHz
	REFCLK_MHZ		: real := 200.0;	-- MHz
	S				: integer := 10;	-- SERDES Factor
	D				: integer := 4;		-- Input Channels
	IOSTANDARD		: string := "LVDS_18";
	DATA_RATE		: string := "DDR";
	DIFF_TERM		: boolean := false;
	INVERT_CLK		: boolean := false;
	INVERT_DATA 	: std_logic_vector(D-1 downto 0) := (others => '0')
);
Port (
	REFCLK_I		: in  STD_LOGIC;
	RST_I			: in  STD_LOGIC;
	
	MCLK_I			: in  STD_LOGIC; -- Master Clock for Sensor
	MCLK_O			: out STD_LOGIC := '0';	-- 72MHz clock for PLL
	MCLKp_O			: out STD_LOGIC := '0';	-- 360MHz clock for direct clocking without PLL
	MCLKn_O			: out STD_LOGIC := '1';
	
	CLKp_I			: in  STD_LOGIC;		-- 360MHz/288MHz DDR Input Clock
	CLKn_I			: in  STD_LOGIC;
	
	SYNCp_I			: in  STD_LOGIC;
	SYNCn_I			: in  STD_LOGIC;
	
	DATAp_I			: in  STD_LOGIC_VECTOR(3 downto 0);
	DATAn_I			: in  STD_LOGIC_VECTOR(3 downto 0);
	           	
	-- AXI Master
	M_AXIS_ACLK_O	: out STD_LOGIC := '0';
	M_AXIS_TVALID_O	: out STD_LOGIC := '0';
	M_AXIS_TLAST_O	: out STD_LOGIC := '0';
	M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
	M_AXIS_TREADY_I	: in  STD_LOGIC	
);
end python;

architecture Behavioral of python is

signal	refclkint 			: std_logic;
signal	refclkintbufg 		: std_logic;
signal	delay_ready			: std_logic;

begin

refclkint <= REFCLK_I;

bufg_ref : BUFG
port map (
	I	=> refclkint, 
	O	=> refclkintbufg
);
	
icontrol : IDELAYCTRL
port map (
	REFCLK	=> refclkintbufg,
	RST		=> RST_I,
	RDY		=> delay_ready
);

/*
serdes : entity work.serdes_1_to_468_idelay_ddr
generic map (
	S						=> S,				-- Set the serdes factor (4, 6 or 8)
	D						=> D,				-- Number of data lines
	REF_FREQ				=> REFCLK_MHZ,		-- Set idelay control reference frequency
	BITRATE					=> integer(CLOCK_MHZ * 10.0),
	DCD_CORRECT				=> false,			-- enables clock duty cycle correction
	MSB_FIRST				=> true,
	HIGH_PERFORMANCE_MODE	=> "TRUE",
	DATA_FORMAT				=> "PER_CHANL",		-- PER_CLOCK or PER_CHANL data formatting
	IOSTANDARD				=> IOSTANDARD,
	DIFF_TERM				=> DIFF_TERM,
	INVERT_CLK				=> INVERT_CLK,
	RX_SWAP_MASK			=> INVERT_DATA
)
port map (                           
	clkin_p   				=> DATA_CLK_I_P,
	clkin_n   				=> DATA_CLK_I_N,
	datain_p     			=> DATA_I_P,
	datain_n     			=> DATA_I_N,
	enable_phase_detector	=> '0',				-- enable phase detector operation
	enable_monitor			=> '0',				-- enables data eye monitoring
	rxclk    				=> open,
	idelay_rdy				=> delay_ready,
	system_clk				=> PCLK_O,
	system_clk_2x			=> PCLK_2X_O,
	reset     				=> RST_I,
	rx_lckd					=> LOCKED_O,
	bitslip  				=> BITSLIP_I,
	rx_data					=> DATA_O,
	bit_time_value			=> open,
	eye_info				=> open,			-- data eye monitor per line
	m_delay_1hot			=> open,			-- sample point monitor per line
	debug					=> open				-- debug bus
);
*/

end Behavioral;
