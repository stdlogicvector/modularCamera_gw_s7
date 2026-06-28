library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.util.ALL;

entity eth_mac is
	Generic (
		FIXED_MAC		: boolean := true;
		MAC_ADDR		: std_logic_vector(47 downto 0) := x"00_11_22_33_44_55";
		IP_ADDR			: std_logic_vector(31 downto 0) 
	);
	Port(
		-- system signals
		CLK_I			: in std_logic;
		RESET_I			: in std_logic;

		-- GMII interface to ethernet PHY
		PHY_RXD_I		: in	std_logic_vector(7 downto 0);
		PHY_RX_DV_I		: in	std_logic;	-- 1 = normal data reception, 0 = idle
		PHY_RX_ER_I		: in	std_logic;
		PHY_RX_EMPTY_I  : in    std_logic; 
		
		PHY_TXD_O  		: out	std_logic_vector(7 downto 0) := (others => '0');
		PHY_TX_EN_O		: out	std_logic := '0';
		PHY_TX_ER_O		: out	std_logic := '0';
		
		ETH_SRC_MAC_O	: out	std_logic_vector(47 downto 0) := (others => '0');
		ETH_TYPE_O		: out	std_logic_vector(15 downto 0) := (others => '0');

		-- UDP interface
		UDP_RX_DONE_O		: out	std_logic := '0';
		UDP_RX_DV_O			: out	std_logic := '0';
		UDP_RX_DATA_O		: out	std_logic_vector( 7 downto 0) := (others => '0');
		UDP_RX_SRC_MAC_O	: out	std_logic_vector(47 downto 0);
		UDP_RX_SRC_IP_O		: out	std_logic_vector(31 downto 0);
		UDP_RX_SRC_PORT_O	: out	std_logic_vector(15 downto 0);
		UDP_RX_DST_PORT_O	: out	std_logic_vector(15 downto 0);
		
		UDP_TX_START_I		: in	std_logic;
		UDP_TX_READY_O		: out	std_logic := '0';
		UDP_TX_BUSY_O		: out	std_logic := '0';
		
		UDP_TX_DV_I			: in	std_logic;
		UDP_TX_DATA_I		: in	std_logic_vector( 7 downto 0);
		UDP_TX_DST_MAC_I	: in	std_logic_vector(47 downto 0);
		UDP_TX_DST_IP_I		: in	std_logic_vector(31 downto 0);
		UDP_TX_SRC_PORT_I	: in	std_logic_vector(15 downto 0);
		UDP_TX_DST_PORT_I	: in	std_logic_vector(15 downto 0);
		UDP_TX_DATA_SIZE_I	: in	std_logic_vector(15 downto 0)
		
		;DEBUG_O			: out	std_logic_vector(7 downto 0) := (others => '0')
	);
end eth_mac;

architecture Behavioral of eth_mac is
	signal mac_address			: std_logic_vector(47 downto 0) := MAC_ADDR;

	-- ethernet signals
	signal eth_rx_dv			: std_logic;
	signal eth_rx_data			: std_logic_vector(7 downto 0);
	signal eth_rx_type			: std_logic_vector(15 downto 0);
	signal eth_rx_src_mac		: std_logic_vector(47 downto 0);
    signal eth_busy             : std_logic;	
    signal eth_done             : std_logic;	
	
	signal eth_transmit			: std_logic := '0';
	signal eth_transmits		: std_logic_vector(1 downto 0) := (others => '0');
	signal eth_tx_busy			: std_logic;
	signal eth_tx_ready			: std_logic;
	signal eth_tx_dv			: std_logic := '0';
	signal eth_tx_dvs			: std_logic_vector(1 downto 0) := (others => '0');
	signal eth_tx_data			: std_logic_vector(7 downto 0);
	signal eth_tx_type			: std_logic_vector(15 downto 0);
	signal eth_tx_dst_mac		: std_logic_vector(47 downto 0);
	
	-- ipv4 signals
	signal ip4_rx_dv			: std_logic;
	signal ip4_rx_data			: std_logic_vector(7 downto 0);
	signal ip4_rx_proto			: std_logic_vector(7 downto 0);
	signal ip4_rx_data_size		: std_logic_vector(15 downto 0);
	signal ip4_rx_src_ip		: std_logic_vector(31 downto 0);
    signal ip4_busy             : std_logic;
	signal ip4_done             : std_logic;
	
	signal ip4_transmit			: std_logic := '0';
	signal ip4_transmits		: std_logic_vector(1 downto 0) := (others => '0');
	signal ip4_tx_ready			: std_logic;
	signal ip4_tx_busy			: std_logic;
	
	signal ip4_tx_dv			: std_logic := '0';
	signal ip4_tx_dvs			: std_logic_vector(1 downto 0) := (others => '0');
	signal ip4_tx_data			: std_logic_vector(7 downto 0);
	
	signal ip4_tx_dst_mac		: std_logic_vector(47 downto 0);
	signal ip4_tx_dst_ip		: std_logic_vector(31 downto 0);
	
	signal ip4_tx_proto			: std_logic_vector(7 downto 0);
	signal ip4_tx_data_size		: std_logic_vector(15 downto 0);
	
	-- arp signals
	signal arp_received			: std_logic;
	signal arp_tx_busy			: std_logic;
	signal arp_rx_src_mac		: std_logic_vector(47 downto 0);
	signal arp_rx_src_ip		: std_logic_vector(31 downto 0);
    signal arp_busy             : std_logic;

	-- icmp signals
	signal icmp_received		: std_logic;
	signal icmp_rx_dv			: std_logic;
	signal icmp_rx_data			: std_logic_vector(7 downto 0);
	signal icmp_rx_header		: std_logic_vector(31 downto 0);
	signal icmp_tx_busy         : std_logic;
	signal icmp_tx_ready        : std_logic;
	signal icmp_rx_skip         : std_logic;
	
begin

---------------------------------------------------------------------------------------------
-- signal assignments
---------------------------------------------------------------------------------------------

eth_transmit	<= or_reduce(eth_transmits);
eth_tx_dv		<= or_reduce(eth_tx_dvs);

ip4_transmit	<= or_reduce(ip4_transmits);
ip4_tx_dv		<= or_reduce(ip4_tx_dvs);

---------------------------------------------------------------------------------------------
-- instances
---------------------------------------------------------------------------------------------

mac_fixed : if FIXED_MAC = true generate
	mac_address <= MAC_ADDR;
end generate;

mac_dynamic: if FIXED_MAC = false generate

addr: entity work.mac_addr
port map (
	CLK_I 		=> CLK_I,
	RESET_I		=> RESET_I,
	
	PREFIX_I	=> MAC_ADDR(23 downto 0),
	MAC_O		=> mac_address	
);

end generate;

eth_rx: entity work.eth_decoder
port map (
	CLK_I 		=> CLK_I,
	RESET_I		=> RESET_I,
	
	MAC_ADDR_I 	=> mac_address,
	
	PHY_RXD_I	=> PHY_RXD_I,
	PHY_RX_DV_I	=> PHY_RX_DV_I,
	PHY_RX_ER_I	=> PHY_RX_ER_I,
	PHY_RX_EMPTY => PHY_RX_EMPTY_I,
	
	DONE_O		=> eth_done,
	DV_O		=> eth_rx_dv,
	DATA_O		=> eth_rx_data,
	BUSY_O      => eth_busy,
	
	SRC_MAC_O	=> eth_rx_src_mac,
	ETHERTYPE_O	=> eth_rx_type
);

ETH_SRC_MAC_O	<= eth_rx_src_mac;
ETH_TYPE_O		<= eth_rx_type;

eth_tx : entity work.eth_encoder
port map (
	CLK_I		=> CLK_I,
	RESET_I		=> RESET_I,
	
	MAC_ADDR_I 	=> mac_address,
	
	PHY_TXD_O	=> PHY_TXD_O,
	PHY_TX_EN_O	=> PHY_TX_EN_O,
	PHY_TX_ER_O	=> PHY_TX_ER_O,
	
	START_I		=> eth_transmit,
	BUSY_O		=> eth_tx_busy,
	READY_O		=> eth_tx_ready,
	
	DV_I		=> eth_tx_dv,
	DATA_I		=> eth_tx_data,
	
	DST_MAC_I	=> eth_tx_dst_mac,
	ETHERTYPE_I	=> eth_tx_type
);

ip4_rx : entity work.ip4_decoder
generic map (
	IP_ADDR			=> IP_ADDR
)
port map (
	CLK_I			=> CLK_I,
	RESET_I			=> RESET_I,
	
	ETH_TYPE_I	 	=> eth_rx_type,
	ETH_DV_I		=> eth_rx_dv,
	ETH_DATA_I 		=> eth_rx_data,
	ETH_DONE_I      => eth_done,
	
	DONE_O			=> ip4_done,
	DV_O			=> ip4_rx_dv,
	DATA_O			=> ip4_rx_data,
	BUSY_O          => ip4_busy,
	
	SRC_IP_O		=> ip4_rx_src_ip,
	PROTOCOL_O		=> ip4_rx_proto,
	DATA_SIZE_O		=> ip4_rx_data_size
);

ip4_tx : entity work.ip4_encoder
generic map (
	IP_ADDR		=> IP_ADDR
)
port map (
	CLK_I		=> CLK_I,
	RESET_I		=> RESET_I,
	
	START_O		=> eth_transmits(0),
	BUSY_I		=> eth_tx_busy,
	READY_I		=> eth_tx_ready,
	
	DV_O		=> eth_tx_dvs(0),
	DATA_O		=> eth_tx_data,
	
	DST_MAC_O	=> eth_tx_dst_mac,
	ETHERTYPE_O	=> eth_tx_type,
	
	START_I		=> ip4_transmit,
	READY_O		=> ip4_tx_ready,
	BUSY_O		=> ip4_tx_busy,
	
	DV_I		=> ip4_tx_dv,
	DATA_I		=> ip4_tx_data,
	
	DST_MAC_I	=> ip4_tx_dst_mac,
	DST_IP_I	=> ip4_tx_dst_ip,
	
	PROTOCOL_I	=> ip4_tx_proto,
	DATA_SIZE_I	=> ip4_tx_data_size
);

arp_rx : entity work.arp_decoder
generic map (
	IP_ADDR		=> IP_ADDR
)
port map (
	CLK_I		=> CLK_I,
	RESET_I		=> RESET_I,
	
	MAC_ADDR_I 	=> mac_address,
	
	ETH_TYPE_I 	=> eth_rx_type,
	ETH_DV_I	=> eth_rx_dv,
	ETH_DATA_I 	=> eth_rx_data,
	ETH_DONE_I  => eth_done,
	
	DONE_O		=> arp_received,
	--DV_O		=> open,
	--DATA_O	=> open,
    BUSY_O      => arp_busy,	
	
	SRC_MAC_O	=> arp_rx_src_mac,
	SRC_IP_O	=> arp_rx_src_ip
);

arp_tx : entity work.arp_encoder
generic map (
	IP_ADDR		=> IP_ADDR
)
port map (
	CLK_I		=> CLK_I,
	RESET_I		=> RESET_I,
	
	MAC_ADDR_I 	=> mac_address,
	
	START_O		=> eth_transmits(1),
	BUSY_I		=> eth_tx_busy,
	READY_I		=> eth_tx_ready,
	
	DV_O		=> eth_tx_dvs(1),
	DATA_O		=> eth_tx_data,
	
	DST_MAC_O 	=> eth_tx_dst_mac,
	ETHERTYPE_O => eth_tx_type,
	
	START_I		=> arp_received,
	BUSY_O		=> arp_tx_busy,
	
	DST_MAC_I	=> arp_rx_src_mac,
	DST_IP_I	=> arp_rx_src_ip
);

icmp_rx : entity work.icmp_decoder
port map (
	CLK_I		=> CLK_I,
	RESET_I		=> RESET_I,
	
	IP4_DV_I	=> ip4_rx_dv,
	IP4_DATA_I	=> ip4_rx_data,
	IP4_PROTO_I	=> ip4_rx_proto,
	IP4_LENGTH_I=> ip4_rx_data_size,
	IP4_DONE_I  => ip4_done,
	
	DONE_O		=> icmp_received,
	DV_O		=> icmp_rx_dv,
	DATA_O		=> icmp_rx_data,
	
	HEADER_O	=> icmp_rx_header,
	
	SKIP_O      => icmp_rx_skip
);

icmp_tx : entity work.icmp_encoder
port map (
	CLK_I		=> CLK_I,
	RESET_I		=> RESET_I,
	
	START_O		=> ip4_transmits(0),
	BUSY_I		=> ip4_tx_busy,
	READY_I		=> ip4_tx_ready,
	
	DV_O		=> ip4_tx_dvs(0),
	DATA_O		=> ip4_tx_data,
	
	DST_IP_O	=> ip4_tx_dst_ip,
	DST_MAC_O	=> ip4_tx_dst_mac,
	PROTOCOL_O	=> ip4_tx_proto,
	LENGTH_O	=> ip4_tx_data_size,
	
	START_I		=> icmp_received,
	BUSY_O		=> icmp_tx_busy,
	READY_O		=> icmp_tx_ready,
	
	DV_I		=> icmp_rx_dv,
	DATA_I		=> icmp_rx_data,
	
	DST_MAC_I	=> eth_rx_src_mac,
	DST_IP_I	=> ip4_rx_src_ip,
	HEADER_I	=> icmp_rx_header
);

udp_rx : entity work.udp_decoder
port map (
	CLK_I		=> CLK_I,
	RESET_I		=> RESET_I,
	
	IP4_DV_I	=> ip4_rx_dv,
	IP4_DATA_I	=> ip4_rx_data,
	IP4_PROTO_I	=> ip4_rx_proto,
	IP4_LENGTH_I=> ip4_rx_data_size,
	IP4_DONE_I  => ip4_done,
	
	DONE_O		=> UDP_RX_DONE_O,
	DV_O		=> UDP_RX_DV_O,
	DATA_O		=> UDP_RX_DATA_O,
	
	SRC_PORT_O	=> UDP_RX_SRC_PORT_O,
	DST_PORT_O	=> UDP_RX_DST_PORT_O
);

UDP_RX_SRC_IP_O <= ip4_rx_src_ip;
UDP_RX_SRC_MAC_O <= eth_rx_src_mac;

udp_tx : entity work.udp_encoder
port map (
	CLK_I		=> CLK_I,
	RESET_I		=> RESET_I,
	
	START_O		=> ip4_transmits(1),
	BUSY_I		=> ip4_tx_busy,
	READY_I		=> ip4_tx_ready,
	
	DV_O		=> ip4_tx_dvs(1),
	DATA_O		=> ip4_tx_data,
	
	DST_IP_O	=> ip4_tx_dst_ip,
	DST_MAC_O  	=> ip4_tx_dst_mac,
	PROTOCOL_O 	=> ip4_tx_proto,
	LENGTH_O	=> ip4_tx_data_size,
	
	START_I		=> UDP_TX_START_I,
	BUSY_O		=> UDP_TX_BUSY_O,
	READY_O		=> UDP_TX_READY_O,
	
	DV_I		=> UDP_TX_DV_I,
	DATA_I		=> UDP_TX_DATA_I,
	
	DST_MAC_I	=> UDP_TX_DST_MAC_I,
	DST_IP_I	=> UDP_TX_DST_IP_I,
	SRC_PORT_I	=> UDP_TX_SRC_PORT_I,
	DST_PORT_I	=> UDP_TX_DST_PORT_I,
	LENGTH_I	=> UDP_TX_DATA_SIZE_I
);

end Behavioral;
