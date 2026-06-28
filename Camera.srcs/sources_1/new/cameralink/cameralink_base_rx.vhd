library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use work.types.all;
use work.util.all;

entity cl_base_rx is
	generic (
		CLOCK_MHZ	: real := 80.0; --MHz
		N			: integer := 7;	-- SERDES Factor
		D			: integer := 4;	-- DataLines
		INVERT_CLK	: boolean := FALSE;
		INVERT_DATA	: std_logic_vector(D-1 downto 0) := (others => '0')
	);
	port (
	-- Internal
		REFCLK_I	: IN	STD_LOGIC;
		RST_I		: IN	STD_LOGIC;

	-- Data
		PCLK_O		: OUT	STD_LOGIC := '0';
		DATA_O		: OUT	STD_LOGIC_VECTOR((N*D)-1 downto 0) := (others => '0');
		
	-- Control
		CC_I		: IN	STD_LOGIC_VECTOR( 3 downto 0);	-- Camera Control 1-4
	
	-- Serial
		TX_I		: IN	STD_LOGIC;						-- To Camera
		RX_O		: OUT	STD_LOGIC := '0';				-- To FrameGrabber
	
	-- Bitslip
		DBG_O		: OUT	STD_LOGIC_VECTOR(7 downto 0);
	
-- External
	-- Pixel Lines
		Xp_I		: IN	STD_LOGIC_VECTOR((D-1) downto 0);
		Xn_I		: IN	STD_LOGIC_VECTOR((D-1) downto 0);
		
		XCLKp_I		: IN	STD_LOGIC;
		XCLKn_I		: IN	STD_LOGIC;
		
	-- Control Lines
		CCp_O		: OUT	STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
		CCn_O		: OUT	STD_LOGIC_VECTOR(3 downto 0) := (others => '1');
		
	-- Serial Lines
		SERTFGp_I	: IN	STD_LOGIC;
		SERTFGn_I	: IN	STD_LOGIC;
		SERTCp_O	: OUT	STD_LOGIC := '0';
		SERTCn_O	: OUT	STD_LOGIC := '1'
	);
end cl_base_rx;

architecture RTL of cl_base_rx is

constant CLOCK_PERIOD_CL 		: real := 1000.0 / CLOCK_MHZ;	-- ns

signal	refclkint 				: std_logic;
signal	refclkintbufg 			: std_logic;
--signal	rx_mmcm_lckd			: std_logic;
--signal	rx_mmcm_lckdps			: std_logic;
--signal	rx_mmcm_lckdpsbs		: std_logic_vector(1 downto 0);
signal	rxclk_div				: std_logic;
signal 	rxd						: std_logic_vector((N*D)-1 downto 0);
signal	delay_ready				: std_logic;

attribute clock_signal of PCLK_O : signal is "yes";

begin

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

serdes : entity work.n_x_serdes_1_to_N_mmcm_idelay_sdr
generic map (
	N						=> N,				-- Serdes Factor
	C						=> 1,				-- Number of channels
	D						=> D,				-- Number of data lines
	SAMPL_CLOCK				=> "BUF_G",
	PIXEL_CLOCK				=> "BUF_G",
	USE_PLL					=> FALSE,
 	HIGH_PERFORMANCE_MODE 	=> "TRUE",
    CLKIN_PERIOD			=> CLOCK_PERIOD_CL,	-- Set input clock period
	MMCM_MODE				=> 2,				-- Parameter to set multiplier for MMCM to get VCO in correct operating range. 1 multiplies input clock by 7, 2 multiplies clock by 14, etc
	DIFF_TERM				=> TRUE,
	DATA_FORMAT 			=> "PER_CHANL",		-- PER_CLOCK or PER_CHANL data formatting
	CLK_PATTERN_0			=> "1100011",
	CLK_PATTERN_1			=> "1100001",
	INVERT_CLK				=> INVERT_CLK,
	INVERT_DATA				=> INVERT_DATA
)
port map (                           
	clkin_p(0) 				=> XCLKp_I,
	clkin_n(0) 				=> XCLKn_I,
	datain_p     			=> Xp_I,
	datain_n     			=> Xn_I,
	enable_phase_detector	=> '1',				-- enable phase detector operation
	enable_monitor			=> '0',				-- enables data eye monitoring
	rxclk    				=> open,
	idelay_rdy				=> delay_ready,
	rxclk_div				=> PCLK_O,
	reset     				=> RST_I,
	rx_mmcm_lckd			=> open,	--rx_mmcm_lckd,
	rx_mmcm_lckdps			=> open,	--rx_mmcm_lckdps,
	rx_mmcm_lckdpsbs		=> open,	--rx_mmcm_lckdpsbs,
	clk_data  				=> open,
	rx_data					=> DATA_O,
	bit_rate_value			=> x"0560",			-- required bit rate value in BCD
	bit_time_value			=> open,
	status					=> open,
	eye_info				=> open,			-- data eye monitor per line
	m_delay_1hot			=> open,			-- sample point monitor per line
	debug					=> open
);	

-- CC Lines -------------------------------------------------------------------

control_lines : for i in 0 to 3 generate 
	c_lines : OBUFDS
	generic map (
		IOSTANDARD	=> "LVDS_33"
	)
	port map (
		I	=> CC_I(i),
		O	=> CCp_O(i),
		OB	=> CCn_O(i)
	);
end generate;

-- Serial ---------------------------------------------------------------------

ser_tx : OBUFDS
	generic map (
		IOSTANDARD => "LVDS_33"
	)
	port map (
		I	=> TX_I,
		O	=> SERTCp_O,
		OB	=> SERTCn_O
	);
	
ser_rx : IBUFDS
	generic map (
		IOSTANDARD	=> "LVDS_33",
		DIFF_TERM	=> TRUE
	)
	port map (
		O	=> RX_O,
		I	=> SERTFGp_I,
		IB	=> SERTFGn_I
	);

end RTL;

