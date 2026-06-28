library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.ALL;
use work.util.all;

entity axi_yuv444_to_yuv422 is
Port (
	RST_I		: in  STD_LOGIC;
	
	-- AXI Slave
	S_AXIS_ACLK_I		: in  STD_LOGIC;
	S_AXIS_TVALID_I		: in  STD_LOGIC;
	S_AXIS_TLAST_I		: in  STD_LOGIC;
	S_AXIS_TDATA_I		: in  STD_LOGIC_VECTOR(23 downto 0);
	S_AXIS_TUSER_I		: in  STD_LOGIC_VECTOR(1 downto 0);
	S_AXIS_TREADY_O		: out STD_LOGIC;
	
	-- AXI Master
	M_AXIS_ACLK_O		: out STD_LOGIC := '0';
	M_AXIS_TVALID_O		: out STD_LOGIC := '0';
	M_AXIS_TLAST_O		: out STD_LOGIC := '0';
	M_AXIS_TUSER_O		: out STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
	M_AXIS_TDATA_O		: out STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	M_AXIS_TREADY_I		: in  STD_LOGIC		
);
end axi_yuv444_to_yuv422;

architecture Behavioral of axi_yuv444_to_yuv422 is

signal sel	: std_logic := '0';
alias y		: std_logic_vector(7 downto 0) is S_AXIS_TDATA_I(23 downto 16);
alias u		: std_logic_vector(7 downto 0) is S_AXIS_TDATA_I(15 downto  8);
alias v		: std_logic_vector(7 downto 0) is S_AXIS_TDATA_I( 7 downto  0);

begin

M_AXIS_ACLK_O <= S_AXIS_ACLK_I;

convert : process(M_AXIS_ACLK_O)
begin
	if rising_edge(M_AXIS_ACLK_O) then
		M_AXIS_TVALID_O <= S_AXIS_TVALID_I;	
		M_AXIS_TLAST_O	<= S_AXIS_TLAST_I;
		M_AXIS_TUSER_O	<= S_AXIS_TUSER_I;
		S_AXIS_TREADY_O	<= M_AXIS_TREADY_I;
				
		M_AXIS_TDATA_O(7 downto 0)	<= y;
		
		if sel = '0' then
			sel <= '1';
			M_AXIS_TDATA_O(15 downto 8) <= u;
		else
			sel <= '0';
			M_AXIS_TDATA_O(15 downto 8) <= v;
		end if;
		
	end if;
end process;

end Behavioral;
