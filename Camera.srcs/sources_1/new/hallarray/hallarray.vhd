library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use work.util.all;

entity hallarray is
Generic (
	CLK_MHZ			: real := 100.0;
	RESOLUTION_US	: real := 1.0;
	ROWS			: natural := 8;
	COLS			: natural := 8
);
Port (
	RST_I			: in  STD_LOGIC;
	CLK_I			: in  STD_LOGIC;
	
	ENABLE_I		: in  STD_LOGIC;
	TRIGGER_I		: in  STD_LOGIC;
	SETTLING_I		: in  STD_LOGIC_VECTOR(15 downto 0);
	
	nENABLE_O		: out STD_LOGIC := '1';
	COL_O			: out STD_LOGIC_VECTOR(clogb2(COLS)-1 downto 0) := (others => '0');
	ROW_O			: out STD_LOGIC_VECTOR(clogb2(ROWS)-1 downto 0) := (others => '0');
	
	nCS_O			: out STD_LOGIC := '1';
	SCK_O			: out STD_LOGIC := '0';
	SDO_I			: in  STD_LOGIC;
	
	-- AXI Master
	M_AXIS_ACLK_O	: out STD_LOGIC := '0';
	M_AXIS_TVALID_O	: out STD_LOGIC := '0';
	M_AXIS_TLAST_O	: out STD_LOGIC := '0';
	M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
	M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
	M_AXIS_TREADY_I	: in  STD_LOGIC	
);
end hallarray;

architecture Behavioral of hallarray is

constant CLK_PERIOD	: real := 1000.0 / CLK_MHZ;
constant PRESCALE	: integer := integer(RESOLUTION_US * 1000.0 / CLK_PERIOD);

signal prescaler	: integer range 0 to PRESCALE-1 := 0;
signal strobe		: std_logic := '0';

signal pause		: std_logic_vector(15 downto 0) := (others => '0');

type state_t 		is (S_IDLE, S_PAUSE, S_SAMPLE, S_ROW);
signal state		: state_t := S_IDLE;

signal row			: integer range 0 to ROWS-1 := 0;
signal col			: integer range 0 to COLS-1 := 0;

signal sample		: std_logic := '0';

signal counter		: integer range 0 to 1 := 0;

signal dv			: std_logic;
signal data			: std_logic_vector(11 downto 0);

signal row_map		: integer_vector(0 to 7) := (2, 1, 0, 3, 4, 6, 7, 5);
signal col_map		: integer_vector(0 to 7) := (7, 6, 5, 4, 3, 2, 1, 0); 

begin

-- South Pole : Positive -> Higher Output
-- No Field   : Half Scale
-- North Pole : Negative -> Lower Output


ROW_O <= int2vec(row_map(row), ROW_O'length);
COL_O <= int2vec(col_map(col), COL_O'length);

scan : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if prescaler = PRESCALE-1 then
			prescaler	<= 0;
			strobe		<= '1';
		else
			prescaler	<= prescaler + 1;
			strobe		<= '0';
		end if;
		
		sample 			  <= '0';
		M_AXIS_TVALID_O	  <= '0';
		M_AXIS_TLAST_O 	  <= '0';
		M_AXIS_TUSER_O(0) <= '0';
		M_AXIS_TUSER_O(1) <= '0';
		M_AXIS_TDATA_O    <= data;
		
		case state is
		when S_IDLE =>
			nENABLE_O <= '1';
			row <= 0;
			col <= 0;
			
			if ENABLE_I = '1' and TRIGGER_I = '1' and M_AXIS_TREADY_I = '1' then
				prescaler	<= 0;
				nENABLE_O 	<= '0';
				state 		<= S_PAUSE;
			end if;

		when S_PAUSE =>
			if pause >= SETTLING_I then
				sample <= '1';
				pause <= (others => '0');
				
				state <= S_SAMPLE;
			elsif strobe = '1' then
				pause <= inc(pause);
			end if;
						
		when S_SAMPLE =>
			if dv = '1' then
				if counter = 1 then
					counter <= 0;
					state <= S_ROW;
				else
					sample <= '1';
					counter <= counter + 1;
				end if;
			end if;
		
		when S_ROW =>
			state	<= S_PAUSE;
			
			if col = 0 and row = 0 then
				M_AXIS_TUSER_O(0) <= '1';	-- Start of Frame
			end if;
			
			if row = ROWS-1 then
				M_AXIS_TLAST_O <= '1';		-- End of Line
				
				row <= 0;
				col <= col + 1;
			else
				row	<= row + 1;
			end if;
			
			if row = ROWS-1 and col = COLS-1 then
				col <= 0;
				M_AXIS_TUSER_O(1) <= '1';	-- End of Frame
				state <= S_IDLE;
			end if;
		
			M_AXIS_TVALID_O <= '1';
				
		end case;
	end if;
end process;

adc : entity work.LTC2315
port map (
	CLK_I		=> CLK_I,
	RST_I		=> RST_I,
		
	CS_O		=> nCS_O,
	SCK_O		=> SCK_O,
	SDO_I		=> SDO_I,
	
	SAMPLE_I 	=> sample,
	
	DV_O 		=> dv,
	DATA_O 		=> data		
);

M_AXIS_ACLK_O		<= CLK_I;

end Behavioral;
