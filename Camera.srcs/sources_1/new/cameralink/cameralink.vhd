library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cameralink is
Generic (
	CLOCK_MHZ		: real := 80.0; --MHz
	USED_BITS		: integer := 16;
	N				: integer := 7;	-- SERDES Factor
	D				: integer := 4;	-- Data Lines
	INVERT_CLK		: boolean := FALSE;
	INVERT_DATA 	: std_logic_vector(D-1 downto 0) := (others => '0')	
);
Port (
	-- Pixel Lines
	Xp_I			: IN	STD_LOGIC_VECTOR((D-1) downto 0);
	Xn_I			: IN	STD_LOGIC_VECTOR((D-1) downto 0);
	
	XCLKp_I			: IN	STD_LOGIC;
	XCLKn_I			: IN	STD_LOGIC;
	
	-- Control Lines
	CCp_O			: OUT	STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
	CCn_O			: OUT	STD_LOGIC_VECTOR(3 downto 0) := (others => '1');
	
	-- Serial Lines
	SERTFGp_I		: IN	STD_LOGIC;
	SERTFGn_I		: IN	STD_LOGIC;
	SERTCp_O		: OUT	STD_LOGIC := '0';
	SERTCn_O		: OUT	STD_LOGIC := '1';
	
	-- Internal
	REFCLK_I		: IN	STD_LOGIC;
	RST_I			: IN	STD_LOGIC;
	
	-- Control
	CC_I			: IN	STD_LOGIC_VECTOR( 3 downto 0);	-- Camera Control 1-4

	-- Serial
	TX_I			: IN	STD_LOGIC;						-- To Camera
	RX_O			: OUT	STD_LOGIC := '0';				-- To FrameGrabber

	-- Debug
	DBG_O			: OUT	STD_LOGIC_VECTOR(7 downto 0);

	-- AXI Master
	M_AXIS_ACLK_O	: out	STD_LOGIC;
	M_AXIS_TVALID_O	: out	STD_LOGIC;
	M_AXIS_TLAST_O	: out	STD_LOGIC;
	M_AXIS_TDATA_O	: out	STD_LOGIC_VECTOR(USED_BITS-1 downto 0);
	M_AXIS_TUSER_O	: out	STD_LOGIC_VECTOR(1 downto 0);
	M_AXIS_TREADY_I	: in 	STD_LOGIC	
);
end cameralink;

architecture Behavioral of cameralink is

signal rx_clk				: std_logic;

signal rx_dval				: std_logic;
signal rx_lval				: std_logic;
signal rx_fval				: std_logic;
signal rx_spare				: std_logic;

signal rx_data				: std_logic_vector((N*D)-1 downto 0) := (others => '0');

signal rx_data_mapped		: std_logic_vector((N*D - 4)-1 downto 0) := (others => '0');
signal rx_data_unused		: std_logic_vector(79 downto rx_data_mapped'high+1);

signal ready				: std_logic := '0';
signal in_frame				: std_logic := '0';
signal last_dval			: std_logic := '0';

begin

rx : entity work.cl_base_rx
generic map (
	CLOCK_MHZ		=> CLOCK_MHZ,
	N				=> N,
	D				=> D,
	INVERT_DATA		=> INVERT_DATA,
	INVERT_CLK		=> INVERT_CLK
)
port map (
	REFCLK_I		=> REFCLK_I,
	RST_I			=> RST_I,
	
	PCLK_O			=> rx_clk,
	DATA_O			=> rx_data,
	
	CC_I			=> CC_I,
	TX_I			=> TX_I,
	RX_O			=> RX_O,
	
	Xp_I			=> Xp_I,
	Xn_I			=> Xn_I,
	XCLKp_I			=> XCLKp_I,
	XCLKn_I			=> XCLKn_I,
	
	CCp_O			=> CCp_O,
	CCn_O			=> CCn_O,
	
	SERTFGp_I		=> SERTFGp_I,
	SERTFGn_I		=> SERTFGn_I,
	
	SERTCp_O		=> SERTCp_O,
	SERTCn_O		=> SERTCn_O
);
/*
ila : entity work.ila_0
port map (
	clk 	=> rx_clk,
	probe0	=> rx_data(27 downto 0)
);
*/
-- TODO: Invert Mask for CC lines

cl_bitmap : entity work.bitmap_cl_rx
port map (
	CLK_I			=> rx_clk,
	
	DATA_I(rx_data'high downto 0) 		 	=> rx_data,
	DATA_I(83 downto rx_data'high+1)	 	=> (others => '0'),
	
	FVAL_O			=> rx_fval,
	LVAL_O			=> rx_lval,
	DVAL_O			=> rx_dval,
	SPARE_O			=> rx_spare,
	
	DATA_O(rx_data_mapped'high downto 0) 	=> rx_data_mapped,
	DATA_O(79 downto rx_data_mapped'high+1)	=> rx_data_unused
);

M_AXIS_ACLK_O 	<= rx_clk;
M_AXIS_TLAST_O	<= last_dval and not rx_dval;	-- End of Line

process(rx_clk)
begin
	if rising_edge(rx_clk) then
		M_AXIS_TDATA_O		<= rx_data_mapped(USED_BITS-1 downto 0);
		
		M_AXIS_TUSER_O(0)	<= rx_dval and not in_frame;		-- Start of Frame	
		M_AXIS_TUSER_O(1)	<= not rx_dval and in_frame;		-- End of Frame (TODO!!!!!!!!!!!!!!!!!!!)	
		
		if rx_fval = '1' then
			if rx_dval = '1' then
				in_frame		<= '1';
				M_AXIS_TVALID_O <= ready;
			else
				M_AXIS_TVALID_O <= '0';
			end if;
		else
			in_frame		<= '0';
			ready 			<= M_AXIS_TREADY_I;
			M_AXIS_TVALID_O <= '0';
		end if;
		
		last_dval <= rx_dval;
	end if;
end process;

end Behavioral;
