library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.util.all;

entity uart_baudrate is
	generic (
		OVERSAMPLE	: 	integer := 16;
		CLOCKRATE	: 	integer := 50000000;
		BAUDRATE	:	integer := 9600
	);
	port (
		RST_I		: in STD_LOGIC;
		CLK_I		: in STD_LOGIC;
		
		OS_CLK_O	: out STD_LOGIC
	);
end uart_baudrate;

architecture RTL of uart_baudrate is

constant divider : integer := integer(round(real(CLOCKRATE) / (real(BAUDRATE) * real(OVERSAMPLE)))) - 1;

signal cnt 	: integer range 0 to divider := 0;
signal clk 	: std_logic := '0';

begin

log("UART Oversampling = " & integer'image(OVERSAMPLE) & " for " & integer'image(BAUDRATE) & "baud at " & integer'image(CLOCKRATE) & "Hz");
log("UART Clock Divider = " & integer'image(divider + 1));

OS_CLK_O	<= clk;

process (CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			cnt <= 0;
			clk <= '0';
		else
			if (cnt >= divider) then
				cnt <= 0;
				clk	<= '1';
			else
				clk	<= '0';
				cnt <= cnt + 1;
			end if;
		end if;
	end if;
end process;

end RTL;

