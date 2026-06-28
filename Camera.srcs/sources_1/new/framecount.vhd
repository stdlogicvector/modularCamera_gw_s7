library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.util.all;

entity framecount is
Port (
	CLK_I			: in  STD_LOGIC;
	RST_I			: in  STD_LOGIC;

	ZERO_I			: in  STD_LOGIC;
	S_AXIS_TLAST_I	: in  STD_LOGIC := '0';
	S_AXIS_TUSER_I	: in  STD_LOGIC_VECTOR(1 downto 0);
	LINENR_O 		: out STD_LOGIC_VECTOR(15 downto 0);
	FRAMENR_O 		: out STD_LOGIC_VECTOR(31 downto 0)
);
end framecount;

architecture Behavioral of framecount is
	
signal linenr		: std_logic_vector(15 downto 0) := (others => '0');
signal framenr		: std_logic_vector(31 downto 0) := (others => '0');

begin

FRAMENR_O <= framenr;

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if ZERO_I = '1' then
			linenr <= (others => '0');
			framenr <= (others => '0');
		else
			if S_AXIS_TUSER_I(1) = '1' then
				linenr	<= (others => '0');
				framenr <= inc(framenr);
			elsif S_AXIS_TLAST_I = '1' then
				linenr <= inc(linenr);
			end if;
		end if;
	end if;
end process;

end Behavioral;
