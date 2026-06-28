library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use Work.util.all;

entity registers is
	generic (
		NR_OF_REGS		: integer	:= 32;
		DEFAULT_VALUE	: array16_t(0 to NR_OF_REGS-1) := (others => x"0000")
	);
	port (
		-- system signals
		CLK_I		: in	std_logic;
		RST_I		: in	std_logic;

		-- Interface
		ACK_O		: out	std_logic := '0';
		WRITE_I		: in	std_logic := '0';
		READ_I		: in	std_logic := '0';
		ADDR_I		: in	std_logic_vector( 7 downto 0);
		DATA_O		: out	std_logic_vector(15 downto 0) := (others => '0');
		DATA_I		: in	std_logic_vector(15 downto 0);
		
		-- Registers
		REG_DV_O	: out	std_logic_vector(NR_OF_REGS-1 downto 0) := (others => '0');
		REGISTERS_O	: out 	array16_t(0 to NR_OF_REGS-1);
		
		REG_DV_I	: in	std_logic_vector(NR_OF_REGS-1 downto 0);
		REGISTERS_I	: in 	array16_t(0 to NR_OF_REGS-1)
	);
end registers;

architecture Behavioral of registers is

constant ADDR_WIDTH : integer := clogb2(NR_OF_REGS) - 1;

signal reg_ro	: array16_t(0 to NR_OF_REGS-1) := (others => (others => '0'));

signal reg_rw	: array16_t(0 to NR_OF_REGS-1) := DEFAULT_VALUE;

begin

rw : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			reg_ro	<= REGISTERS_I;		-- Get initial values from unchanging registers
		else
			for i in 0 to NR_OF_REGS-1 loop
				if REG_DV_I(i) = '1' then
					reg_ro(i) <= REGISTERS_I(i);
				end if;
			end loop;		
		
			REG_DV_O	<= (others => '0');
			ACK_O		<= WRITE_I OR READ_I;
			
			if (WRITE_I = '0') then
				reg_rw(0) <= x"0000";	-- Automatically reset to zero
			end if;
			
			if (ADDR_I(ADDR_I'high) = '0') then
				if (WRITE_I = '1') then
					REG_DV_O(vec2int(ADDR_I(ADDR_WIDTH downto 0)))	<= '1';
					reg_rw(vec2int(ADDR_I(ADDR_WIDTH downto 0)))	<= DATA_I;
				end if;
			end if;
		end if;
	end if;
end process rw;

mux : process(ADDR_I, reg_rw, reg_ro)
begin
	if (ADDR_I(ADDR_I'high) = '0') then
		DATA_O  	<= reg_rw(vec2int(ADDR_I(ADDR_WIDTH downto 0)));
	else
		DATA_O  	<= reg_ro(vec2int(ADDR_I(ADDR_WIDTH downto 0)));
	end if;
end process;

REGISTERS_O <= reg_rw;

end architecture;