library IEEE, UNISIM, XPM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use XPM.vcomponents.all;
use work.types.all;
use work.util.all;

entity camera_python is
generic (
	VERSION			: integer := 16#0100#;
	BUILD			: integer := 1;
	TIMESTAMP		: integer := 0;			-- Set by TCL during Synthesis
	VARIANT			: string  := "PYTHON";
	INTERFACE		: string  := "USB";
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
	
	-- FX3
	FX3_CLOCK_O		: out	STD_LOGIC := '0';
	FX3_CTL_IO		: inout	STD_LOGIC_VECTOR( 3 downto 0) := (others => 'Z');
	FX3_DATA_O		: out	STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
		
	UART_TX_O		: out	STD_LOGIC := '1';
	UART_RX_I		: in	STD_LOGIC;
	UART_RTS_O		: out	STD_LOGIC := '1';
	UART_CTS_I		: in	STD_LOGIC := '1';
		
	-- PYTHON
	SENS_nRESET_O	: out	STD_LOGIC := '0'; -- Keep in Reset until init
	
	SENS_CLOCK_O	: out	STD_LOGIC := '0';
	SENS_CLOCKp_O	: out	STD_LOGIC := '0';
	SENS_CLOCKn_O	: out	STD_LOGIC := '1';
	
	SENS_CLOCKp_I	: in	STD_LOGIC;
	SENS_CLOCKn_I	: in	STD_LOGIC;
	SENS_SYNCp_I	: in	STD_LOGIC;
	SENS_SYNCn_I	: in	STD_LOGIC;
	SENS_DATAp_I	: in	STD_LOGIC_VECTOR(3 downto 0);
	SENS_DATAn_I	: in	STD_LOGIC_VECTOR(3 downto 0);
	
	SENS_TRIGGER_O	: out	STD_LOGIC_VECTOR(2 downto 0) := (others => '0');
	SENS_MONITOR_I	: in	STD_LOGIC_VECTOR(1 downto 0);
	
	SENS_EN_CLK_O	: out	STD_LOGIC := '0';
	SENS_EN_1V8_O	: out	STD_LOGIC := '0';
	SENS_EN_3V3_O	: out	STD_LOGIC := '0';
	SENS_EN_PIX_O	: out	STD_LOGIC := '0';
	
	SENS_nCS_O 		: out	STD_LOGIC := '1';
	SENS_SCK_O 		: out	STD_LOGIC := '0';
	SENS_MOSI_O 	: out	STD_LOGIC := '0';
	SENS_MISO_I		: in	STD_LOGIC;
		
	-- Misc.
	LED_O			: out	STD_LOGIC := '0';
	DBG_O			: out	STD_LOGIC_VECTOR(1 downto 0) := (others => '0')
);
end camera_python;

architecture toplevel of camera_python is

constant SYS_CLK_FREQ	: real := 100.0;

-- Clocks
signal clk100			: std_logic := '0';
signal rst100			: std_logic := '0';
signal clk_ready		: std_logic := '0';

-- LED
signal led_counter		: integer range 0 to 50e6-1 := 0;
signal led_state		: std_logic := '0';

-- Trigger
signal gen_trigger		: std_logic := '0';
signal trigger			: std_logic := '0';

-- Image Pipeline
constant PIXEL_WIDTH	: integer := 10;
constant PIXEL_CHANNELS	: integer := 1;
constant DATA_WIDTH		: integer := PIXEL_WIDTH * PIXEL_CHANNELS;
constant FIFO_DEPTH		: integer := 2048;

signal sens_aclock		: std_logic;
signal sens_tvalid		: std_logic;
signal sens_tlast		: std_logic;
signal sens_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal sens_tuser		: std_logic_vector(1 downto 0);

signal sens_trigger		: std_logic;
signal sens_sync		: std_logic;

signal test_aclock		: std_logic;
signal test_tvalid		: std_logic;
signal test_tlast		: std_logic;
signal test_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal test_tuser		: std_logic_vector(1 downto 0);

signal srcsel			: std_logic;

signal mux_reset		: std_logic;
signal mux_aclock		: std_logic;
signal mux_tvalid		: std_logic;
signal mux_tlast		: std_logic;
signal mux_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal mux_tuser		: std_logic_vector(1 downto 0);
signal mux_0_tready		: std_logic;
signal mux_1_tready		: std_logic;

signal rate_tvalid		: std_logic;
signal rate_tlast		: std_logic;
signal rate_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal rate_tuser		: std_logic_vector(1 downto 0);
signal rate_tready		: std_logic;

signal fifo_tvalid		: std_logic;
signal fifo_tlast		: std_logic;
signal fifo_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal fifo_tuser		: std_logic_vector(1 downto 0);
signal fifo_tready		: std_logic;

signal fifo_threshold	: std_logic;

signal usb3_tready		: std_logic;
signal fx3_fval			: std_logic;
signal fx3_lval			: std_logic;

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

-- UART		
constant UART_CMD_BITS		: integer := 8;
constant UART_CMD_MAX_ARGS	: integer := 4;

signal uart_arb_nack	: std_logic;
signal uart_arb_ack		: std_logic;

signal uart_tx_done		: std_logic;

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

dbg : entity work.dbg_mux
generic map (
	SLOTS		=> 8
)
port map (
	SELECT_I	=> reg(28)(2 downto 0),
	DBG_O		=> DBG_O,
	
	-- 0
	DBG_I(0)	=> '0',
	DBG_I(1)	=> '0',
	
	-- 1
	DBG_I(2)	=> '0',
	DBG_I(3)	=> '0',
	
	-- 2
	DBG_I(4)	=> sens_tlast or sens_tuser(0),
	DBG_I(5)	=> sens_tvalid,
	
	-- 3
	DBG_I(6)	=> sens_tuser(0),
	DBG_I(7)	=> sens_tuser(1),
	
	-- 4
	DBG_I(8)	=> fifo_tready,
	DBG_I(9)	=> mux_0_tready,
	
	-- 5
	DBG_I(10)	=> usb3_tready,
	DBG_I(11)	=> fifo_threshold,
	
	-- 6
	DBG_I(12)	=> fifo_tuser(0),
	DBG_I(13)	=> fifo_tlast,
	
	-- 7
	DBG_I(14)	=> fx3_fval,
	DBG_I(15)	=> fx3_lval
);

-- Clocking -------------------------------------------------------------------

clk_gen : entity work.clk_gen
generic map (
	CLK_IN_PERIOD	=> 20.0,	-- 50MHz
	DIFF_CLK_IN		=> false,
	DIVCLK_DIVIDE	=> 1,
	CLKFB_MULT		=> 16.0,
	CLK_OUT_DIVIDE	=> ( 0 => 8.0, others => 0.0 )
)
port map (
	CLK_Ip	=> CLK50_I,
	
	CLK0_O	=> clk100,	-- 50MHz * 16 / 8 = 100MHz
		
	LOCKED_O=> clk_ready
);

rst100 <= NOT clk_ready;

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
	
	TRIGGER_O		=> gen_trigger,
	EXPOSE_O		=> open,
	
	PERIOD_I		=> reg(3) & reg(2),
	EXPOSURE_I		=> reg(4)
);

trigger <= (reg(0)(0) and not reg(1)(0)) or gen_trigger;

-- Source ---------------------------------------------------------------------

source : entity work.python
port map (
	REFCLK_I		=> '0',
	RST_I			=> '0',

	-- Sensor Interface
	MCLK_I			=> '0', -- External Clock for Sensor provided by XTAL
	MCLK_O			=> SENS_CLOCK_O,

	CLKp_I			=> SENS_CLOCKp_I,
	CLKn_I			=> SENS_CLOCKn_I,

	SYNCp_I			=> SENS_SYNCp_I,
	SYNCn_I			=> SENS_SYNCn_I,

	DATAp_I			=> SENS_DATAp_I,
	DATAn_I			=> SENS_DATAn_I,	

	-- AXI Master
	M_AXIS_ACLK_O	=> sens_aclock,
	M_AXIS_TVALID_O	=> sens_tvalid,
	M_AXIS_TLAST_O	=> sens_tlast,
	M_AXIS_TDATA_O	=> sens_tdata,
	M_AXIS_TUSER_O	=> sens_tuser,
	M_AXIS_TREADY_I	=> mux_0_tready
);

SENS_TRIGGER_O(0) <= trigger;
SENS_TRIGGER_O(1) <= '0';
SENS_TRIGGER_O(2) <= '0';

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
/*
sync_reset : xpm_cdc_pulse
generic map (
	DEST_SYNC_FF	=> 4,
	REG_OUTPUT		=> 1,
	RST_USED		=> 0
)
port map(
	src_clk			=> clk100,
	src_rst			=> '0',
	src_pulse		=> rst100,
	
	dest_clk		=> mux_aclock,
	dest_rst		=> '0',
 	dest_pulse		=> mux_reset
);
*/
mux_reset <= '0';

srcsel <= reg(1)(1);

mux : entity work.axi_mux
generic map (
	DATA_WIDTH			=> DATA_WIDTH
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
	M_AXIS_TREADY_I		=> rate_tready	
);

rate : entity work.axi_rate
generic map (
	DATA_WIDTH		=> DATA_WIDTH
)
port map (
	AXIS_ACLK_I		=> mux_aclock,
	RST_I			=> mux_reset,
	
	INTERVAL_I		=> reg(10),
	
	-- AXI Slave
 	S_AXIS_TVALID_I	=> mux_tvalid,
	S_AXIS_TLAST_I	=> mux_tlast,
	S_AXIS_TDATA_I	=> mux_tdata,
	S_AXIS_TUSER_I	=> mux_tuser,
	S_AXIS_TREADY_O	=> rate_tready,

	-- AXI Master
	M_AXIS_TVALID_O	=> rate_tvalid,
	M_AXIS_TLAST_O	=> rate_tlast,
	M_AXIS_TDATA_O	=> rate_tdata,
	M_AXIS_TUSER_O	=> rate_tuser,
	M_AXIS_TREADY_I	=> fifo_tready
);	

fifo : entity work.axi_fifo
generic map (
	CLOCKING_MODE	=> "independent_clock",
	DATA_WIDTH		=> DATA_WIDTH,
	DEPTH			=> FIFO_DEPTH
)
port map (
	nRST_I			=> not mux_reset,
	
	-- AXI Slave
	S_AXIS_ACLK_I	=> mux_aclock,
	S_AXIS_TVALID_I	=> rate_tvalid,
	S_AXIS_TLAST_I	=> rate_tlast,
	S_AXIS_TDATA_I	=> rate_tdata,
	S_AXIS_TUSER_I	=> rate_tuser,
	S_AXIS_TREADY_O	=> fifo_tready,

	-- AXI Master
	M_AXIS_ACLK_I	=> clk100,
	M_AXIS_TVALID_O	=> fifo_tvalid,
	M_AXIS_TLAST_O	=> fifo_tlast,
	M_AXIS_TDATA_O	=> fifo_tdata,
	M_AXIS_TUSER_O	=> fifo_tuser,
	M_AXIS_TREADY_I	=> usb3_tready,
	
	THRESHOLD_I		=> reg(5)(clogb2(FIFO_DEPTH) downto 0),
	THRESHOLD_O		=> fifo_threshold
);

output : entity work.fx3
generic map (
	DATA_WIDTH		=> DATA_WIDTH,
	INVERT_CLK		=> true
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,
	
	-- AXI Slave
	S_AXIS_TVALID_I	=> fifo_tvalid,
	S_AXIS_TLAST_I	=> fifo_tlast,
	S_AXIS_TDATA_I	=> fifo_tdata,
	S_AXIS_TUSER_I	=> fifo_tuser,
	S_AXIS_TREADY_O	=> usb3_tready,
	
	THRESHOLD_I		=> fifo_threshold,
	HBLANK_I		=> reg(9)( 7 downto 0),
	VBLANK_I		=> reg(9)(15 downto 8),
	
	-- FX3
	CLK_O			=> FX3_CLOCK_O,
	CTL_IO			=> FX3_CTL_IO,
	DATA_O			=> FX3_DATA_O,
	
	-- DBG
	FVAL_O			=> fx3_fval,
	LVAL_O			=> fx3_lval
);

-- Registers ------------------------------------------------------------------

registers : entity work.registers
generic map (
	NR_OF_REGS 		=> NR_OF_REGS,
	DEFAULT_VALUE	=> (
						1		=> switch(SIMULATION, x"0000", x"0000"),-- Select Internal Source by default
						2		=> int2vec(33334, 16),					-- Trigger Period in us (Lo)
						3		=> int2vec(0, 16),						-- Trigger Period in us (Hi)
						4		=> int2vec(10, 16),						-- Exposure Time in us
						5		=> int2vec(720*2/PIXEL_CHANNELS, 16),	-- Test Image Width
						6		=> int2vec(576, 16),					-- Test Image Height
						7		=> int2vec(0, 16),						-- Test Image H Blank in us
						8		=> x"1234",								-- Test Image Pattern
						9		=> int2vec(10, 8) & int2vec(1, 8),		-- Output V/H Blank
						10		=> int2vec(33000, 16),					-- Minimum Interval between frames
						others	=> x"0000"
						)
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,
	
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

-- UART -----------------------------------------------------------------------

uart : entity work.uart
generic map (
	CLK_MHZ			=> SYS_CLK_FREQ,
	BAUDRATE		=> UART_BAUDRATE,
	FLOW_CTRL		=> UART_FLOW_CTRL
)
port map (
	CLK_I			=> clk100,
	RST_I 			=> rst100,
	
	RX_I	 		=> UART_RX_I,
	TX_O 			=> UART_TX_O,
	
	CTS_I			=> UART_CTS_I,
	RTS_O			=> UART_RTS_O,
	
	TX_DONE_O		=> open,
	
	PUT_CHAR_I		=> uart_put,
	PUT_ACK_O		=> uart_put_ack,
	TX_CHAR_I		=> uart_put_char,
	TX_FULL_O		=> uart_put_full,
	
	GET_CHAR_I		=> uart_get,
	GET_ACK_O		=> uart_get_ack,
	RX_CHAR_O		=> uart_get_char,
	RX_EMPTY_O		=> uart_get_empty
);

uart_decoder : entity work.uart_decoder
generic map (
	DATA_BITS 		=> UART_CMD_BITS,
	MAX_ARGS		=> UART_CMD_MAX_ARGS
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,
	
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
	CLK_I			=> clk100,
	RESET_I			=> rst100,
	
	BUSY_O			=> cmd_busy,
	
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
	SENS_DATA_O		=> sens_data_w
);

-- Sensor Control -------------------------------------------------------------

ctrl : entity work.python_ctrl
generic map (
	CLK_MHZ		=> SYS_CLK_FREQ,
	SPI_MHZ		=> 10.0,
	PAUSE_US	=> 11.0,
	SIMULATION	=> SIMULATION
)
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,
	
	EN_1V8_O	=> SENS_EN_1V8_O,
	EN_3V3_O	=> SENS_EN_3V3_O,
	EN_PIX_O	=> SENS_EN_PIX_O,
	EN_CLK_O	=> SENS_EN_CLK_O,
	RST_O		=> SENS_nRESET_O,
	
	ENABLE_I	=> reg(1)(4),
	
	BUSY_O		=> sens_busy,
	DONE_O		=> sens_done,
	
	READ_I		=> sens_read,
	WRITE_I		=> sens_write,
	
	ADDR_I		=> sens_addr,
	DATA_I		=> sens_data_w,
	DATA_O		=> sens_data_r,
	
	nCS_O		=> SENS_nCS_O,
	SCK_O		=> SENS_SCK_O,
	MOSI_O		=> SENS_MOSI_O,
	MISO_I	 	=> SENS_MISO_I
);

end toplevel;
