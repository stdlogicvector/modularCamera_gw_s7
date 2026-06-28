library IEEE, UNISIM, XPM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use XPM.vcomponents.all;
use work.types.all;
use work.util.all;

entity camera_aisc110c_eth is
generic (
	VERSION			: integer := 16#0101#;
	BUILD			: integer := 1;
	BUILDTIME		: integer := 0;			-- Set by TCL during Synthesis
	VARIANT			: string  := "AISC1101";
	INTERFACE		: string  := "ETH";
	MAC_ADDR		: std_logic_vector(47 downto 0) := mac2vec(x"DE",x"AD",x"BE",x"EF",x"C0",x"DE");
	IP_ADDR			: std_logic_vector(31 downto 0) := ip2vec(192,168,178,100);
	FIXED_MAC		: boolean := TRUE;
	UART_BAUDRATE	: integer := 921600;
	UART_FLOW_CTRL	: boolean := FALSE;
	SIMULATION		: boolean := FALSE
);
port (
	CLK50_I			: in	STD_LOGIC;
	
	-- Flash
	FLASH_CS_O		: out	STD_LOGIC := '1';
--	FLASH_SCK_O		: out	STD_LOGIC := '0';
	FLASH_DQ_IO		: inout	STD_LOGIC_VECTOR(3 downto 0) := (others => 'Z');
	
	-- PHY
	PHY_RST_O		: out	STD_LOGIC := '0';						-- Hold in reset per default
	PHY_INT_PD_O	: out	STD_LOGIC := '1';						-- Default: PowerDown, active low input on PHY, pulled up
	PHY_LED_O		: out	STD_LOGIC := '0';
	
	PHY_MD_IO		: inout STD_LOGIC := 'Z';
	PHY_MDC_O		: out	STD_LOGIC := '0';
	
	PHY_TXCK_O		: out	STD_LOGIC := '0';
	PHY_TXCTL_O		: out	STD_LOGIC := '0';
	PHY_TXERR_O		: out	STD_LOGIC := '0';
	PHY_TX_O		: out	STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	
	PHY_RXCK_I		: in	STD_LOGIC := '0';
	PHY_RXCTL_I		: in	STD_LOGIC := '0';
	PHY_RXERR_I		: in	STD_LOGIC := '0';
	PHY_RX_I		: in	STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
		
	-- AISC110C
	SENS_CLOCK_I	: in	STD_LOGIC;
	SENS_DVAL_I		: in	STD_LOGIC;
	SENS_DATA_I		: in	STD_LOGIC_VECTOR(31 downto 0);
	
	SENS_GP_IO		: inout	STD_LOGIC_VECTOR(2 downto 0) := (others => 'Z');
	
	SENS_EN_O		: out	STD_LOGIC := '0';
	
	SENS_CS_O		: out	STD_LOGIC := '1';
	SENS_SCK_O		: out	STD_LOGIC := '0';
	SENS_MOSI_O		: out	STD_LOGIC := '0';
	SENS_MISO_I		: in	STD_LOGIC;
	
	-- Misc.
	LED_O			: out	STD_LOGIC := '0';
	DBG_O			: out	STD_LOGIC_VECTOR(1 downto 0) := (others => '0')
);
end camera_aisc110c_eth;

architecture toplevel of camera_aisc110c_eth is

constant SYS_CLK_FREQ	: real := 100.0;
constant ETH_CLK_FREQ	: real := 125.0;

constant UDP_PORTS		: natural := 2;
constant UDP_CMD		: natural := 0; -- Highest Priority
constant UDP_FRAME		: natural := 1;

constant UDP_PORT_CMD	: integer := 16#1000#;
constant UDP_PORT_FRAME	: integer := 16#1001#;

-- Clocks
signal clk100			: std_logic := '0';
signal rst100			: std_logic := '0';
signal clk125			: std_logic;
signal rst125			: std_logic := '1';
signal clk_ready		: std_logic := '0';

-- LED
signal led_counter		: integer range 0 to 50e6-1 := 0;
signal led_state		: std_logic := '0';

-- Trigger
signal gen_trigger		: std_logic := '0';
signal trigger			: std_logic := '0';

-- Image Pipeline
constant PIXEL_WIDTH	: integer := 8;
constant PIXEL_CHANNELS	: integer := 4;
constant DATA_WIDTH		: integer := PIXEL_WIDTH * PIXEL_CHANNELS;
constant FIFO_DEPTH		: integer := 2048;

signal sens_aclock		: std_logic;
signal sens_tvalid		: std_logic;
signal sens_tlast		: std_logic;
signal sens_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal sens_tuser		: std_logic_vector(1 downto 0);

signal sens_trigger		: std_logic;
signal sens_dv          : std_logic;
signal sens_sync		: std_logic;

signal test_aclock		: std_logic;
signal test_tvalid		: std_logic;
signal test_tlast		: std_logic;
signal test_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal test_tuser		: std_logic_vector(1 downto 0);

signal srcsel			: std_logic;

signal mux_aclock		: std_logic;
signal mux_tvalid		: std_logic;
signal mux_tlast		: std_logic;
signal mux_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal mux_tuser		: std_logic_vector(1 downto 0);
signal mux_0_tready		: std_logic;
signal mux_1_tready		: std_logic;

signal meta_aclock		: std_logic;
signal meta_tvalid		: std_logic;
signal meta_tlast		: std_logic;
signal meta_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal meta_tuser		: std_logic_vector(1 downto 0);
signal meta_tready		: std_logic;

signal fifo_tvalid		: std_logic;
signal fifo_tlast		: std_logic;
signal fifo_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal fifo_tuser		: std_logic_vector(1 downto 0);
signal fifo_tready		: std_logic;

signal fifo_threshold	: std_logic;

signal width_tvalid		: std_logic;
signal width_tlast		: std_logic;
signal width_tdata		: std_logic_vector(7 downto 0);
signal width_tuser		: std_logic_vector(1 downto 0);
signal width_tready		: std_logic;

signal udp_tready		: std_logic;

-- Metadata
signal timestamp		: std_logic_vector(31 downto 0);
signal framenr			: std_logic_vector(31 downto 0);
signal linenr			: std_logic_vector(15 downto 0);
signal sync_timestamp	: std_logic_vector(31 downto 0);
signal sync_framenr		: std_logic_vector(31 downto 0);

-- Registers
constant NR_OF_REGS		: integer := 32;

signal reg_dv			: std_logic_vector(NR_OF_REGS-1 downto 0);
signal reg				: array16_t(0 to NR_OF_REGS-1);

signal reg_ack			: std_logic;
signal reg_addr			: std_logic_vector( 7 downto 0);
signal reg_data_r		: std_logic_vector(15 downto 0);
signal reg_data_w		: std_logic_vector(15 downto 0);
signal reg_write		: std_logic := '0';
signal reg_read			: std_logic := '0';

-- Sensor Register
signal sens_busy		: std_logic := '0';
signal sens_done		: std_logic := '0';

signal sens_addr		: std_logic_vector(15 downto 0);
signal sens_data_r		: std_logic_vector(15 downto 0);
signal sens_data_w		: std_logic_vector(15 downto 0);
signal sens_write		: std_logic := '0';
signal sens_read		: std_logic := '0';

-- Sensor SPI
signal sens_spi_busy		: std_logic := '0';
signal sens_spi_done		: std_logic := '0';
signal sens_spi_write		: std_logic := '0';
signal sens_spi_burst		: std_logic := '0';
signal sens_spi_last		: std_logic := '0';
signal sens_spi_addr		: std_logic_vector( 7 downto 0);
signal sens_spi_data_out	: std_logic_vector(15 downto 0);
signal sens_spi_data_in 	: std_logic_vector(15 downto 0);

-- SPI
signal spi_send 			: std_logic;
signal spi_cont 			: std_logic;
signal spi_keep				: std_logic;
signal spi_busy 			: std_logic;
signal spi_slave 			: std_logic_vector(0 downto 0);

signal spi_tx 				: std_logic_vector(7 downto 0);
signal spi_rx 				: std_logic_vector(7 downto 0);

-- ETHERNET
signal gmii_txd				: std_logic_vector(7 downto 0);
signal gmii_tx_dv			: std_logic;
signal gmii_tx_er			: std_logic;

signal gmii_rxd				: std_logic_vector(7 downto 0);
signal gmii_rx_dv			: std_logic;
signal gmii_rx_empty		: std_logic;
signal gmii_rx_er			: std_logic;

signal eth_src_mac			: std_logic_vector(47 downto 0);

-- UDP
signal udp_rx_done			: std_logic;
signal udp_rx_dv			: std_logic;
signal udp_rx_data			: std_logic_vector(7 downto 0);
signal udp_rx_src_ip		: std_logic_vector(31 downto 0);
signal udp_rx_src_mac		: std_logic_vector(47 downto 0);
signal udp_rx_src_port		: std_logic_vector(15 downto 0);
signal udp_rx_dst_port		: std_logic_vector(15 downto 0);

signal udp_tx_dv			: std_logic;
signal udp_tx_dvs			: std_logic_vector(UDP_PORTS-1 downto 0) := (others => '0');
signal udp_tx_data			: std_logic_vector(7 downto 0);
signal udp_tx_dst_ip		: std_logic_vector(31 downto 0);
signal udp_tx_dst_mac		: std_logic_vector(47 downto 0);
signal udp_tx_src_port		: std_logic_vector(15 downto 0);
signal udp_tx_dst_port		: std_logic_vector(15 downto 0);
signal udp_tx_data_size		: std_logic_vector(15 downto 0);

signal udp_tx_start			: std_logic := '0';
signal udp_tx_starts		: std_logic_vector(UDP_PORTS-1 downto 0) := (others => '0');
signal udp_tx_ready			: std_logic;
signal udp_tx_busy			: std_logic;
signal udp_tx_rts			: std_logic_vector(UDP_PORTS-1 downto 0) := (others => '0');
signal udp_tx_busies		: std_logic_vector(UDP_PORTS-1 downto 0);

signal macip_set			: std_logic;
signal udp_frame_tx_dst_ip	: std_logic_vector(31 downto 0) := (others => '0');
signal udp_frame_tx_dst_mac	: std_logic_vector(47 downto 0) := (others => '0');

-- UART		
constant UART_CMD_BITS		: integer := 8;
constant UART_CMD_MAX_ARGS	: integer := 4;

signal uart_arb_nack	: std_logic;
signal uart_arb_ack		: std_logic;

signal uart_tx_done		: std_logic;

signal uart_rx_busy		: std_logic;
signal uart_tx_busy		: std_logic;

signal uart_decoder_rx_busy		: std_logic;
signal uart_decoder_tx_busy		: std_logic;

signal uart_rts			: std_logic;
signal uart_put			: std_logic;
signal uart_put_ack		: std_logic;
signal uart_put_char	: std_logic_vector(7 downto 0);
signal uart_put_full	: std_logic;

signal uart_get			: std_logic;
signal uart_get_ack		: std_logic;
signal uart_get_char	: std_logic_vector(7 downto 0);
signal uart_get_empty	: std_logic;

-- UART CMD
signal cmd_busy			: std_logic;

signal uart_new_cmd		: std_logic;
signal uart_cmd_ack		: std_logic;
signal uart_cmd_nack	: std_logic;
signal uart_cmd_id		: std_logic_vector(UART_CMD_BITS-1 downto 0);
signal uart_cmd_args	: std_logic_vector((UART_CMD_MAX_ARGS*UART_CMD_BITS)-1 downto 0);

signal uart_new_ack		: std_logic;
signal uart_new_nack	: std_logic;
signal uart_new_done	: std_logic;

signal uart_new_reply	: std_logic;
signal uart_long_reply	: std_logic;
signal uart_reply_ack	: std_logic;
signal uart_reply_id	: std_logic_vector(UART_CMD_BITS-1 downto 0);
signal uart_reply_args	: std_logic_vector((UART_CMD_MAX_ARGS*UART_CMD_BITS)-1 downto 0);
signal uart_reply_argn	: std_logic_vector(clogb2(UART_CMD_MAX_ARGS+1)-1 downto 0);

begin

-- Debug ----------------------------------------------------------------------

DBG_O <= (
--	0	=> sens_trigger,
--	1	=> sens_tvalid,
--	0	=> sens_tuser(0) OR sens_tuser(1) OR sens_sync, --sens_tlast,
--	1	=> sens_tvalid
    others => '0'
);

-- Clocking -------------------------------------------------------------------

clk_gen : entity work.clk_gen
generic map (
	CLK_IN_PERIOD	=> 20.0,	-- 50MHz
	DIFF_CLK_IN		=> false,
	DIVCLK_DIVIDE	=> 1,
	CLKFB_MULT		=> 20.0,
	CLK_OUT_DIVIDE	=> ( 0 => 10.0, 1 => 8.0, others => 0.0 )
)
port map (
	CLK_Ip     => CLK50_I,
	
	CLK0_O	   => clk100,	-- 50MHz * 20 / 10 = 100MHz
	CLK1_O     => clk125,	-- 50MHz * 20 /  8 = 125MHz
		
	LOCKED_O   => clk_ready
);

rst100 <= NOT clk_ready;
rst125 <= NOT clk_ready;

-- LED 1Hz Blink
led_blink : process(clk100)
begin
	if rising_edge(clk100) then
		if led_counter = 50e6-1 then
			led_counter	<= 0;
			led_state	<= NOT led_state;
		else
			led_counter	<= led_counter + 1;
		end if;
		
		LED_O <= led_state;
	end if;
end process;

PHY_LED_O <= NOT LED_O;

-- Trigger ---------------------------------------------------------------------

trigger_gen : entity work.trigger_gen
generic map (
	CLK_MHZ			=> 100.0,
	RESOLUTION_US	=> 1
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,
	
	ENABLE_I		=> reg(1)(0),
	
	TRIGGER_O		=> open,
	EXPOSE_O		=> gen_trigger,
	
	PERIOD_I		=> reg(3) & reg(2),
	EXPOSURE_I		=> reg(4)
);

trigger <= (reg(0)(0) and not reg(1)(0)) or gen_trigger;

-- Source ---------------------------------------------------------------------

SENS_EN_O <= reg(1)(4);

source : entity work.aisc110c
port map (
	RST_I			=> '0',

	TRIGGER_I		=> trigger AND NOT srcsel,

	-- Sensor Interface
	CLK_I			=> SENS_CLOCK_I,			
	DV_I			=> SENS_DVAL_I,
	DATA_I			=> SENS_DATA_I,
	GP_IO			=> SENS_GP_IO,
	
	-- AXI Master
	M_AXIS_ACLK_O	=> sens_aclock,
	M_AXIS_TVALID_O	=> sens_tvalid,
	M_AXIS_TLAST_O	=> sens_tlast,
	M_AXIS_TDATA_O	=> sens_tdata,
	M_AXIS_TUSER_O	=> sens_tuser,
	M_AXIS_TREADY_I	=> mux_0_tready
	
	-- Debug
	,TRIGGER_O		=> sens_trigger
	,DV_O           => sens_dv
	,SYNC_O			=> sens_sync
);

-- Test Image Generator -------------------------------------------------------

testimage : entity work.image_gen
generic map (
	PIXEL_WIDTH		=> PIXEL_WIDTH,
	PIXEL_CHANNELS	=> PIXEL_CHANNELS
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,

	TRIGGER_I		=> trigger AND srcsel,
	
	WIDTH_I			=> reg(5),
	HEIGHT_I		=> reg(6),
	
	HBLANK_I		=> reg(7),
		
	MODE_I			=> reg(1)(10 downto 8),
	PATTERN_I		=> reg(8),
	
	-- AXI Master
	M_AXIS_ACLOCK_O	=> test_aclock,
	M_AXIS_TVALID_O	=> test_tvalid,
	M_AXIS_TLAST_O	=> test_tlast,
	M_AXIS_TDATA_O	=> test_tdata,
	M_AXIS_TUSER_O	=> test_tuser,
	M_AXIS_TREADY_I	=> mux_1_tready
);

-- Source Selection -----------------------------------------------------------

srcsel <= reg(1)(1);

mux : entity work.axi_mux
generic map (
	DATA_WIDTH			=> DATA_WIDTH,
	OVERRIDE_0          => true        -- Clock from Sensor only active during capture
)
port map (	
	SELECT_I			=> srcsel,

	S_AXIS_ACLOCK_0_I	=> sens_aclock,
	S_AXIS_TVALID_0_I	=> sens_tvalid,
	S_AXIS_TLAST_0_I	=> sens_tlast,
	S_AXIS_TDATA_0_I	=> sens_tdata,
	S_AXIS_TUSER_0_I	=> sens_tuser,
	S_AXIS_TREADY_0_O	=> mux_0_tready,
	
	S_AXIS_ACLOCK_1_I	=> test_aclock,
	S_AXIS_TVALID_1_I	=> test_tvalid,
	S_AXIS_TLAST_1_I	=> test_tlast,
	S_AXIS_TDATA_1_I	=> test_tdata,
	S_AXIS_TUSER_1_I	=> test_tuser,
	S_AXIS_TREADY_1_O	=> mux_1_tready,
	
	M_AXIS_ACLOCK_O		=> mux_aclock,
	M_AXIS_TVALID_O		=> mux_tvalid,
	M_AXIS_TLAST_O		=> mux_tlast,
	M_AXIS_TDATA_O		=> mux_tdata,
	M_AXIS_TUSER_O		=> mux_tuser,
	M_AXIS_TREADY_I		=> meta_tready	
);

-- Metadata

meta_timestamp : entity work.timestamp
generic map (
	CLK_MHZ			=> 100.0,
	RESOLUTION_US	=> 1
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,
	
	ZERO_I			=> reg(0)(15),
	S_AXIS_TUSER_I	=> mux_tuser,
	TIMESTAMP_O		=> timestamp
);

meta_framenr : entity work.framecount
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,
	
	ZERO_I			=> reg(0)(15),
	
	S_AXIS_TUSER_I	=> mux_tuser,
	S_AXIS_TLAST_I	=> mux_tlast,
	
	FRAMENR_O		=> framenr,
	LINENR_O		=> linenr	
);

metadata : entity work.axi_metadata
generic map (
	PIXEL_WIDTH		=> PIXEL_WIDTH,
	PIXEL_CHANNELS	=> PIXEL_CHANNELS
)
port map (
	RST_I			=> reg(0)(15),
	
	TIMESTAMP_I		=> timestamp,
	FRAMENR_I		=> framenr,
	USERDATA_I		=> reg(31),
	
	-- AXI Slave
	S_AXIS_ACLK_I	=> mux_aclock,
	S_AXIS_TVALID_I	=> mux_tvalid,
	S_AXIS_TLAST_I	=> mux_tlast,
	S_AXIS_TDATA_I	=> mux_tdata,
	S_AXIS_TUSER_I	=> mux_tuser,
	S_AXIS_TREADY_O	=> meta_tready,

	-- AXI Master
	M_AXIS_ACLK_O	=> meta_aclock,
	M_AXIS_TVALID_O	=> meta_tvalid,
	M_AXIS_TLAST_O	=> meta_tlast,
	M_AXIS_TDATA_O	=> meta_tdata,
	M_AXIS_TUSER_O	=> meta_tuser,
	M_AXIS_TREADY_I	=> fifo_tready
);

-- FIFO

fifo : entity work.axi_fifo
generic map (
	CLOCKING_MODE	=> "independent_clock",
	DATA_WIDTH		=> DATA_WIDTH,
	DEPTH			=> FIFO_DEPTH
)
port map (
	nRST_I			=> not reg(0)(15),
	
	-- AXI Slave
	S_AXIS_ACLK_I	=> meta_aclock,
	S_AXIS_TVALID_I	=> meta_tvalid,
	S_AXIS_TLAST_I	=> meta_tlast,
	S_AXIS_TDATA_I	=> meta_tdata,
	S_AXIS_TUSER_I	=> meta_tuser,
	S_AXIS_TREADY_O	=> fifo_tready,

	-- AXI Master
	M_AXIS_ACLK_I	=> clk125,
	M_AXIS_TVALID_O	=> fifo_tvalid,
	M_AXIS_TLAST_O	=> fifo_tlast,
	M_AXIS_TDATA_O	=> fifo_tdata,
	M_AXIS_TUSER_O	=> fifo_tuser,
	M_AXIS_TREADY_I	=> width_tready,
	
	THRESHOLD_I		=> "0" & reg(5)(clogb2(FIFO_DEPTH) downto 1),
	THRESHOLD_O		=> fifo_threshold
);

width : entity work.axi_width
generic map (
	IN_WIDTH		=> DATA_WIDTH,
	OUT_WIDTH		=> 8
)
port map (
	AXIS_ACLK_I		=> clk125,
	RST_I			=> rst125,	

	-- AXI Slave
	S_AXIS_TVALID_I	=> fifo_tvalid,
	S_AXIS_TLAST_I	=> fifo_tlast,
	S_AXIS_TDATA_I	=> fifo_tdata,
	S_AXIS_TUSER_I	=> fifo_tuser,
	S_AXIS_TREADY_O	=> width_tready,

	-- AXI Master
	M_AXIS_TVALID_O	=> width_tvalid,
	M_AXIS_TLAST_O	=> width_tlast,
	M_AXIS_TDATA_O	=> width_tdata,
	M_AXIS_TUSER_O	=> width_tuser,
	M_AXIS_TREADY_I	=> udp_tready
);

output : entity work.udp_frame_transmitter
generic map (
	PORT_NR			=> UDP_PORT_FRAME
)
port map (
	CLK_I			=> clk125,
	RESET_I			=> rst125,
	
	TX_START_O		=> udp_tx_starts(UDP_FRAME),
	TX_READY_I		=> udp_tx_ready,
	TX_RTS_O		=> udp_tx_rts(UDP_FRAME),
	TX_BUSY_I		=> udp_tx_busies(UDP_FRAME),
	
	TX_DV_O			=> udp_tx_dvs(UDP_FRAME),
	TX_DATA_O		=> udp_tx_data,
	TX_DST_IP_O		=> udp_tx_dst_ip,
	TX_DST_MAC_O	=> udp_tx_dst_mac,
	TX_SRC_PORT_O	=> udp_tx_src_port,
	TX_DST_PORT_O	=> udp_tx_dst_port,
	TX_DATA_SIZE_O	=> udp_tx_data_size,
	
	AVAIL_I			=> fifo_threshold,
	
	S_AXIS_TVALID_I	=> width_tvalid,
	S_AXIS_TLAST_I	=> width_tlast,
	S_AXIS_TDATA_I	=> width_tdata,
	S_AXIS_TUSER_I	=> width_tuser,
	S_AXIS_TREADY_O	=> udp_tready,

	PKT_BPP_I		=> int2vec(8, 8),
	PKT_LINE_I		=> linenr,
	PKT_FRAME_I		=> framenr(15 downto 0),
 	PKT_LEN_I		=> reg(5),
	
	FRM_DST_MAC_I	=> udp_frame_tx_dst_mac,
 	FRM_DST_IP_I	=> udp_frame_tx_dst_ip,
	FRM_DST_PORT_I	=> reg(10)
);

-- Registers ------------------------------------------------------------------

registers : entity work.registers
generic map (
	NR_OF_REGS 		=> NR_OF_REGS,
	DEFAULT_VALUE	=> (
						1		=> x"0002",							-- Select Internal Source by default
						2		=> int2vec(26, 16),					-- Trigger Period in us (Lo)
						3		=> int2vec(0, 16),					-- Trigger Period in us (Hi)
						4		=> int2vec(10, 16),					-- Exposure Time in us
						5		=> int2vec(80/PIXEL_CHANNELS, 16),	-- Test Image Width
						6		=> int2vec(120, 16),				-- Test Image Height
						7		=> int2vec(0, 16),					-- Test Image H Blank in us
						8		=> x"1234",							-- Test Image Pattern
						9		=> int2vec(10, 8) & int2vec(1, 8),	-- Output V/H Blank
						10		=> int2vec(UDP_PORT_FRAME, 16),		
						others	=> x"0000"
						)
)
port map (
	CLK_I			=> clk125,
	RST_I			=> rst125,
	
	ACK_O			=> reg_ack,
	WRITE_I			=> reg_write,
	READ_I			=> reg_read,
	ADDR_I			=> reg_addr,
	DATA_O			=> reg_data_r,
	DATA_I			=> reg_data_w,
	
	-- Read/Write Registers
	REG_DV_O		=> reg_dv,
	REGISTERS_O		=> reg,
	
	-- Read Only Registers
	REG_DV_I		=> (
				others => '0'
	),
	REGISTERS_I		=> (
				 
					29	=> int2vec(integer(SYS_CLK_FREQ), 16),	-- Sys Clk (MHz)
					30	=> int2vec(VERSION, 16),				-- FPGA VERSION
					31	=> int2vec(BUILD, 16),					-- FPGA BUILD
				others	=> x"0000"
	)
);

-- Ethernet --------------------------------------------------------------

PHY_RST_O 	<= clk_ready;	-- Phy reset is Active Low

gmii : entity work.GMII_buffer
generic map (
	USE_CLK90			=> FALSE,
	INV_CLK				=> TRUE
)
port map (
	CLK_I				=> clk125,
	RESET_I				=> rst125,
	
	GMII_TX_CLK_O		=> PHY_TXCK_O,
	GMII_TXD_O			=> PHY_TX_O,
	GMII_TX_CTL_O		=> PHY_TXCTL_O,
	GMII_TX_ERR_O		=> PHY_TXERR_O,
	              
	GMII_RX_CLK_I		=> PHY_RXCK_I,
	GMII_RXD_I			=> PHY_RX_I,
	GMII_RX_CTL_I		=> PHY_RXCTL_I,
	GMII_RX_ERR_I		=> PHY_RXERR_I,
	
	GMII_TXD_I		 	=> gmii_txd,
	GMII_TX_DV_I		=> gmii_tx_dv,
	GMII_TX_ER_I		=> gmii_tx_er,
	              
	GMII_RXD_O		 	=> gmii_rxd,
	GMII_RX_DV_O		=> gmii_rx_dv,
	GMII_RX_EMPTY_O		=> gmii_rx_empty,
	GMII_RX_ER_O		=> gmii_rx_er
);

udp_tx_start <= or_reduce(udp_tx_starts);
udp_tx_dv <= or_reduce(udp_tx_dvs);

eth_mac : entity work.eth_mac
generic map (
	FIXED_MAC			=> FIXED_MAC,
	MAC_ADDR			=> MAC_ADDR,
	IP_ADDR				=> IP_ADDR
)
port map (
	CLK_I				=> clk125,
	RESET_I				=> rst125,
	
	PHY_RXD_I			=> gmii_rxd,
	PHY_RX_DV_I			=> gmii_rx_dv,
	PHY_RX_ER_I			=> gmii_rx_er,
    PHY_RX_EMPTY_I      => gmii_rx_empty,

	PHY_TXD_O			=> gmii_txd,
	PHY_TX_EN_O			=> gmii_tx_dv,
	PHY_TX_ER_O			=> gmii_tx_er,
	
	ETH_SRC_MAC_O		=> eth_src_mac,
	
	-- UDP interface
	UDP_RX_DONE_O		=> udp_rx_done,
	UDP_RX_DV_O			=> udp_rx_dv,
	UDP_RX_DATA_O		=> udp_rx_data,
	UDP_RX_SRC_IP_O		=> udp_rx_src_ip,
	UDP_RX_SRC_MAC_O	=> udp_rx_src_mac,
	UDP_RX_SRC_PORT_O	=> udp_rx_src_port,
	UDP_RX_DST_PORT_O	=> udp_rx_dst_port,
	
	UDP_TX_START_I		=> udp_tx_start,
	UDP_TX_READY_O		=> udp_tx_ready,
	UDP_TX_BUSY_O		=> udp_tx_busy,
	
	UDP_TX_DV_I			=> udp_tx_dv,
	UDP_TX_DATA_I		=> udp_tx_data,
	UDP_TX_DST_IP_I		=> udp_tx_dst_ip,
	UDP_TX_DST_MAC_I	=> udp_tx_dst_mac,
	UDP_TX_SRC_PORT_I	=> udp_tx_src_port,
	UDP_TX_DST_PORT_I	=> udp_tx_dst_port,
	UDP_TX_DATA_SIZE_I	=> udp_tx_data_size
);

udp_arbiter : entity work.udp_arbiter
generic map (
	PORTS 				=> UDP_PORTS
)
port map (
	CLK_I 				=> clk125,
	RESET_I				=> rst125,
	
	UDP_TX_BUSY_I		=> udp_tx_busy,
	PORT_TX_RTS_I		=> udp_tx_rts,
	PORT_TX_BUSY_O		=> udp_tx_busies
);

-- UART -----------------------------------------------------------------------

udp_uart : entity work.udp_uart
generic map (
	PORT_NR				=> UDP_PORT_CMD
)
port map (
	CLK_I				=> clk125,
	RESET_I				=> rst125,
	
	RX_BUSY_O			=> uart_rx_busy,
	TX_BUSY_O			=> uart_tx_busy,
	
	UDP_RX_DONE_I		=> udp_rx_done,
	UDP_RX_DV_I			=> udp_rx_dv,
	UDP_RX_DATA_I		=> udp_rx_data,
	UDP_RX_SRC_IP_I		=> udp_rx_src_ip,
	UDP_RX_SRC_MAC_I	=> udp_rx_src_mac,
	UDP_RX_SRC_PORT_I	=> udp_rx_src_port,
	UDP_RX_DST_PORT_I	=> udp_rx_dst_port,
	
	UDP_TX_START_O		=> udp_tx_starts(UDP_CMD),
	UDP_TX_READY_I		=> udp_tx_ready,
	UDP_TX_RTS_O		=> udp_tx_rts(UDP_CMD),
	UDP_TX_BUSY_I		=> udp_tx_busies(UDP_CMD),
	
	UDP_TX_DV_O			=> udp_tx_dvs(UDP_CMD),
	UDP_TX_DATA_O		=> udp_tx_data,
	UDP_TX_DST_IP_O		=> udp_tx_dst_ip,
	UDP_TX_DST_MAC_O	=> udp_tx_dst_mac,
	UDP_TX_SRC_PORT_O	=> udp_tx_src_port,
	UDP_TX_DST_PORT_O	=> udp_tx_dst_port,
	UDP_TX_DATA_SIZE_O	=> udp_tx_data_size,
	
	RTS_I				=> uart_rts,
	PUT_CHAR_I			=> uart_put,
	PUT_ACK_O			=> uart_put_ack,
	TX_CHAR_I			=> uart_put_char,
	TX_FULL_O			=> uart_put_full,
	
	GET_CHAR_I			=> uart_get,
	GET_ACK_O			=> uart_get_ack,
	RX_CHAR_O			=> uart_get_char,
	RX_EMPTY_O			=> uart_get_empty
);

uart_decoder : entity work.uart_decoder
generic map (
	DATA_BITS 		=> UART_CMD_BITS,
	MAX_ARGS		=> UART_CMD_MAX_ARGS,
	PKT_MODE		=> true
)
port map (
	CLK_I			=> clk125,
	RST_I			=> rst125,
	
	RX_BUSY_I		=> uart_rx_busy,
	TX_BUSY_I		=> uart_tx_busy,
	
	TX_BUSY_O		=> uart_decoder_tx_busy,
	RX_BUSY_O		=> uart_decoder_rx_busy,
	
	RTS_O			=> uart_rts,
	PUT_CHAR_O		=> uart_put,
	PUT_ACK_I		=> uart_put_ack,
	TX_CHAR_O		=> uart_put_char,
	TX_FULL_I		=> uart_put_full,
	
	GET_CHAR_O		=> uart_get,
	GET_ACK_I		=> uart_get_ack,
	RX_CHAR_I		=> uart_get_char,
	RX_EMPTY_I		=> uart_get_empty,
	
	NEW_CMD_O		=> uart_new_cmd,
	CMD_ACK_I		=> uart_cmd_ack,
	CMD_NACK_I		=> uart_cmd_nack,
	CMD_ID_O		=> uart_cmd_id,
	CMD_ARGS_O		=> uart_cmd_args,
	
	NEW_ACK_I		=> uart_new_ack,
	NEW_NACK_I		=> uart_new_nack,
	NEW_DONE_I		=> uart_new_done,
	
	NEW_REPLY_I		=> uart_new_reply,
	LONG_REPLY_I	=> uart_long_reply,
	REPLY_ACK_O		=> uart_reply_ack,
	REPLY_ID_I		=> uart_reply_id,
	REPLY_ARGS_I	=> uart_reply_args,
	REPLY_ARGN_I	=> uart_reply_argn
);

cmd_decoder : entity work.uart_cmd_decoder
generic map (
	DATA_BITS 		=> UART_CMD_BITS,
	MAX_ARGS		=> UART_CMD_MAX_ARGS,
	USE_SENSOR		=> true,
	SENS_ADDR_BYTES	=> 2,
	SENS_DATA_BYTES	=> 2
)
port map (
	CLK_I			=> clk125,
	RESET_I			=> rst125,
	
	BUSY_O			=> cmd_busy,
	UART_BUSY_I		=> uart_decoder_tx_busy, 
	
	NEW_CMD_I		=> uart_new_cmd,
	CMD_ACK_O		=> uart_cmd_ack,
	CMD_NACK_O		=> uart_cmd_nack,
	CMD_ID_I		=> uart_cmd_id,
	CMD_ARGS_I		=> uart_cmd_args,
	
	NEW_ACK_O		=> uart_new_ack,
	NEW_NACK_O		=> uart_new_nack,
	NEW_DONE_O		=> uart_new_done,
	
	NEW_REPLY_O		=> uart_new_reply,
	LONG_REPLY_O	=> uart_long_reply,
	REPLY_ACK_I		=> uart_reply_ack,
	REPLY_ID_O		=> uart_reply_id,
	REPLY_ARGS_O	=> uart_reply_args,
	REPLY_ARGN_O	=> uart_reply_argn,
	
	-- Register
	REG_WRITE_O		=> reg_write,
	REG_ADDR_O		=> reg_addr,
	REG_DATA_I		=> reg_data_r,
	REG_DATA_O		=> reg_data_w,
	
	-- Sensor Register
	SENS_BUSY_I		=> sens_busy,
	SENS_DONE_I		=> sens_done,
	SENS_WRITE_O	=> sens_write,
	SENS_READ_O		=> sens_read,
	SENS_ADDR_O		=> sens_addr,
	SENS_DATA_I		=> sens_data_r,
	SENS_DATA_O		=> sens_data_w,
	
	MACIP_SET_O		=> macip_set
);

mod_macip : process(clk125)
begin
 	if rising_edge(clk125) then
 		if (macip_set = '1') then
 			udp_frame_tx_dst_mac	<=	udp_rx_src_mac;
 			udp_frame_tx_dst_ip		<=	udp_rx_src_ip;
 		end if;
	end if;
end process;

-- Sensor Control -------------------------------------------------------------

ctrl : entity work.aisc110c_ctrl
port map (
	CLK_I		=> clk125,
	RST_I		=> rst125,
	
	BUSY_O		=> sens_busy,
	DONE_O		=> sens_done,
	
	READ_I		=> sens_read,
	WRITE_I		=> sens_write,
	
	ADDR_I		=> sens_addr,
	DATA_I		=> sens_data_w,
	DATA_O		=> sens_data_r,
	
	SPI_BUSY_I	=> spi_busy,
	SPI_SEND_O	=> spi_send,
	SPI_CONT_O	=> spi_cont,
	SPI_KEEP_O	=> spi_keep,
	SPI_SLAVE_O	=> spi_slave,
	
	SPI_TX_O	=> spi_tx,
	SPI_RX_I	=> spi_rx
);

-- SPI ------------------------------------------------------------------------

spi : entity work.spi_master
generic map (
	SLAVES		=> 1,
	WIDTH		=> 8
)
port map (
	CLKDIV_I	=> x"04",	-- 125MHz / 8 = 15.625MHz (Max. for AISC110 = 15.625MHz)
	CPOL		=> '0',		-- Clock Idle = Low
	CPHA		=> '0',		-- Sample on Rising Edge
	
	CLK_I		=> clk125,
	RST_I		=> rst125,
	
	SEND_I		=> spi_send,
	CONT_I		=> spi_cont,
	KEEP_I		=> spi_keep,
	BUSY_O		=> spi_busy,
	SLAVE_I		=> spi_slave,

	TX_I		=> spi_tx,
	RX_O		=> spi_rx,
	
	CSN_O(0)	=> SENS_CS_O,
	
	SCK_O		=> SENS_SCK_O,
	MOSI_O		=> SENS_MOSI_O,
	MISO_I	 	=> SENS_MISO_I
);

end toplevel;
