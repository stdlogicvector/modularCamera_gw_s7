library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity image_gen is
Generic (
	CLK_MHZ			: real := 100.0;
	RESOLUTION_US	: integer := 1;
	PIXEL_WIDTH		: integer := 8;
	PIXEL_CHANNELS	: integer := 4
);
Port (
	CLK_I			: in STD_LOGIC;
	RST_I			: in STD_LOGIC;

	TRIGGER_I		: in STD_LOGIC;
	
	WIDTH_I			: in STD_LOGIC_VECTOR(15 downto 0);
	HEIGHT_I		: in STD_LOGIC_VECTOR(15 downto 0);
	
	HBLANK_I		: in STD_LOGIC_VECTOR(15 downto 0);
	
	MODE_I			: in STD_LOGIC_VECTOR(2 downto 0);
	PATTERN_I		: in STD_LOGIC_VECTOR(15 downto 0);
	
	-- AXI Master
	M_AXIS_ACLOCK_O	: out STD_LOGIC;
	M_AXIS_TVALID_O	: out STD_LOGIC;
	M_AXIS_TLAST_O	: out STD_LOGIC;
	M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(PIXEL_WIDTH*PIXEL_CHANNELS-1 downto 0);
	M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR(1 downto 0);
	M_AXIS_TREADY_I	: in  STD_LOGIC	
);
end image_gen;

architecture Behavioral of image_gen is

constant CH_WIDTH	: integer := clogb2(PIXEL_CHANNELS);

constant CLK_PERIOD	: real := 1000.0 / CLK_MHZ;
constant PRESCALE	: integer := integer(real(RESOLUTION_US) * 1000.0 / CLK_PERIOD);

signal prescaler	: integer range 0 to PRESCALE-1 := 0;
signal strobe		: std_logic := '0';
signal hblank		: std_logic_vector(15 downto 0) := (others => '0');

signal height		: std_logic_vector(15 downto 0) := (others => '0');
signal width		: std_logic_vector(15 downto 0) := (others => '0');

signal col			: std_logic_vector(15 downto 0) := (others => '0');
signal row			: std_logic_vector(15 downto 0) := (others => '0');
signal cnt			: std_logic_vector(15 downto 0) := (others => '0');

signal mode			: std_logic_vector( 2 downto 0) := (others => '0');
signal frame		: std_logic_vector(15 downto 0) := (others => '0');
signal test			: std_logic_vector(15 downto 0) := (others => '0');
signal pattern		: std_logic_vector(15 downto 0) := (others => '0');

signal data			: std_logic_vector(PIXEL_WIDTH*PIXEL_CHANNELS-1 downto 0):= (others => '0');

signal first		: std_logic := '0';

type state_t is (S_IDLE, S_DATA, S_EOL, S_EOF, S_HBLANK);
signal state		: state_t := S_IDLE;

begin

M_AXIS_ACLOCK_O <= CLK_I;
M_AXIS_TDATA_O	<= data;

process(CLK_I)
begin
	if rising_edge(CLK_I) then
	
		M_AXIS_TVALID_O 	<= '0';
		M_AXIS_TLAST_O		<= '0';
		M_AXIS_TUSER_O(0)	<= '0';
		M_AXIS_TUSER_O(1)	<= '0';
		
		case mode is
		when "000" => -- Horizontal Gradient
			for c in 0 to PIXEL_CHANNELS-1 loop
				data((c+1)*PIXEL_WIDTH-1 downto c*PIXEL_WIDTH) <= col(PIXEL_WIDTH-CH_WIDTH-1 downto 0) & int2vec(c, CH_WIDTH);
			end loop;
			
		when "001" => -- Vertical Gradient
			for c in 0 to PIXEL_CHANNELS-1 loop
				data((c+1)*PIXEL_WIDTH-1 downto c*PIXEL_WIDTH) <= row(PIXEL_WIDTH-1 downto 0);
			end loop;
		
		when "010" =>
			for c in 0 to PIXEL_CHANNELS-1 loop
				data((c+1)*PIXEL_WIDTH-1 downto c*PIXEL_WIDTH) <= test(PIXEL_WIDTH-CH_WIDTH-1 downto 0) & int2vec(c, CH_WIDTH);
			end loop;
		
		when "011" =>
			for c in 0 to PIXEL_CHANNELS-1 loop
				data((c+1)*PIXEL_WIDTH-1 downto c*PIXEL_WIDTH) <= pattern(PIXEL_WIDTH-1 downto 0);
			end loop;
			
		when "100" =>
			if or_reduce(col) = '0' then
				data <= (PIXEL_WIDTH-1 downto 0 => '1', others => '0');
			elsif col >= width then
				data <= (PIXEL_CHANNELS*PIXEL_WIDTH-1 downto (PIXEL_CHANNELS-1)*PIXEL_WIDTH => '1', others => '0');
			else
				data <= (others => '0');
			end if;
		
		when "101" =>
			if or_reduce(row) = '0' then
				data <= (others => '1');
			elsif row >= height then
				data <= (others => '1');
			else
				data <= (others => '0');
			end if;
		
		when "110" =>
			if (row(3) XOR col(4-PIXEL_CHANNELS)) = '1' then
				data <= (others => '1');
			else
				data <= (others => '0');
			end if;
		
		when "111" =>
			for i in 1 to PIXEL_CHANNELS loop
				data(i*PIXEL_WIDTH-1 downto (i-1)*PIXEL_WIDTH) <= (others => frame(i));
			end loop;			
						
		when others =>
			data <= (others => '0');
		end case;
	
		width	<= dec(WIDTH_I);
		height	<= dec(HEIGHT_I);
		hblank	<= dec(HBLANK_I);
	
		case state is
		when S_IDLE =>
			if TRIGGER_I = '1' then
				first 	<= '1';
				state 	<= S_DATA;
				pattern <= PATTERN_I;
				mode	<= MODE_I;
			end if;
			
		when S_DATA =>
			M_AXIS_TVALID_O 	<= '1';
			M_AXIS_TUSER_O(0)	<= first;
			
			first <= '0';
			
			test	<= inc(test);
			pattern <= pattern(14 downto 0) & pattern(15);
					
			if col >= width then
				M_AXIS_TLAST_O		<= '1';
				col					<= (others => '0');
				row					<= inc(row);
				
				if row >= height then
					M_AXIS_TUSER_O(1)	<= '1';
					state				<= S_EOF;
				else
					state				<= S_EOL;
				end if;
			else
				col <= inc(col);
			end if;
		
		when S_EOL =>
			if HBLANK_I = x"0000" then
				state <= S_DATA;
			else
				state <= S_HBLANK;
			end if;
		
		when S_EOF =>
			row	  <= (others => '0');
			frame <= inc(frame);
			state <= S_IDLE;
		
		when S_HBLANK =>
			if prescaler = PRESCALE-1 then
				prescaler	<= 0;
				strobe		<= '1';
			else
				prescaler	<= prescaler + 1;
				strobe		<= '0';
			end if;
		
			if strobe = '1' then
				if cnt >= hblank then
					cnt				<= (others => '0');
					state			<= S_DATA;
				else
					cnt <= inc(cnt);
				end if;
			end if;
		
		end case;
	end if;
end process;

end Behavioral;
