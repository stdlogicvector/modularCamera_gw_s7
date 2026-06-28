library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.util.all;

entity dbg_mux is
Generic (
	SLOTS		: integer range 1 to 31 := 4
);
Port (
	SELECT_I	: in  STD_LOGIC_VECTOR(clogb2(SLOTS)-1 downto 0);
	DBG_O		: out STD_LOGIC_VECTOR(1 downto 0);
	DBG_I		: in  STD_LOGIC_VECTOR(SLOTS*2-1 downto 0)
);
end dbg_mux;

architecture Behavioral of dbg_mux is

begin

process(DBG_I, SELECT_I)
variable h, l : integer := 0;
begin
	l := vec2int(SELECT_I) * 2;
	h := l + 1;

	DBG_O <= DBG_I(h downto l);
end process;

end Behavioral;
