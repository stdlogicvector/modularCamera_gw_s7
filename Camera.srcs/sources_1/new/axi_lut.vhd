library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.ALL;
use work.util.all;

entity axi_lut is
Generic (
	INPUT_WIDTH			: integer := 8;
	OUTPUT_WIDTH		: integer := 8;
	INIT_FILE			: string  := "";
	INIT_VALUES			: integer_vector := (0, 0);
	FILE_TYPE			: string := "NUMBER";
);
Port (
	CLK_I				: in  STD_LOGIC;
	RST_I				: in  STD_LOGIC;
	
	LUT_WRITE_I			: in  STD_LOGIC := '0';
	LUT_ACK_O			: out STD_LOGIC := '0';
	LUT_ADDR_I			: in  STD_LOGIC_VECTOR(INPUT_WIDTH-1 downto 0) := (others => '0');
	LUT_DATA_I			: in  STD_LOGIC_VECTOR(OUTPUT_WIDTH-1 downto 0) := (others => '0');
	
	-- AXI Slave
	S_AXIS_ACLK_I		: in  STD_LOGIC;
	S_AXIS_TVALID_I		: in  STD_LOGIC;
	S_AXIS_TLAST_I		: in  STD_LOGIC;
	S_AXIS_TDATA_I		: in  STD_LOGIC_VECTOR(INPUT_WIDTH-1 downto 0);
	S_AXIS_TUSER_I		: in  STD_LOGIC_VECTOR(1 downto 0);
	S_AXIS_TREADY_O		: out STD_LOGIC;

	-- AXI Master
	M_AXIS_ACLK_O		: out STD_LOGIC := '0';
	M_AXIS_TVALID_O		: out STD_LOGIC := '0';
	M_AXIS_TLAST_O		: out STD_LOGIC := '0';
	M_AXIS_TUSER_O		: out STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
	M_AXIS_TDATA_O		: out STD_LOGIC_VECTOR(OUTPUT_WIDTH-1 downto 0) := (others => '0');
	M_AXIS_TREADY_I		: in  STD_LOGIC	
);
end axi_lut;

architecture Behavioral of axi_lut is

constant DELAY			: integer := 2;

signal val_delay		: std_logic_vector(DELAY-1 downto 0) := "00";
signal eol_delay		: std_logic_vector(DELAY-1 downto 0) := "00";
signal sof_delay		: std_logic_vector(DELAY-1 downto 0) := "00";
signal eof_delay		: std_logic_vector(DELAY-1 downto 0) := "00";

begin

LUT_ACK_O <= '1';

M_AXIS_ACLK_O <= S_AXIS_ACLK_I;

lut : entity work.ram
generic map (
	RAM_WIDTH	=> OUTPUT_WIDTH,
	RAM_DEPTH	=> 2**(INPUT_WIDTH),
	INIT_VALUES	=> INIT_VALUES,
	INIT_FILE	=> INIT_FILE,
	FILE_TYPE	=> FILE_TYPE
)
port map (
	RESET_I		=> RST_I,
	
	A_CLK_I		=> CLK_I,
	A_ENA_I		=> '1',
	A_WEN_I		=> LUT_WRITE_I,
	A_ADDR_I	=> LUT_ADDR_I,
	A_DATA_I	=> LUT_DATA_I,
	
	B_CLK_I		=> S_AXIS_ACLK_I,
	B_ENA_I		=> '1',
	B_WEN_I		=> '0',
	B_ADDR_I	=> S_AXIS_TDATA_I,
	B_DATA_O	=> M_AXIS_TDATA_O
);

mapping : process(S_AXIS_ACLK_I)
begin
	if rising_edge(S_AXIS_ACLK_I) then
	
		S_AXIS_TREADY_O <= M_AXIS_TREADY_I;
	
		val_delay <= val_delay(val_delay'high-1 downto 0) & S_AXIS_TVALID_I;
		eol_delay <= eol_delay(eol_delay'high-1 downto 0) & S_AXIS_TLAST_I;
		sof_delay <= sof_delay(sof_delay'high-1 downto 0) & S_AXIS_TUSER_I(0);
		eof_delay <= eof_delay(eof_delay'high-1 downto 0) & S_AXIS_TUSER_I(1);
	end if;
end process;

M_AXIS_TVALID_O		<= val_delay(val_delay'high);
M_AXIS_TLAST_O		<= eol_delay(val_delay'high);
M_AXIS_TUSER_O(0)	<= sof_delay(sof_delay'high);
M_AXIS_TUSER_O(1)	<= eof_delay(eof_delay'high);

end Behavioral;
