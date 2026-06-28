library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use Work.util.all;

entity ilx506 is
	Generic (
		CLK_MHZ			: real := 100.0;
		FREQ_MHZ		: real range 1.0 to 12.5 := 3.0
	);
	Port (
		CLK_I		: in  STD_LOGIC;
		RST_I		: in  STD_LOGIC;
		
		ROG_O		: out STD_LOGIC := '0';
		CLK_O		: out STD_LOGIC := '1';
		RS_O		: out STD_LOGIC := '1';
		
		SAMPLE_O	: out STD_LOGIC := '0';

		SOL_O		: out STD_LOGIC := '0';		
		EOL_O		: out STD_LOGIC := '0';
		EXPOSING_O	: out STD_LOGIC := '0';
		
		TRIGGER_I	: in  STD_LOGIC
	);
end ilx506;

architecture Behavioral of ilx506 is

constant RESOLUTION		: real := 1000.0 / CLK_MHZ;	-- External Clock Period in ns

constant PIXELS 		: integer := 5034;
constant BLANK_PRE		: integer := 28;
constant BLANK_POST		: integer := 6;

constant PRE_ROG		: real := 200.0;			-- CLK rising to ROG falling
constant ROG_PULSE		: real := 1000.0;			-- ROG rising to ROG falling
constant POST_ROG		: real := 1000.0;			-- ROG falling to CLK falling
constant PRE_RS			: real := 50.0; 			-- CLK falling to RS falling
constant RS_PULSE		: real := 25.0;				-- RS falling to RS rising
constant SAMPLE_DLY		: real := 100.0;
constant CLK_PERIOD		: real := 500.0 / FREQ_MHZ;	-- CLK rising to CLK rising

constant PRE_ROG_CY		: integer := integer(ceil(PRE_ROG 	/ RESOLUTION)) - 1;
constant ROG_PULSE_CY	: integer := integer(ceil(ROG_PULSE / RESOLUTION)) - 1;
constant POST_ROG_CY	: integer := integer(ceil(POST_ROG 	/ RESOLUTION)) - 1;
constant PRE_RS_CY		: integer := integer(ceil(PRE_RS 	/ RESOLUTION)) - 1;
constant RS_PULSE_CY	: integer := integer(ceil(RS_PULSE 	/ RESOLUTION)) - 1;
constant SAMPLE_DLY_CY	: integer := integer(ceil(SAMPLE_DLY / RESOLUTION)) - 1;
constant CLK_PERIOD_CY	: integer := integer(ceil(CLK_PERIOD / RESOLUTION)) - 1;
constant POST_RS_CY		: integer := integer(ceil((CLK_PERIOD-PRE_RS-RS_PULSE) / RESOLUTION)) - 1;

type c_state_t			is (S_ROG_PRE, S_ROG, S_ROG_POST, S_CLK_HIGH, S_RS_PRE, S_RS, S_RS_POST);
signal c_state			: c_state_t := S_CLK_HIGH;

signal pixel			: integer range 0 to PIXELS-1 := 0;
signal counter			: integer range 0 to ROG_PULSE_CY := 0;
signal sample			: std_logic := '0';

signal trigger			: std_logic := '0';
signal data				: std_logic := '0';

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if RST_I = '1' then
			c_state		<= S_CLK_HIGH;
		else				
			SOL_O		<= '0';
			EOL_O		<= '0';
			SAMPLE_O	<= '0';
				
			if TRIGGER_I = '1' then
				trigger <= '1';
			end if;
			
			if sample = '1' then
				if pixel = PIXELS-1 then
					pixel <= 0;
					data <= '0';
					trigger <= '0';
				else
					pixel <= pixel + 1;
				end if;
				
				if pixel > BLANK_PRE-1
				and pixel < PIXELS-BLANK_POST
				then
					SAMPLE_O <= '1';
				end if;
				
				if pixel = PIXELS-BLANK_POST-1 then
					EOL_O		<= '1';
				end if;
			end if;
			
			case c_state is
			when S_ROG_PRE =>
				ROG_O	<= '0';
				CLK_O	<= '1';
				RS_O	<= '1';
				
				EXPOSING_O 	<= '0';
				
				if counter = PRE_ROG_CY then
					counter <= 0;
					c_state <= S_ROG;
				else
					counter <= counter + 1;
				end if;
				
			when S_ROG =>
				ROG_O	<= '1';
				CLK_O	<= '1';
				RS_O	<= '1';
				
				if counter = ROG_PULSE_CY then
					counter <= 0;
					c_state <= S_ROG_POST;
				else
					counter <= counter + 1;
				end if;
			
			when S_ROG_POST =>
				ROG_O	<= '0';
				CLK_O	<= '1';
				RS_O	<= '1';
				
				EXPOSING_O 	<= '1';
				
				if counter = POST_ROG_CY then
					counter <= 0;
					c_state <= S_RS_PRE;
					SOL_O	<= '1';
					data 	<= '1';
				else
					counter <= counter + 1;
				end if;
			
			when S_CLK_HIGH =>
				ROG_O	<= '0';
				CLK_O	<= '1';
				RS_O	<= '1';
				
				if data = '1' and counter = SAMPLE_DLY_CY then
					sample <= '1';
				else
					sample <= '0';
				end if;
				
				if counter = CLK_PERIOD_CY then
					counter <= 0;
					c_state <= S_RS_PRE;
				else
					counter <= counter + 1;
				end if;
				
			when S_RS_PRE =>
				ROG_O	<= '0';
				CLK_O	<= '0';
				RS_O	<= '1';
				
				if counter = PRE_RS_CY then
					counter <= 0;
					c_state <= S_RS;
				else
					counter <= counter + 1;
				end if;
			
			when S_RS =>
				ROG_O	<= '0';
				CLK_O	<= '0';
				RS_O	<= '0';
				
				if counter = RS_PULSE_CY then
					counter <= 0;
					c_state <= S_RS_POST;
				else
					counter <= counter + 1;
				end if;
			
			when S_RS_POST =>
				ROG_O	<= '0';
				CLK_O	<= '0';
				RS_O	<= '1';
						
				if counter = POST_RS_CY then
					counter <= 0;
					
					if trigger = '1' and data = '0' then
						c_state <= S_ROG_PRE;
					else
						c_state <= S_CLK_HIGH;
					end if;
				else
					counter <= counter + 1;
				end if;
			
			end case;
			
			
		end if;
	end if;
end process;

end Behavioral;
