library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use work.util.all;

entity misc_tb is
--  Port ( );
end misc_tb;

architecture Behavioral of misc_tb is

signal clk100			: std_logic := '0';

signal trigger			: std_logic := '0';
signal sample			: std_logic := '0';

signal i2s_sck			: std_logic := '0';
signal i2s_ws			: std_logic := '0';
signal i2s_sd			: std_logic := '0';

signal i2s_ws_last		: std_logic := '0';

signal i2s_b			: integer := 0;
signal i2s_data			: std_logic_vector(31 downto 0) := x"AAA55000";

signal cap_pin			: std_logic;
signal cap_en			: std_logic := '1';

signal spi_ncs			: std_logic;
signal spi_sck			: std_logic;
signal spi_miso			: std_logic;
signal spi_mosi			: std_logic;					


begin

sim : process
begin
	wait for 5us;
	
	sample <= '1';
	wait for 20ns;
	sample <= '0';
/*	
	loop
		wait until rising_edge(clk100);
		trigger <= '1';
		wait for 10us;
		wait until rising_edge(clk100);
		trigger <= '0';
		wait for 15ms;
		wait until rising_edge(clk100);
	end loop;
*/	

	wait;
end process;

clk_100 : process
begin
	clock(100.0, 0ns, clk100);
end process;

ctrl : entity work.python_ctrl
generic map (
	CLK_MHZ		=> 100.0,
	SPI_MHZ		=> 10.0,
	PAUSE_US	=> 11.0,
	SIMULATION	=> TRUE
)
port map (
	CLK_I		=> clk100,
	RST_I		=> '0',
	
	EN_1V8_O	=> open,
	EN_3V3_O	=> open,
	EN_PIX_O	=> open,
	EN_CLK_O	=> open,
	RST_O		=> open,
	
	ENABLE_I	=> '0',
	
	BUSY_O		=> open,
	DONE_O		=> open,
	
	READ_I		=> sample,
	WRITE_I		=> '0',
	
	ADDR_I		=> x"0155",
	DATA_I		=> x"AAAA",
	DATA_O		=> open,
	
	nCS_O		=> spi_ncs,
	SCK_O		=> spi_sck,
	MOSI_O		=> spi_mosi,
	MISO_I	 	=> spi_miso
);

spi : process
variable miso : std_logic_vector(15 downto 0) := x"1234";
begin
	wait until spi_ncs = '0';
	
	for i in 0 to 8 loop
		wait until rising_edge(spi_sck);
	end loop;
	
	wait until rising_edge(spi_sck);
	
	for i in 15 downto 0 loop
		wait until rising_edge(spi_sck);
		spi_miso <= miso(i);
	end loop;

	wait until spi_ncs = '1';
end process;

/*
cap : entity work.capsense
generic map (
	DRIVE_TIME	=> 50
)
port map (
	CLK_I		=> clk100,
	RST_I		=> '0',

	EN_I		=> cap_en,
	SENSE_I		=> int2vec(5000, 16),
	
	PIN_IO		=> cap_pin,

	VALUE_O		=> open
);

cap_pin <= 'L';

cappin : process
begin
	wait until cap_pin = '1';
	wait until cap_pin = 'L';
	
	wait for random_time(100ns, 2000ns, 1ns);
	cap_pin <= '0';
	
end process;
*/

/*
i2s_src : process(i2s_sck)
begin
	if rising_edge(i2s_sck) then
		i2s_ws_last <= i2s_ws;
		
		if i2s_ws_last /= i2s_ws then
			i2s_b <= 0;
		else
			if (i2s_b < 31) then
				i2s_b <= i2s_b + 1;
			end if;
		end if;
	end if;
	
	if falling_edge(i2s_sck) then
		i2s_sd <= i2s_data(31 - i2s_b);
	end if;
end process;

i2s : entity work.i2s(StereoMode)
generic map (
	CLK_MHZ 		=> 100.0,
	SCK_MHZ			=>  10.0,
	WORD_SIZE		=> 32,
	DATA_WIDTH		=> 18
)
port map (
	CLK_I			=> clk100,
	RST_I			=> '0',
	
	SCK_O			=> i2s_sck,
	WS_O			=> i2s_ws,
	SD_I			=> i2s_sd,
	
	DV_O			=> open,
	DATA_O			=> open
);
*/
/*
source : entity work.linear_ccd(tcd1304)
generic map (
	CHANNELS		=> 1,
	WIDTH			=> 8
)
port map (
	CLK_I			=> clk100,
	RST_I			=> '0',

	LPF_I			=> int2vec(10, 16),
	TRIGGER_I		=> trigger,

	-- Sensor Interface
	CTL_O			=> open,
	
	CS_O			=> open,
	SCK_O			=> open,
	SDO_I			=> "000",
	
	EXPOSING_O		=> open,
	
	-- AXI Master
	M_AXIS_ACLK_O	=> open,
	M_AXIS_TVALID_O	=> open,
	M_AXIS_TLAST_O	=> open,
	M_AXIS_TDATA_O	=> open,
	M_AXIS_TUSER_O	=> open,
	M_AXIS_TREADY_I	=> '1'
);
*/

end Behavioral;
