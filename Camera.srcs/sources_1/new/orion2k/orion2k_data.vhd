library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use UNISIM.VComponents.all;
use Work.util.all;

entity orion2k_data is
	generic (
		CLOCK_MHZ		: real :=  80.0; -- MHz
		REFCLK_MHZ		: real := 200.0; -- MHz
		N				: integer := 8;	-- SERDES Factor
		S				: integer := 2;	-- Segments
		D				: integer := 4;	-- Input Number per Segment
		IOSTANDARD		: string := "LVDS_25";
		DATA_RATE		: string := "DDR";
		DIFF_TERM		: boolean := false;
		EXT_CLK			: boolean := true;
		INVERT_CLK		: boolean := false;
		INVERT_DATA 	: std_logic_vector(S*D-1 downto 0) := (others => '0')	
	);
	port (
		-- Internal
		MCLK_I			: IN	STD_LOGIC;
		REFCLK_I		: IN	STD_LOGIC;
		RST_I			: IN	STD_LOGIC;

		PCLK_O			: OUT 	STD_LOGIC;
		PCLK_2X_O		: OUT 	STD_LOGIC;
		DATA_O			: OUT	STD_LOGIC_VECTOR(((S*D*N)-1) downto 0);
		LVAL_O			: OUT	STD_LOGIC_VECTOR((S-1) downto 0);
		
		LOCKED_O		: OUT	STD_LOGIC;
		BITSLIP_I		: IN	STD_LOGIC_VECTOR(((S*D)-1) downto 0);

		-- Sensor
		MCLK_O_P		: OUT	STD_LOGIC;	-- Master Clock to Sensor
		MCLK_O_N		: OUT	STD_LOGIC;

		LVAL_I			: IN	STD_LOGIC_VECTOR((S-1) downto 0);
		
		DATA_CLK_I_P	: IN	STD_LOGIC;	-- DDR Data Clock from Sensor
		DATA_CLK_I_N	: IN	STD_LOGIC;

		DATA_I_P		: IN	STD_LOGIC_VECTOR(((S*D)-1) downto 0);		-- SEG 1/2: A/B MSB, A/B LSB
		DATA_I_N		: IN	STD_LOGIC_VECTOR(((S*D)-1) downto 0)
	);
end orion2k_data;

architecture RTL of orion2k_data is

constant CLOCK_PERIOD		: real := 1000.0 / CLOCK_MHZ;	-- ns

signal	refclkint 			: std_logic;
signal	refclkintbufg 		: std_logic;
signal	delay_ready			: std_logic;

signal 	mclk				: std_logic;

type data_array is array(((S*D)-1) downto 0) of std_logic_vector(N-1 downto 0);
signal data : data_array := (others => (others => '0'));

begin

mclk_oddr_p : ODDR
generic map (
	DDR_CLK_EDGE	=> "OPPOSITE_EDGE",
	INIT 			=> '0',
	SRTYPE 			=> "SYNC"
)
port map (
	D1	=> '0',
	D2	=> '1',
	C	=> MCLK_I,
	CE	=> '1',
	R	=> '0',
	S	=> '0',
	Q	=> mclk
);

mclk_obufds : OBUFDS
generic map (
	IOSTANDARD 	=> IOSTANDARD
)
port map (
	I	=> mclk,
	O	=> MCLK_O_P,
	OB	=> MCLK_O_N
);

serdes : entity work.orion2k_serdes
generic map (
	S						=> N,				-- Set the serdes factor (4, 6 or 8)
	D						=> S*D,				-- Number of data lines
	REF_FREQ				=> REFCLK_MHZ,		-- IDELAYCTRL reference frequency
	MSB_FIRST				=> true,
	HIGH_PERFORMANCE_MODE	=> "TRUE",
	DATA_FORMAT				=> "PER_CHANL",		-- PER_CLOCK or PER_CHANL
	DATA_RATE				=> DATA_RATE,
	IOSTANDARD				=> IOSTANDARD,
	DIFF_TERM				=> DIFF_TERM,
	EXT_CLK					=> EXT_CLK,
	INVERT_CLK				=> INVERT_CLK,
	INVERT_DATA				=> INVERT_DATA
)
port map (
	REFCLK_I				=> REFCLK_I,
	RST_I					=> RST_I,
	
	CLKp_I					=> DATA_CLK_I_P,
	CLKn_I					=> DATA_CLK_I_N,
	DATAp_I					=> DATA_I_P,
	DATAn_I					=> DATA_I_N,
	
	BITSLIP_I				=> BITSLIP_I,
	SYSCLK_O				=> PCLK_O,
	SYSCLKx2_O				=> PCLK_2X_O,
	LOCKED_O				=> LOCKED_O,
	DATA_O					=> DATA_O
);

/*
--iob_in : IBUF
--port map (
--	I	=> REFCLK_I,
--	O	=> refclkint
--);

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

serdes : entity work.serdes_1_to_468_idelay_ddr
generic map (
	S						=> N,				-- Set the serdes factor (4, 6 or 8)
	D						=> S*D,				-- Number of data lines
	REF_FREQ				=> REFCLK_MHZ,		-- Set idelay control reference frequency
	BITRATE					=> integer(CLOCK_MHZ * 4.0),
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

LVAL_O	<= LVAL_I when LOCKED_O = '1' else (others => '0');

--lval_seg : for l in 0 to (S-1) generate			-- Distribute Segment Valid signals to data channels
--	lval : for i in 0 to (D-1) generate
--		LVAL_O(l*D + i) <= LVAL_I(l);
--	end generate lval;
--end generate lval_seg;

end RTL;
