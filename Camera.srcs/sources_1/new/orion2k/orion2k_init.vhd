library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.types.all;

entity orion2k_init is
Generic (
	CLK_MHZ			: real := 100.0
);
Port (
	CLK_I		: in  STD_LOGIC;
	RST_I		: in  STD_LOGIC;
	
	SOFT_RESET_I: in  STD_LOGIC;
	
	RST_PLL_O	: out STD_LOGIC := '0';
	RST_LOGIC_O	: out STD_LOGIC := '0';
	RST_SPI_O	: out STD_LOGIC := '0'
);
end orion2k_init;

architecture Behavioral of orion2k_init is

constant CLK_PERIOD	: real := 1000.0 / CLK_MHZ;
constant WAIT_1US  : integer := integer(ceil(1100.0 / CLK_PERIOD));	--  1.1us delay
constant WAIT_10US : integer := 10 * wait_1us;						-- 11.0us delay

type state_t is (RST_PLL, RST_SPI, RST_LOGIC, IDLE);
signal state : state_t := RST_PLL;

signal counter : integer range 0 to WAIT_10US := 0;
signal edge	: std_logic_vector(1 downto 0) := "00";

begin

process (CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			edge	  		<= "00";
			counter 		<= 0;
			
			RST_PLL_O	<= '0';
			RST_SPI_O 	<= '0';
			RST_LOGIC_O <= '0';
			
			state <= RST_PLL;
		else
			edge <= edge(0) & SOFT_RESET_I;
			
			case (state) is
			when RST_PLL =>
				if (counter < WAIT_1US) then
					counter <= counter + 1;
				else
					counter 	 <= 0;
					RST_PLL_O <= '1';
					state 	 <= RST_SPI;
				end if;
				
			when RST_SPI =>
				if (counter < WAIT_10US) then
					counter <= counter + 1;
				else
					counter 	 <= 0;
					RST_SPI_O <= '1';
					state 	 <= RST_LOGIC;
				end if;
				
			when RST_LOGIC =>
				if (counter < 5) then
					counter <= counter + 1;
				else
					counter 	 	<= 0;
					RST_LOGIC_O <= '1';
					state 	 	<= IDLE;
				end if;	
				
			when IDLE =>
				if (edge = "10") then		-- falling Edge on Soft Reset
					state <= RST_PLL;
					
					RST_PLL_O 	<= '0';
					RST_SPI_O 	<= '0';
					RST_LOGIC_O <= '0';
				end if;
				
			end case;
		end if;
	end if;
end process;

end Behavioral;
