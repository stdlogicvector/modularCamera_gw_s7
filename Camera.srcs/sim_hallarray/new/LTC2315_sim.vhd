library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity LTC2315_sim is
Port (
	nCS_I		: in  STD_LOGIC := '1';
	SCK_I		: in  STD_LOGIC := '0';
	SDO_O		: out STD_LOGIC := '0';
	ANALOG_I 	: in  integer range 0 to 2**12-1
); 
end LTC2315_sim;

architecture Behavioral of LTC2315_sim is

signal value	: std_logic_vector(11 downto 0) := (others => '0');

begin

process
variable b : integer := 0;
begin
	SDO_O	<= 'Z';
	
	wait until falling_edge(nCS_I);
	SDO_O <= '0';
		
	wait until falling_edge(SCK_I);
	SDO_O <= '0';
		
	for b in 11 downto 0 loop
		wait until falling_edge(SCK_I);
		SDO_O <= value(b);
	end loop;
	
	wait until falling_edge(SCK_I);
	SDO_O <= '0';
	
	wait until rising_edge(nCS_I);
	SDO_O	<= 'Z';

	wait for 40 ns;
	value <= int2vec(ANALOG_I, 12);

end process;

end Behavioral;
