library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use Work.util.all;

entity LTC2315 is
	Port (
		CLK_I 		: in  STD_LOGIC;
		RST_I		: in  STD_LOGIC;
		
		CS_O		: out STD_LOGIC := '1';
		SCK_O		: out STD_LOGIC := '1';
		SDO_I		: in  STD_LOGIC;
		
		SAMPLE_I 	: in STD_LOGIC;
		
		BUSY_O 		: out STD_LOGIC := '0';
		
		DV_O 		: out STD_LOGIC := '0';
		DATA_O 		: out STD_LOGIC_VECTOR (11 downto 0) := (others => '0')		
	);
end LTC2315;

architecture Behavioral of LTC2315 is

type state_t	is (S_IDLE, S_READ, S_ACQ);
signal state	: state_t := S_IDLE;

signal counter	: integer range 0 to 26 := 0;

signal value	: std_logic_vector(12 downto 0) := (others => '0');

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		DV_O <= '0';
		
		case state is
		when S_IDLE =>
			SCK_O <= '1';
			
			
			if SAMPLE_I = '1' then
				BUSY_O <= '1';
				CS_O <= '0';
				state <= S_READ;
			else
				CS_O <= '1';
				BUSY_O <= '0';
			end if;
			
		when S_READ =>
			if counter = 26 then
				counter <= 0;
				state <= S_ACQ;
				
--				DV_O <= '1';
				DATA_O <= value(11 downto 0);
			else
				counter <= counter + 1;
			end if;
			
			if counter mod 2 = 0 then
				SCK_O <= '0';
			else
				SCK_O <= '1';
				value <= value(11 downto 0) & SDO_I;
			end if;			
		
		when S_ACQ =>
			CS_O  <= '1';
			SCK_O <= '1';
			
			if counter = 4 then
				DV_O <= '1';		
				counter <= 0;
				state	<= S_IDLE;
			else
				counter <= counter + 1;
			end if;
		end case;
	end if;
end process;

end Behavioral;
