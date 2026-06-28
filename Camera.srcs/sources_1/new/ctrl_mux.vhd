library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use work.util.all;

entity ctrl_mux is
Generic (
	ADDR_WIDTH	: integer := 8;
	DATA_WIDTH	: integer := 16
);
Port (
	CLK_I		: in	STD_LOGIC;
	RST_I		: in	STD_LOGIC;
	
	SEL_I		: in	STD_LOGIC := '0';
	
	-- Target
	BUSY_I		: in	STD_LOGIC;
	DONE_I		: in	STD_LOGIC;
	
	READ_O		: out	STD_LOGIC := '0';
	WRITE_O		: out	STD_LOGIC := '0';
	
	ADDR_O		: out	STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0) := (others => '0');
	DATA_O		: out	STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
	DATA_I		: in	STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
	
	-- Port A
	A_BUSY_O	: out	STD_LOGIC;
	A_DONE_O	: out	STD_LOGIC;
	
	A_READ_I	: in	STD_LOGIC;
	A_WRITE_I	: in	STD_LOGIC;
	
	A_ADDR_I	: in	STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
	A_DATA_I	: in	STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
	A_DATA_O	: out	STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
	
	-- Port B
	B_BUSY_O	: out	STD_LOGIC;
	B_DONE_O	: out	STD_LOGIC;
	
	B_READ_I	: in	STD_LOGIC;
	B_WRITE_I	: in	STD_LOGIC;
	
	B_ADDR_I	: in	STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
	B_DATA_I	: in	STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
	B_DATA_O	: out	STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0')
);
end ctrl_mux;

architecture Behavioral of ctrl_mux is

signal sel		: std_logic := '0';

begin

mux : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if BUSY_I = '0' then
			sel <= SEL_I;
		end if;
	
		if sel = '0' then
			A_BUSY_O	<= BUSY_I;
			A_DONE_O	<= DONE_I;
			
			B_BUSY_O	<= '1';
			B_DONE_O	<= '0';
			
			READ_O		<= A_READ_I;
			WRITE_O		<= A_WRITE_I;
			
			ADDR_O		<= A_ADDR_I;
			DATA_O		<= A_DATA_I;
			A_DATA_O	<= DATA_I;
			B_DATA_O	<= (others => '0');
		else
			B_BUSY_O	<= BUSY_I;
			B_DONE_O	<= DONE_I;
			
			A_BUSY_O	<= '1';
			A_DONE_O	<= '0';
			
			READ_O		<= B_READ_I;
			WRITE_O		<= B_WRITE_I;
			
			ADDR_O		<= B_ADDR_I;
			DATA_O		<= B_DATA_I;
			B_DATA_O	<= DATA_I;
			A_DATA_O	<= (others => '0');
		end if;
	end if;
end process;

end Behavioral;