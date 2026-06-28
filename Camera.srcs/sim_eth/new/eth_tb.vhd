library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use work.util_eth.all;
use work.util.all;

entity eth_tb is
Generic (
	SIMULATION			: boolean := TRUE;
	UART_BAUDRATE		: integer := 921600;
	CWD					: string := "V:/vhdl/modularCamera/Camera.srcs/sim_eth/new/"
--  CWD                 : string := "D:/Documents/Code/vhdl/modularCamera/Camera.srcs/sim_eth/new/"
);
--  Port ( );
end eth_tb;

architecture Testbench of eth_tb is

signal clk50			: std_logic := '0';
signal clk100			: std_logic := '0';

signal sens_clk			: std_logic := '0';
signal sens_trig		: std_logic := '0';
signal sens_dval		: std_logic := '0';
signal sens_data		: std_logic_vector(31 downto 0) := (others => '0');
signal sens_gpio		: std_logic_vector( 2 downto 0) := (others => 'Z');
signal sens_cs			: std_logic := '0';
signal sens_sck			: std_logic := '0';
signal sens_miso		: std_logic := '0';
signal sens_mosi		: std_logic := '0';

-- ETH

signal phy_int_pd	: STD_LOGIC := '0';						-- Default: PowerDown, active low input on PHY, pulled up
	
signal phy_mdio		: STD_LOGIC := 'Z';
signal phy_mdc		: STD_LOGIC := '0';
	
signal phy_txck		: STD_LOGIC := '0';
signal phy_txctl	: STD_LOGIC := '0';
signal phy_txerr	: STD_LOGIC := '0';
signal phy_tx		: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	
signal phy_rxck		: STD_LOGIC := '0';
signal phy_rxctl	: STD_LOGIC := '0';
signal phy_rxerr	: STD_LOGIC := '0';
signal phy_rx		: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	
constant dst_mac	: std_logic_vector(47 downto 0) := x"DEADBEEFC0DE";
constant src_mac	: std_logic_vector(47 downto 0) := x"08002768c935";
constant dst_ip		: std_logic_vector(31 downto 0) := byte_reverse(ip2vec(192,168,178,100));
constant src_ip		: std_logic_vector(31 downto 0) := byte_reverse(ip2vec(192,168,178,131));
constant src_port 	: std_logic_vector(15 downto 0) := x"1000";
constant dst_port	: std_logic_vector(15 downto 0) := x"1000";

procedure cmd_send(
				cmd : string;
				signal clk : in std_logic;
				signal dv : out std_logic;
				signal data : out std_logic_vector(7 downto 0)
			)
is
	variable payload : array8_t(0 to cmd'length-1);
begin
	for i in 0 to cmd'length-1 loop
		payload(i) := char2vec(cmd(i+1));
	end loop;
	
	udp_send(dst_mac, src_mac, dst_ip, src_ip, src_port, dst_port, payload, clk, dv, data);
end;

begin

sim : process
begin
	wait for 5us;
	
	cmd_send("{R05}", phy_rxck, phy_rxctl, phy_rx);
	wait for 1us;
			
	wait;
end process;

clk_50 : process
begin
	clock(50.0, 0ns, clk50);
end process;

clk_100 : process
begin
	clock(100.0, 3ns, clk100);
end process;

clk_125 : process
begin
	clock(125.0, 0ns, phy_rxck);
end process;

spi : process(sens_sck)
begin
	if rising_edge(sens_sck) then
		sens_miso <= random_bit;
	end if;
end process;

sensor : entity work.aisc110c_sim
generic map (
	FILE_BASE		=> CWD & "test",
	FILE_EXT		=> ".pgm",
	WIDTH			=> 80,
	HEIGHT			=> 120,
	CHANNELS		=> 4,
	BPP				=> 8,
	PREAMBLE		=> 2,
	INTERLEAVED		=> false,
	SCALE			=> 1
)
port map (
	CLK_I			=> clk100,
	RST_I			=> '0',
	
	TRIGGER_I		=> sens_gpio(0),
	
	CLK_O			=> sens_clk,
	DVAL_O			=> sens_dval,
	FSYNC_O			=> sens_gpio(2), -- GPIO1 has no contact on Sensor PCBv1
	DATA_O			=> sens_data	
);

cam : entity work.camera_aisc110c_eth
generic map (
	UART_BAUDRATE	=> UART_BAUDRATE,
	SIMULATION		=> SIMULATION
)
port map (
	CLK50_I			=> clk50,
	
	-- Flash
	FLASH_CS_O		=> open,
--	FLASH_SCK_O		=> open,
	FLASH_DQ_IO		=> open,
	
	PHY_RST_O		=> open,
	PHY_INT_PD_O	=> open,
	PHY_LED_O		=> open,
	
	PHY_MD_IO		=> open,
	PHY_MDC_O		=> open,
	
	PHY_TXCK_O		=> phy_txck,
	PHY_TXCTL_O		=> phy_txctl,
	PHY_TXERR_O		=> phy_txerr,
	PHY_TX_O		=> phy_tx,
	
	PHY_RXCK_I		=> phy_rxck,
	PHY_RXCTL_I		=> phy_rxctl,
	PHY_RXERR_I		=> phy_rxerr,
	PHY_RX_I		=> phy_rx,
				
	-- Sensor
	SENS_CLOCK_I	=> sens_clk,
	SENS_DVAL_I		=> sens_dval,
	SENS_DATA_I		=> sens_data,
	
	SENS_GP_IO		=> sens_gpio,
	SENS_CS_O		=> sens_cs,
	SENS_SCK_O		=> sens_sck,
	SENS_MOSI_O		=> sens_mosi,
	SENS_MISO_I		=> sens_miso,
	
	-- Misc.
	LED_O			=> open	
);

end Testbench;
