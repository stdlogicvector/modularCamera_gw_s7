library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.ALL;
use work.types.all;
use work.util.all;

entity aisc110c is
Port (
	RST_I			: in STD_LOGIC;

	TRIGGER_I		: in STD_LOGIC;

	-- Sensor Interface
	CLK_I			: in STD_LOGIC;
	DV_I			: in STD_LOGIC;
	DATA_I			: in STD_LOGIC_VECTOR(31 downto 0);
	GP_IO			: inout STD_LOGIC_VECTOR(2 downto 0) := (others => 'Z');
	
	-- AXI Master
	M_AXIS_ACLK_O	: out STD_LOGIC := '0';
	M_AXIS_TVALID_O	: out STD_LOGIC := '0';
	M_AXIS_TLAST_O	: out STD_LOGIC := '0';
	M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
	M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR( 1 downto 0) := (others => '0');
	M_AXIS_TREADY_I	: in  STD_LOGIC
	
	-- Debug
	;TRIGGER_O		: out STD_LOGIC := '0'
	;DV_O           : out STD_LOGIC := '0'
	;SYNC_O			: out STD_LOGIC := '0'
);
end aisc110c;

architecture Behavioral of aisc110c is

signal dv			: std_logic := '0';
signal last_dv		: std_logic := '0';
signal sync			: std_logic := '0';

signal ready		: std_logic := '0';

signal data			: std_logic_vector(31 downto 0);
signal last_data	: std_logic_vector(31 downto 0);
signal sof			: std_logic := '0';
signal valid		: std_logic := '0';

begin

TRIGGER : OBUF
generic map (
	DRIVE		=> 12,
	IOSTANDARD	=> "DEFAULT",
	SLEW		=> "SLOW"
)
port map (
	O			=> GP_IO(0),
	I			=> TRIGGER_I 
);

TRIGGER_O <= TRIGGER_I;

SYNC_I : IBUF
generic map (
	IBUF_LOW_PWR=> FALSE,
	IOSTANDARD	=> "DEFAULT"
)
port map (
	I			=> GP_IO(1),
	O			=> open -- no contact on Sensor PCBv1
);

SYNC_O <= sync;

UNUSED : IBUF
generic map (
	IBUF_LOW_PWR=> FALSE,
	IOSTANDARD	=> "DEFAULT"
)
port map (
	I			=> GP_IO(2),
	O			=> sync
);

CLOCK_I : BUFG
port map (
	I			=> CLK_I,
	O			=> M_AXIS_ACLK_O
);

DVAL : IBUF
generic map (
	IBUF_LOW_PWR=> FALSE,
	IOSTANDARD	=> "DEFAULT"
)
port map (
	I			=> DV_I,
	O			=> dv
);

DV_O <= dv;

DATA_n : for i in 0 to 31 generate
	n : IBUF
	generic map (
		IBUF_LOW_PWR=> FALSE,
		IOSTANDARD	=> "DEFAULT"
	)
	port map (
		I			=> DATA_I(i),
		O			=> data(i)
	);
end generate;

process(M_AXIS_ACLK_O)	-- Sensor Clock is only running during data transmission
begin
	if falling_edge(M_AXIS_ACLK_O) then	-- Sync pulse is only half a cycle wide
	--if rising_edge(M_AXIS_ACLK_O) then	
		last_dv		<= dv;

		if dv = '0' then
			valid <= '0';
			ready <= M_AXIS_TREADY_I;
		else
			valid <= ready;
		end if;

		last_data			<= data;
		M_AXIS_TDATA_O		<= last_data;
		M_AXIS_TLAST_O		<= (sync AND last_dv) or (last_dv and not dv);		-- End of Line
		sof   				<= dv and not last_dv;								-- Start of Frame
		M_AXIS_TUSER_O(0)	<= sof;
		M_AXIS_TUSER_O(1)	<= not dv and last_dv;                              -- End of Frame
		M_AXIS_TVALID_O		<= valid;
	end if;
end process;

end Behavioral;



