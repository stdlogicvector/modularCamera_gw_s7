library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.util.all;

entity trigger_gen is
Generic (
	CLK_MHZ			: real := 100.0;
	RESOLUTION_US	: integer := 1
);
Port (
	CLK_I		: in STD_LOGIC;
	RST_I		: in STD_LOGIC;
	
	ENABLE_I	: in STD_LOGIC;
	
	TRIGGER_O	: out STD_LOGIC := '0';
	EXPOSE_O	: out STD_LOGIC := '0';
	
	PERIOD_I	: in STD_LOGIC_VECTOR(31 downto 0);
	EXPOSURE_I	: in STD_LOGIC_VECTOR(15 downto 0)
);
end trigger_gen;

architecture Behavioral of trigger_gen is

constant CLK_PERIOD	: real := 1000.0 / CLK_MHZ;
constant PRESCALE	: integer := integer(real(RESOLUTION_US) * 1000.0 / CLK_PERIOD);

signal prescaler	: integer range 0 to PRESCALE-1 := 0;
signal strobe		: std_logic := '0';

signal p_limit		: std_logic_vector(31 downto 0) := (others => '0');
signal e_limit		: std_logic_vector(15 downto 0) := (others => '0');
signal period		: std_logic_vector(31 downto 0) := (others => '0');
signal exposure		: std_logic_vector(15 downto 0) := (others => '0');

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if ENABLE_I = '0' then
			prescaler	<= PRESCALE-1;
			strobe		<= '0';
			period	  	<= (others => '1');
			exposure	<= (others => '0');
		else
			if prescaler = PRESCALE-1 then
				prescaler	<= 0;
				strobe		<= '1';
			else
				prescaler	<= prescaler + 1;
				strobe		<= '0';
			end if;
		end if;
		
		TRIGGER_O	<= '0';
		p_limit 	<= dec(PERIOD_I);
		e_limit		<= dec(EXPOSURE_I);

		if strobe = '1' then
			EXPOSE_O	<= '0';
		
			if period >= p_limit then
				TRIGGER_O	<= '1';
				EXPOSE_O	<= '1';
				period	  	<= (others => '0');
				exposure	<= (others => '0');
			else
				period		<= inc(period);
			
				if exposure < e_limit then
					exposure	<= inc(exposure);
					EXPOSE_O	<= '1';
				end if;
			end if;
		
		end if;
	end if;
end process;

end Behavioral;
