library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity axi_roi is
	Generic (
		DATA_WIDTH		: integer := 8
	);
	Port (
		AXIS_ACLK_I		: in	STD_LOGIC;
		RST_I			: in	STD_LOGIC;
			
		-- AXI Slave
		S_AXIS_TVALID_I	: in  STD_LOGIC;
		S_AXIS_TLAST_I	: in  STD_LOGIC;
		S_AXIS_TDATA_I	: in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
		S_AXIS_TUSER_I	: in  STD_LOGIC_VECTOR(1 downto 0);
		S_AXIS_TREADY_O	: out STD_LOGIC;
	
		-- AXI Master
		M_AXIS_TVALID_O	: out STD_LOGIC;
		M_AXIS_TLAST_O	: out STD_LOGIC;
		M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
		M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR(1 downto 0);
		M_AXIS_TREADY_I	: in  STD_LOGIC;
		
		WIDTH_I			: in	STD_LOGIC_VECTOR(15 downto 0);
		HEIGHT_I		: in	STD_LOGIC_VECTOR(15 downto 0);
		TOP_I			: in	STD_LOGIC_VECTOR(15 downto 0);
		LEFT_I			: in	STD_LOGIC_VECTOR(15 downto 0)
	);
end axi_roi;

architecture Behavioral of axi_roi is

signal pixel_nr		: std_logic_vector(15 downto 0) := (others => '0');
signal line_nr		: std_logic_vector(15 downto 0) := (others => '0');

signal pixel_nr_a	: std_logic_vector(15 downto 0) := (others => '0');
signal line_nr_a	: std_logic_vector(15 downto 0) := (others => '0');

signal left, top	: std_logic_vector(15 downto 0) := (others => '0');
signal width, height: std_logic_vector(15 downto 0) := (others => '1');

signal x, y			: std_logic_vector(1 downto 0) := "00";

signal in_frame		: std_logic := '0';

signal valid		: std_logic := '0';
signal last			: std_logic := '0';
signal user			: std_logic_vector(1 downto 0) := "00";
signal data			: std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

signal first_flag	: std_logic := '1';
signal last_flag	: std_logic := '1';
signal eof_flag		: std_logic := '1';

begin

process(AXIS_ACLK_I)
begin
	if rising_edge(AXIS_ACLK_I) then
		if S_AXIS_TUSER_I(0) = '1' then
			in_frame	<= '1';
			first_flag	<= '1';
			eof_flag	<= '1';
			line_nr		<= (others => '0');
			line_nr_a	<= (others => '0');
		end if;
		
		if S_AXIS_TUSER_I(1) = '1' then
			in_frame	<= '0';
		end if;
		
		if in_frame = '0' then
			x	<= "00";
			y	<= "00";
			
			left	<= LEFT_I;
			top		<= TOP_I;
			height	<= HEIGHT_I;
			width	<= WIDTH_I;
		end if;
		
		if pixel_nr >= left then
			pixel_nr_a <= inc(pixel_nr_a);
			x(0) <= '1';
			user(0) <= first_flag and y(0);
			first_flag <= not y(0);
		else
			x(0) <= '0';
		end if;
		
		if pixel_nr_a < width then
			x(1) <= '1';
			last <= '0';
			last_flag <= y(0) and y(1);
		else
			last <= last_flag;
			last_flag <= '0';
			x(1) <= '0';
		end if;
		
		if line_nr >= top then
			y(0) <= '1';
		end if;
				
		if line_nr_a < height then
			y(1) <= '1';
		else
			y(1) <= '0';
		end if;
		
		if S_AXIS_TLAST_I = '1' then
			pixel_nr 	<= (others => '0');
			pixel_nr_a	<= (others => '0');

			line_nr <= inc(line_nr);
		elsif S_AXIS_TVALID_I = '1' then
			pixel_nr <= inc(pixel_nr);
		end if;		
		
		data <= S_AXIS_TDATA_I;
		valid <= x(0) AND x(1) AND y(0) AND y(1);
		
		M_AXIS_TVALID_O <= valid;
		M_AXIS_TLAST_O	<= last;
		M_AXIS_TUSER_O	<= user; -- TODO EOF
		M_AXIS_TDATA_O	<= data;
		S_AXIS_TREADY_O <= M_AXIS_TREADY_I;
	
	end if;
end process;

end Behavioral;

