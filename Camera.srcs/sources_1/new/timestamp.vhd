library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.util.all;

entity timestamp is
Generic (
	CLK_MHZ			: real := 100.0;
	RESOLUTION_US	: integer := 1
);
Port (
	CLK_I			: in  STD_LOGIC;
	RST_I			: in  STD_LOGIC;
	
	ZERO_I			: in  STD_LOGIC;
	S_AXIS_TUSER_I	: in  STD_LOGIC_VECTOR(1 downto 0);
	TIMESTAMP_O 	: out STD_LOGIC_VECTOR(31 downto 0)
);
end timestamp;

architecture Behavioral of timestamp is

constant CLK_PERIOD	: real := 1000.0 / CLK_MHZ;
constant PRESCALE	: integer := integer(real(RESOLUTION_US) * 1000.0 / CLK_PERIOD);

signal prescaler	: integer range 0 to PRESCALE-1 := 0;
signal timestamp	: std_logic_vector(31 downto 0) := (others => '0');

signal running		: std_logic := '0';

begin

TIMESTAMP_O <= timestamp;

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if ZERO_I = '1' then
			timestamp <= (others => '0');
			prescaler <= PRESCALE-1;
			running	  <= '0';
		else
		
			if S_AXIS_TUSER_I(0) = '1' then
				running <= '1';
			end if;
			
			if prescaler = PRESCALE-1 then
				prescaler	<= 0;
				timestamp	<= inc(timestamp);
			else
				if running = '1' then
					prescaler	<= prescaler + 1;
				end if;
			end if;	
		end if;
	end if;
end process;

end Behavioral;
