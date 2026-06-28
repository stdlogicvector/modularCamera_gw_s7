library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;

entity orion2k is
generic (
	CLOCK_MHZ		: real :=  40.0; -- MHz
	REFCLK_MHZ		: real := 200.0; -- MHz
	N				: integer := 8;	-- SERDES Factor
	S				: integer := 2;	-- Segments
	D				: integer := 4;	-- Input Number per Segment
	DATA_RATE		: string := "DDR";
	IOSTANDARD		: string := "LVDS_25";
	DIFF_TERM		: boolean := false;
	EXT_CLK			: boolean := true;
	INVERT_CLK		: boolean := false;
	INVERT_DATA		: std_logic_vector(S*D-1 downto 0) := (others => '0')	
);
Port (
	MCLK_I			: in STD_LOGIC;	-- 80MHz
	RST_I			: in STD_LOGIC;
	
	REFCLK_I		: in STD_LOGIC;	-- 200MHz
	
	-- Sensor
	MCLK_O_P		: out STD_LOGIC;	-- Master Clock to Sensor
	MCLK_O_N		: out STD_LOGIC;

	LVAL_I			: in STD_LOGIC_VECTOR((S-1) downto 0);
	
	DATA_CLK_I_P	: in STD_LOGIC;	-- DDR Data Clock from Sensor
	DATA_CLK_I_N	: in STD_LOGIC;

	DATA_I_P		: in STD_LOGIC_VECTOR(((S*D)-1) downto 0);		-- SEG 1/2: A/B MSB, A/B LSB
	DATA_I_N		: in STD_LOGIC_VECTOR(((S*D)-1) downto 0);

	BITSLIP_EN_I	: in STD_LOGIC;
	PATTERN_I		: in STD_LOGIC_VECTOR(15 downto 0);

	-- Timing	
	ENABLE_I		: in STD_LOGIC;
	TRIGGER_I		: in STD_LOGIC;
	
	INTEGRATING_O	: out STD_LOGIC;
	END_OF_LINE_O	: out STD_LOGIC;
	
	INT_CLKS_I		: in STD_LOGIC_VECTOR(15 downto 0);				-- Insert Integration Time Clocks
 	DELAY_CLKS_I	: in STD_LOGIC_VECTOR(15 downto 0);				-- Insert Delay Clocks to change Linerate
	LINES_I			: in STD_LOGIC_VECTOR(15 downto 0) := x"0400";	-- Lines per Frame
	
	RST_CVC_O		: out STD_LOGIC;
	RST_CDS_O		: out STD_LOGIC;
	SAMPLE_O		: out STD_LOGIC;
	START_ADC_O		: out STD_LOGIC;
	START_READOUT_O	: out STD_LOGIC;
	
	-- AXI Master
	M_AXIS_ACLK_O	: out STD_LOGIC;
	M_AXIS_TVALID_O	: out STD_LOGIC;
	M_AXIS_TLAST_O	: out STD_LOGIC;
	M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(31 downto 0);
	M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR(1 downto 0);
	M_AXIS_TREADY_I	: in  STD_LOGIC
	
	-- Debug
	;RX_LOCKED_O	: out STD_LOGIC
);
end orion2k;

architecture Behavioral of orion2k is

signal rx_clk		: std_logic;
signal rx_clk_2x	: std_logic;
signal rx_locked	: std_logic;
signal rx_bitslip	: std_logic_vector((S*D-1) downto 0);
signal rx_lval		: std_logic_vector((S-1) downto 0);
signal rx_data		: std_logic_vector(((S*D*N)-1) downto 0) := (others => '0');

constant LVAL_DLY	: integer := 10;

type lval_array	is array(0 to S-1) of std_logic_vector(LVAL_DLY-1 downto 0);
signal lval 		: lval_array := (others => (others => '0'));

type state_t is (STORE, NEXT_LINE, WAIT_FOR_EOL);
signal state : state_t := STORE;

signal segment		: std_logic := '0';
signal line  		: std_logic_vector(15 downto 0) := (others => '0');	
signal pixel		: array16_t(0 to 3) := (others => (others => '0'));

begin

data : entity work.orion2k_data
generic map (
	CLOCK_MHZ		=> CLOCK_MHZ * 2.0,
	REFCLK_MHZ		=> REFCLK_MHZ,
	N				=> N,
	S				=> S,
	D				=> D,
	DATA_RATE		=> DATA_RATE,
	IOSTANDARD		=> IOSTANDARD,
	EXT_CLK			=> EXT_CLK,
	INVERT_CLK		=> INVERT_CLK,
	INVERT_DATA 	=> INVERT_DATA	
)
port map (
	MCLK_I			=> MCLK_I,
	REFCLK_I		=> REFCLK_I,
	RST_I			=> RST_I,

	PCLK_O			=> rx_clk,		-- = MCLK / 2
	PCLK_2X_O		=> rx_clk_2x,	-- = MCLK
	LVAL_O			=> rx_lval,
	DATA_O			=> rx_data,
		
	MCLK_O_N		=> MCLK_O_N,
	MCLK_O_P		=> MCLK_O_P,
	
	LOCKED_O		=> rx_locked,
	BITSLIP_I		=> rx_bitslip,	

	LVAL_I			=> LVAL_I,
	
	DATA_CLK_I_P	=> DATA_CLK_I_P,
	DATA_CLK_I_N	=> DATA_CLK_I_N,
	
	DATA_I_N		=> DATA_I_N,
	DATA_I_P		=> DATA_I_P
);

RX_LOCKED_O <= rx_locked;

ila : entity work.ila_0
port map (
	clk			=> rx_clk,
	probe0		=> rx_bitslip(1 downto 0),
	probe1		=> rx_data(15 downto 0),
	probe2		=> rx_data(31 downto 16)
);

align : entity work.orion2k_bitslip
generic map (
	W				=> N,
	S				=> S,
	D				=> D
)
port map (
	DATA_CLK_I		=> rx_clk,
	RST_I			=> RST_I,
	
	ENABLE_I		=> BITSLIP_EN_I and rx_locked,
	PATTERN_I		=> PATTERN_I,
	BITSLIP_I		=> (others => '0'),
	
	LVAL_I			=> rx_lval,
	DATA_I			=> rx_data,
	
	BITSLIP_O		=> rx_bitslip
);

timing : entity work.orion2k_timing
generic map (
	CLOCK_MHZ		=> CLOCK_MHZ
)
port map (
	CLK_I			=> MCLK_I,
	RST_I			=> RST_I,
	
	ENABLE_I		=> ENABLE_I,
	TRIGGER_I		=> TRIGGER_I,
	
	INTEGRATING_O	=> INTEGRATING_O,
	END_OF_LINE_O	=> END_OF_LINE_O,
	
	INT_CLKS_I		=> INT_CLKS_I,
	DELAY_CLKS_I	=> DELAY_CLKS_I,
	
	RST_CVC_O		=> RST_CVC_O,
	RST_CDS_O		=> RST_CDS_O,
	SAMPLE_O		=> SAMPLE_O,
	START_ADC_O		=> START_ADC_O,
	START_READOUT_O	=> START_READOUT_O
);

pixel(0) <= "000" & rx_data(14 downto  9) & rx_data( 7 downto  1);
pixel(1) <= "000" & rx_data(30 downto 25) & rx_data(23 downto 17);

pixel(2) <= "000" & rx_data(46 downto 41) & rx_data(39 downto 33);
pixel(3) <= "000" & rx_data(62 downto 57) & rx_data(55 downto 49);
	
M_AXIS_ACLK_O <= rx_clk_2x;

process(rx_clk_2x)
begin
	if rising_edge(rx_clk_2x) then
		segment <= not segment;
		
		for i in 0 to S-1 loop
			lval(i) <= lval(i)(lval(i)'high-1 downto 0) & rx_lval(i);
		end loop;
		
		if segment = '0' then
			M_AXIS_TDATA_O <= pixel(1) & pixel(0);
		else
			M_AXIS_TDATA_O <= pixel(3) & pixel(2);
		end if;
		
	end if;
end process;
	
end Behavioral;
