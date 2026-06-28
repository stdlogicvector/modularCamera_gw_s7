library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.util.all;

entity linear_ccd is
	Generic (
		CHANNELS		: integer := 3;
		WIDTH			: integer := 12
	);
	Port (
		CLK_I			: in  STD_LOGIC;
		RST_I			: in  STD_LOGIC;
		
		LPF_I			: in  STD_LOGIC_VECTOR(15 downto 0);
		TRIGGER_I		: in  STD_LOGIC;
		
		-- Sensor Interface
		CTL_O			: out STD_LOGIC_VECTOR(5 downto 0);
		
		CS_O			: out STD_LOGIC_VECTOR(2 downto 0) := (others => '1');
		SCK_O			: out STD_LOGIC_VECTOR(2 downto 0) := (others => '1');
		SDO_I			: in  STD_LOGIC_VECTOR(2 downto 0);
		
		-- AXI Master
		M_AXIS_ACLK_O	: out STD_LOGIC := '0';
		M_AXIS_TVALID_O	: out STD_LOGIC := '0';
		M_AXIS_TLAST_O	: out STD_LOGIC := '0';
		M_AXIS_TDATA_O	: out STD_LOGIC_VECTOR(CHANNELS*WIDTH-1 downto 0) := (others => '0');
		M_AXIS_TUSER_O	: out STD_LOGIC_VECTOR( 1 downto 0) := (others => '0');
		M_AXIS_TREADY_I	: in  STD_LOGIC;
		
		EXPOSING_O		: out STD_LOGIC		
	);
end linear_ccd;

architecture tcd1304 of linear_ccd is

signal ctl		: std_logic_vector(5 downto 0) := (others => '1');

signal sample	: std_logic;

signal sol		: std_logic;
signal eol		: std_logic;
signal eof		: std_logic := '0';

signal first	: std_logic := '0';
signal last		: std_logic := '0';

signal row, col	: std_logic_vector(15 downto 0) := (others => '0');

signal dv		: std_logic;
signal data		: std_logic_vector(11 downto 0);

begin

-- CTL: CLK1, CLK2, SH, RS, DT, SP

CTL_O <= not ctl; -- Inverted by levelshifter

sensor : entity work.tcd1304
port map (
	CLK_I		=> CLK_I,
	RST_I		=> RST_I,
	
	SH_O		=> ctl(2),
	ICG_O		=> ctl(3),
	MCLK_O		=> ctl(0),
	
	SAMPLE_O	=> sample,
	SOL_O		=> sol,
	EOL_O		=> eol,
	EXPOSING_O	=> EXPOSING_O,
	
	TRIGGER_I	=> TRIGGER_I
);

adc : entity work.LTC2315
port map (
	CLK_I		=> CLK_I,
	RST_I		=> RST_I,
		
	CS_O		=> CS_O(0),
	SCK_O		=> SCK_O(0),
	SDO_I		=> SDO_I(0),
	
	SAMPLE_I 	=> sample,
	
	DV_O 		=> dv,
	DATA_O 		=> data		
);

M_AXIS_ACLK_O <= CLK_I;

axi : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		
		if sol = '1' then
			row  <= inc(row);
			first <= '1';
		elsif dv = '1' then
			first <= '0';
		end if;
		
		if eol = '1' then
			last <= '1';
			
			if row = LPF_I then
				row <= (others => '0');
				eof <= '1';
			end if;
		elsif dv = '1' then
			eof  <= '0';
			last <= '0';
		end if;

		if dv = '1' then
			if last = '1' then
				col  <= (others => '0');
			else
				col <= inc(col);
			end if;
		end if;
		
		M_AXIS_TVALID_O 	<= dv;
		M_AXIS_TDATA_O		<= data(data'high downto data'high-CHANNELS*WIDTH+1);
		M_AXIS_TLAST_O		<= dv and last;
		M_AXIS_TUSER_O(0)	<= dv and first;
		M_AXIS_TUSER_O(1)	<= dv and eof;
	end if;
end process;

end tcd1304;

architecture ilx506 of linear_ccd is

signal ctl		: std_logic_vector(5 downto 0) := (others => '1');

signal sample	: std_logic;

signal sol		: std_logic;
signal eol		: std_logic;
signal eof		: std_logic := '0';

signal first	: std_logic := '0';
signal last		: std_logic := '0';

signal row, col	: std_logic_vector(15 downto 0) := (others => '0');

signal dv		: std_logic;
signal data		: std_logic_vector(11 downto 0);

begin
--		0	  1     2   3   4   5
-- CTL: CLK1, CLK2, SH, RS, DT, SP

CTL_O <= not ctl; -- Inverted by levelshifter

sensor : entity work.ilx506
port map (
	CLK_I		=> CLK_I,
	RST_I		=> RST_I,
	
	ROG_O		=> ctl(2),
	RS_O		=> ctl(3),
	CLK_O		=> ctl(0),
	
	SAMPLE_O	=> sample,
	SOL_O		=> sol,
	EOL_O		=> eol,
	EXPOSING_O	=> EXPOSING_O,
	
	TRIGGER_I	=> TRIGGER_I
);

adc : entity work.LTC2315
port map (
	CLK_I		=> CLK_I,
	RST_I		=> RST_I,
		
	CS_O		=> CS_O(0),
	SCK_O		=> SCK_O(0),
	SDO_I		=> SDO_I(0),
	
	SAMPLE_I 	=> sample,
	
	DV_O 		=> dv,
	DATA_O 		=> data		
);

M_AXIS_ACLK_O <= CLK_I;

axi : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		
		if sol = '1' then
			row  <= inc(row);
			first <= '1';
		elsif dv = '1' then
			first <= '0';
		end if;
		
		if eol = '1' then
			last <= '1';
			
			if row = LPF_I then
				row <= (others => '0');
				eof <= '1';
			end if;
		elsif dv = '1' then
			eof  <= '0';
			last <= '0';
		end if;

		if dv = '1' then
			if last = '1' then
				col  <= (others => '0');
			else
				col <= inc(col);
			end if;
		end if;
		
		M_AXIS_TVALID_O 	<= dv;
		M_AXIS_TDATA_O		<= data(data'high downto data'high-CHANNELS*WIDTH+1);
		M_AXIS_TLAST_O		<= dv and last;
		M_AXIS_TUSER_O(0)	<= dv and first;
		M_AXIS_TUSER_O(1)	<= dv and eof;
	end if;
end process;

end ilx506;
