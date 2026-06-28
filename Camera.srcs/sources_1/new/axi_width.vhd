library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity axi_width is
Generic (
	IN_WIDTH	: natural := 32;
	OUT_WIDTH	: natural := 8;
	REVERSE		: boolean := false
);
Port (
	AXIS_ACLK_I		: in	STD_LOGIC;
	RST_I			: in	STD_LOGIC;
		
	-- AXI Slave
	S_AXIS_TVALID_I	: in  STD_LOGIC;
	S_AXIS_TLAST_I	: in  STD_LOGIC;
	S_AXIS_TDATA_I	: in  STD_LOGIC_VECTOR(IN_WIDTH-1 downto 0);
	S_AXIS_TUSER_I	: in  STD_LOGIC_VECTOR(1 downto 0);
	S_AXIS_TREADY_O	: out STD_LOGIC;

	-- AXI Master
	M_AXIS_TVALID_O	: out STD_LOGIC;
	M_AXIS_TLAST_O	: out STD_LOGIC;
	M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(OUT_WIDTH-1 downto 0);
	M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR(1 downto 0);
	M_AXIS_TREADY_I	: in  STD_LOGIC
);
end axi_width;

architecture Behavioral of axi_width is

constant MAX_POS	: natural := IN_WIDTH / OUT_WIDTH - 1;
type natural_array_t is array(natural range <>) of natural range 0 to MAX_POS;

signal rpos			: natural range 0 to MAX_POS := 0;
signal wpos			: natural_array_t(MAX_POS downto 0) := (others => 0);

signal data			: std_logic_vector(IN_WIDTH-1 downto 0) := (others => '0');
signal last			: std_logic_vector(MAX_POS-1 downto 0) := (others => '0');

begin

assert IN_WIDTH rem OUT_WIDTH = 0 report "IN_WIDTH must be an integer multiple of OUT_WIDTH" severity error;

M_AXIS_TLAST_O <= last(last'high);

process (wpos(MAX_POS-1), data)
begin
	if REVERSE = TRUE then
		M_AXIS_TDATA_O <= data((wpos(MAX_POS-1) +1) * OUT_WIDTH-1 downto wpos(MAX_POS-1) * OUT_WIDTH);
	else
		M_AXIS_TDATA_O<= data((MAX_POS-wpos(MAX_POS-1) +1) * OUT_WIDTH-1 downto (MAX_POS-wpos(MAX_POS-1)) * OUT_WIDTH);
	end if;
end process;

process (AXIS_ACLK_I)
begin
	if rising_edge(AXIS_ACLK_I) then
		if RST_I = '1' then
			rpos <= 0;
			wpos <= (others => 0);
			last <= (others => '0');
		else

			if M_AXIS_TREADY_I = '1' then
				-- Input
				if (rpos = MAX_POS) then
					rpos	<= 0;
				else 
					rpos	<= rpos + 1;
				end if;
				
				if rpos = 0 then
					S_AXIS_TREADY_O	<= '1';
				else
					S_AXIS_TREADY_O	<= '0';
				end if;
				
				if (S_AXIS_TVALID_I = '1') then
					last(0) 		<= S_AXIS_TLAST_I;
					data			<= S_AXIS_TDATA_I;
					M_AXIS_TUSER_O	<= S_AXIS_TUSER_I; -- ?
				end if;
				
				-- Output
				wpos <= wpos(MAX_POS-1 downto 0) & rpos;
				last(last'high downto 1) <= last(last'high-1 downto 0);
			
				if (S_AXIS_TVALID_I = '1') then
					M_AXIS_TVALID_O	<= '1';
				elsif (wpos(MAX_POS-1) = MAX_POS) then
					M_AXIS_TVALID_O	<= '0';
				end if;

			else
				S_AXIS_TREADY_O	<= '0';
				M_AXIS_TVALID_O	<= '0';
			end if;
		end if;
	end if;
end process;

end Behavioral;
