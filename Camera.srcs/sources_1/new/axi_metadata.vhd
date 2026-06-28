library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity axi_metadata is
Generic (
	PIXEL_WIDTH		: integer := 8;
	PIXEL_CHANNELS	: integer := 4
);
Port (
	RST_I			: in  STD_LOGIC;
	
	-- Metadata
	TIMESTAMP_I		: in STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
	FRAMENR_I		: in STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
	USERDATA_I		: in STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
	
	-- AXI Slave
	S_AXIS_ACLK_I	: in  STD_LOGIC;
	S_AXIS_TVALID_I	: in  STD_LOGIC;
	S_AXIS_TLAST_I	: in  STD_LOGIC;
	S_AXIS_TDATA_I	: in  STD_LOGIC_VECTOR(PIXEL_WIDTH*PIXEL_CHANNELS-1 downto 0);
	S_AXIS_TUSER_I	: in  STD_LOGIC_VECTOR(1 downto 0);
	S_AXIS_TREADY_O	: out STD_LOGIC;

	-- AXI Master
	M_AXIS_ACLK_O	: out STD_LOGIC;
	M_AXIS_TVALID_O	: out STD_LOGIC;
	M_AXIS_TLAST_O	: out STD_LOGIC;
	M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(PIXEL_WIDTH*PIXEL_CHANNELS-1 downto 0);
	M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR(1 downto 0);
	M_AXIS_TREADY_I	: in  STD_LOGIC
);
end axi_metadata;

architecture Behavioral of axi_metadata is

constant LENGTH		: integer := 80/PIXEL_CHANNELS-1;

signal first		: std_logic := '0';
signal pixel		: integer range 0 to LENGTH := 0;
signal metadata		: std_logic_vector(79 downto 0) := (others => '0');
signal meta			: std_logic_vector(PIXEL_WIDTH*PIXEL_CHANNELS-1 downto 0);

begin

fill : for i in 0 to PIXEL_CHANNELS-1 generate
	meta(PIXEL_WIDTH*(i+1)-1 downto PIXEL_WIDTH*i) <= (others => metadata(pixel * PIXEL_CHANNELS + i));
end generate;
	
M_AXIS_ACLK_O <= S_AXIS_ACLK_I;

process(S_AXIS_ACLK_I)
begin
	if rising_edge(S_AXIS_ACLK_I) then
	
		if first = '0' and S_AXIS_TUSER_I(0) = '1' then
			first <= '1';
			
			metadata(31 downto  0)	<= FRAMENR_I;
			metadata(63 downto 32)	<= TIMESTAMP_I;
			metadata(79 downto 64)	<= USERDATA_I;
		end if;
		
		if first = '1' and S_AXIS_TLAST_I = '1' then
			first <= '0';
		end if;		
		
		if first = '1' or S_AXIS_TUSER_I(0) = '1' then
			if pixel < LENGTH then
				pixel 			<= pixel + 1;
			else
				first <= '0';
			end if;
			
			M_AXIS_TDATA_O	<= meta;
		else
			pixel 			<= 0;
			M_AXIS_TDATA_O	<= S_AXIS_TDATA_I;
		end if;
		
		M_AXIS_TVALID_O	<= S_AXIS_TVALID_I;
		M_AXIS_TLAST_O	<= S_AXIS_TLAST_I;
		M_AXIS_TUSER_O	<= S_AXIS_TUSER_I;
		
		S_AXIS_TREADY_O	<= M_AXIS_TREADY_I;
	end if;
end process;

end Behavioral;
