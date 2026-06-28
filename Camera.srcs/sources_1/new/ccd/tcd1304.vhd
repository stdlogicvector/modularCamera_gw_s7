library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use Work.util.all;

entity tcd1304 is
	Generic (
		CLK_MHZ			: real := 100.0;
		FREQ_MHZ		: real range 0.8 to 4.0 := 4.0
	);
	Port (
		CLK_I		: in  STD_LOGIC;
		RST_I		: in  STD_LOGIC;
		
		SH_O		: out STD_LOGIC := '1';
		ICG_O		: out STD_LOGIC := '1';
		MCLK_O		: out STD_LOGIC := '0';
		
		SAMPLE_O	: out STD_LOGIC := '0';

		SOL_O		: out STD_LOGIC := '0';		
		EOL_O		: out STD_LOGIC := '0';
		EXPOSING_O	: out STD_LOGIC := '0';
		
		TRIGGER_I	: in  STD_LOGIC
	);
end tcd1304;

architecture Behavioral of tcd1304 is

constant PIXELS 	: integer := 3694;
constant BLANK_PRE	: integer := 32;
constant BLANK_POST	: integer := 14;

constant PRESCALE	: integer := integer(CLK_MHZ / FREQ_MHZ);

signal prescaler	: integer range 0 to PRESCALE-1 := 0;
signal strobe		: std_logic := '0';

signal trigger_edge	: std_logic_vector(1 downto 0) := "00";

type state_t 		is (S_IDLE, S_EXPOSURE, S_ICG_PRE, S_SH, S_ICG_POST, S_DATA);

signal state		: state_t := S_IDLE;

signal counter		: std_logic_vector(13 downto 0) := (others => '0');
alias  pixel		: std_logic_vector(11 downto 0) is counter(13 downto 2);
alias  cycle		: std_logic_vector( 1 downto 0) is counter( 1 downto 0); 

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if RST_I = '1' then
			prescaler	<= PRESCALE-1;
			state		<= S_IDLE;
		else				
			EXPOSING_O 	<= '0';
			SOL_O		<= '0';
			EOL_O		<= '0';
			SAMPLE_O	<= '0';
			
			trigger_edge <= trigger_edge(0) & TRIGGER_I;
		
			if prescaler = PRESCALE/2 then
				MCLK_O	<= '1';
			end if;
				
			if prescaler = PRESCALE-1 then
				MCLK_O		<= '0';
				prescaler	<= 0;
				strobe		<= '1';
			else
				prescaler	<= prescaler + 1;
				strobe		<= '0';
			end if;
		
			case state is
			when S_IDLE =>
				SH_O	<= '1';
				ICG_O	<= '1';
				
				if trigger_edge = "01" then
					state <= S_EXPOSURE;
				end if;
				
			when S_EXPOSURE =>
				SH_O 	<= '0';
				ICG_O	<= '1';
				
				EXPOSING_O <= '1';
				
				if strobe = '1' and TRIGGER_I = '0' then
					state <= S_ICG_PRE;
				end if;
			
			when S_ICG_PRE =>
				SH_O	<= '0';
				ICG_O	<= '0';
				
				if strobe = '1' then
					state <= S_SH;
				end if;
				
			when S_SH =>
				SH_O	<= '1';
				ICG_O	<= '0';
				
				if strobe = '1' then
					
					if counter = int2vec(integer(ceil(FREQ_MHZ))-1, 14) then
						counter <= (others => '0');
						state <= S_ICG_POST;
					else
						counter <= inc(counter);
					end if;
				end if;
				
			when S_ICG_POST =>
				SH_O	<= '0';
				ICG_O	<= '0';
				
				if strobe = '1' then
				
					if counter = int2vec(integer(ceil(FREQ_MHZ))-1, 14) then
						counter <= (others => '0');
						state	<= S_DATA;
						SOL_O	<= '1';
					else
						counter <= inc(counter);
					end if;
					
				end if;
			
			when S_DATA =>
				SH_O	<= '0';
				ICG_O	<= '1';
							
				if strobe = '1' then
					if  cycle = "01"
					and pixel > int2vec(BLANK_PRE-1, 12)
					and pixel < int2vec(PIXELS-BLANK_POST, 12)
					then
						SAMPLE_O <= '1';
					end if;
					
					if cycle = "00" and pixel = int2vec(PIXELS-BLANK_POST-1, 12) then
						EOL_O	<= '1';
					end if;
					
					if cycle = "11" and pixel = int2vec(PIXELS-1, 12) then
						counter <= (others => '0');
						state	<= S_IDLE;
					else
						counter <= inc(counter);
					end if;
				end if;
			
			end case;
		end if;
	end if;
end process;

end Behavioral;
