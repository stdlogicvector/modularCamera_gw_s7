library IEEE, UNISIM, XPM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use XPM.vcomponents.all;
use work.types.all;
use work.util.all;
use work.luts.all;

entity camera_hallarray is
generic (
	VERSION			: integer := 16#0101#;
	BUILD			: integer := 1;
	BUILDTIME		: integer := 0;			-- Set by TCL during Synthesis
	VARIANT			: string  := "HALLARRAY";
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
		
	-- Hall Array
	SENS_nENABLE_O	: out	STD_LOGIC := '1';
	
	SENS_ROW_O		: out	STD_LOGIC_VECTOR(2 downto 0) := (others => '0');
	SENS_COL_O		: out	STD_LOGIC_VECTOR(2 downto 0) := (others => '0');
	
	-- ADC	
	SENS_nCS_O		: out	STD_LOGIC := '1';
	SENS_SCK_O		: out	STD_LOGIC := '0';
	SENS_SDO_I		: in	STD_LOGIC;
	
	-- Misc.
	LED_O			: out	STD_LOGIC := '0';
	DBG_O			: out	STD_LOGIC_VECTOR(1 downto 0) := (others => '0')
);
end camera_hallarray;

architecture toplevel of camera_hallarray is

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
constant PIXEL_WIDTH	: integer := 12;
constant PIXEL_CHANNELS	: integer := 1;
constant DATA_WIDTH		: integer := PIXEL_WIDTH * PIXEL_CHANNELS;
constant OUTPUT_WIDTH	: integer := 16;
constant FIFO_DEPTH		: integer := 2048;

signal sens_aclock		: std_logic;
signal sens_tvalid		: std_logic;
signal sens_tlast		: std_logic;
signal sens_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal sens_tuser		: std_logic_vector(1 downto 0);

signal sens_trigger		: std_logic;
signal sens_dv          : std_logic;
signal sens_sync		: std_logic;

signal sens_in_frame	: std_logic := '0';
signal trig_enable		: std_logic := '0';

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

signal ups_aclock		: std_logic;
signal ups_tvalid		: std_logic;
signal ups_tlast		: std_logic;
signal ups_tdata		: std_logic_vector(DATA_WIDTH-1 downto 0);
signal ups_tuser		: std_logic_vector(1 downto 0);
signal ups_tready		: std_logic;

signal lut_aclock		: std_logic;
signal lut_tvalid		: std_logic;
signal lut_tlast		: std_logic;
signal lut_tdata		: std_logic_vector(24-1 downto 0);
signal lut_tuser		: std_logic_vector(1 downto 0);
signal lut_tready		: std_logic; 

signal cnv_aclock		: std_logic;
signal cnv_tvalid		: std_logic;
signal cnv_tlast		: std_logic;
signal cnv_tdata		: std_logic_vector(OUTPUT_WIDTH-1 downto 0);
signal cnv_tuser		: std_logic_vector(1 downto 0);
signal cnv_tready		: std_logic; 

signal fifo_tvalid		: std_logic;
signal fifo_tlast		: std_logic;
signal fifo_tdata		: std_logic_vector(OUTPUT_WIDTH-1 downto 0);
signal fifo_tuser		: std_logic_vector(1 downto 0);
signal fifo_tready		: std_logic;

signal fifo_threshold	: std_logic;

signal usb3_tready		: std_logic;
signal fx3_fval			: std_logic;
signal fx3_lval			: std_logic;

-- Metadata
signal timestamp		: std_logic_vector(31 downto 0);
signal framenr			: std_logic_vector(31 downto 0);
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

-- LUT
constant LUTS			: integer := 1;
signal lut_write		: std_logic_vector(LUTS-1 downto 0) := (others => '0');
signal lut_ack			: std_logic_vector(LUTS-1 downto 0) := (others => '0');
signal lut_addr			: std_logic_vector(15 downto 0) := (others => '0');
signal lut_data			: std_logic_vector(31 downto 0) := (others => '0');

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

DBG_O <= (
--	0	=> trigger,
--	1	=> SENS_CTL_O(2),
--	1	=> sens_tvalid,
	0	=> fx3_fval,
	1	=> fx3_lval,
--	0	=> trigger,
--	1	=> 
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
	CLKFB_MULT		=> 16.0,
	CLK_OUT_DIVIDE	=> ( 0 => 8.0, others => 0.0 )
)
port map (
	CLK_Ip     => CLK50_I,
	
	CLK0_O	   => clk100,	-- 50MHz * 16 / 8 = 100MHz
		
	LOCKED_O   => clk_ready
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

process(clk100)
begin
	if rising_edge(clk100) then
		if sens_tuser(0) = '1' then
			sens_in_frame <= '1';
		elsif sens_tuser(1) = '1' then
			sens_in_frame <= '0';
		end if;
		
		if sens_in_frame = '0' then
			trig_enable <= reg(1)(0);
		end if;
	end if;
end process;

trigger_gen : entity work.trigger_gen
generic map (
	CLK_MHZ			=> 100.0,
	RESOLUTION_US	=> 1
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,
	
	ENABLE_I		=> trig_enable,	--reg(1)(0),
	
	TRIGGER_O		=> open,
	EXPOSE_O		=> gen_trigger,
	
	PERIOD_I		=> reg(3) & reg(2),
	EXPOSURE_I		=> reg(4)
);

trigger <= (reg(0)(0) and not reg(1)(0)) or gen_trigger;

-- Source ---------------------------------------------------------------------

source : entity work.hallarray
generic map (
	ROWS			=> 8,
	COLS			=> 8
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,

	ENABLE_I		=> reg(1)(4),
	TRIGGER_I		=> trigger AND NOT srcsel,
	SETTLING_I		=> reg(4),

	-- Sensor Interface
	nENABLE_O		=> SENS_nENABLE_O,
	COL_O			=> SENS_COL_O,
	ROW_O			=> SENS_ROW_O,
	
	nCS_O			=> SENS_nCS_O,
	SCK_O			=> SENS_SCK_O,
	SDO_I			=> SENS_SDO_I,
		
	-- AXI Master
	M_AXIS_ACLK_O	=> sens_aclock,
	M_AXIS_TVALID_O	=> sens_tvalid,
	M_AXIS_TLAST_O	=> sens_tlast,
	M_AXIS_TDATA_O	=> sens_tdata,
	M_AXIS_TUSER_O	=> sens_tuser,
	M_AXIS_TREADY_I	=> mux_0_tready
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
	M_AXIS_TREADY_I		=> ups_tready	
);

-- Upscale

upscale : entity work.axi_upscale(NearestNeighbor)
generic map (
	INPUT_WIDTH		=> 8,
	INPUT_HEIGHT	=> 8,
	DATA_WIDTH		=> DATA_WIDTH
)
port map (
	RST_I			=> reg(0)(15),
	
	X_FACTOR_I		=> reg(10)(7 downto 0),
	Y_FACTOR_I		=> reg(10)(15 downto 8),
	
	-- AXI Slave
	S_AXIS_ACLK_I	=> mux_aclock,
	S_AXIS_TVALID_I	=> mux_tvalid,
	S_AXIS_TLAST_I	=> mux_tlast,
	S_AXIS_TDATA_I	=> mux_tdata,
	S_AXIS_TUSER_I	=> mux_tuser,
	S_AXIS_TREADY_O	=> ups_tready,

	-- AXI Master
	M_AXIS_ACLK_O	=> ups_aclock,
	M_AXIS_TVALID_O	=> ups_tvalid,
	M_AXIS_TLAST_O	=> ups_tlast,
	M_AXIS_TDATA_O	=> ups_tdata,
	M_AXIS_TUSER_O	=> ups_tuser,
	M_AXIS_TREADY_I	=> lut_tready
);

-- LUT

lut : entity work.axi_lut
generic map (
	INPUT_WIDTH		=> DATA_WIDTH,
	OUTPUT_WIDTH	=> 24,
	INIT_VALUES		=> yuv444_blue_red_4096,	--switch(OUTPUT_WIDTH = 8, gray8_4096_to_256, switch(OUTPUT_WIDTH = 16, yuv565_red_blue_4096, rgb888_red_blue_4096)), --yuv444_red_blue_4096)),
	FILE_TYPE		=> "INTARR"
)
port map (
	CLK_I			=> clk100,
	RST_I			=> reg(0)(15),
		
	LUT_WRITE_I		=> lut_write(0),
	LUT_ACK_O		=> lut_ack(0),
	LUT_ADDR_I		=> lut_addr(DATA_WIDTH-1 downto 0),
	LUT_DATA_I		=> lut_data(24-1 downto 0),
		
	-- AXI Slave
	S_AXIS_ACLK_I	=> ups_aclock,
	S_AXIS_TVALID_I	=> ups_tvalid,
	S_AXIS_TLAST_I	=> ups_tlast,
	S_AXIS_TDATA_I	=> ups_tdata,
	S_AXIS_TUSER_I	=> ups_tuser,
	S_AXIS_TREADY_O	=> lut_tready,

	-- AXI Master
	M_AXIS_ACLK_O	=> lut_aclock,
	M_AXIS_TVALID_O	=> lut_tvalid,
	M_AXIS_TLAST_O	=> lut_tlast,
	M_AXIS_TDATA_O	=> lut_tdata,
	M_AXIS_TUSER_O	=> lut_tuser,
	M_AXIS_TREADY_I	=> cnv_tready
);

-- Conversion

convert : entity work.axi_yuv444_to_yuv422
port map (
	RST_I			=> reg(0)(15),
	
	-- AXI Slave
	S_AXIS_ACLK_I	=> lut_aclock,
	S_AXIS_TVALID_I	=> lut_tvalid,
	S_AXIS_TLAST_I	=> lut_tlast,
	S_AXIS_TDATA_I	=> lut_tdata,
	S_AXIS_TUSER_I	=> lut_tuser,
	S_AXIS_TREADY_O	=> cnv_tready,

	-- AXI Master
	M_AXIS_ACLK_O	=> cnv_aclock,
	M_AXIS_TVALID_O	=> cnv_tvalid,
	M_AXIS_TLAST_O	=> cnv_tlast,
	M_AXIS_TDATA_O	=> cnv_tdata,
	M_AXIS_TUSER_O	=> cnv_tuser,
	M_AXIS_TREADY_I	=> fifo_tready
);

-- FIFO

fifo : entity work.axi_fifo
generic map (
	CLOCKING_MODE	=> "common_clock",
	DATA_WIDTH		=> OUTPUT_WIDTH,
	DEPTH			=> FIFO_DEPTH
)
port map (
	nRST_I			=> not reg(0)(15),
	
	-- AXI Slave
	S_AXIS_ACLK_I	=> cnv_aclock,
	S_AXIS_TVALID_I	=> cnv_tvalid,
	S_AXIS_TLAST_I	=> cnv_tlast,
	S_AXIS_TDATA_I	=> cnv_tdata,
	S_AXIS_TUSER_I	=> cnv_tuser,
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

-- USB3

output : entity work.fx3
generic map (
	DATA_WIDTH		=> OUTPUT_WIDTH,
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
						1		=> x"0002",							-- Select Internal Source by default
						2		=> int2vec(10000, 16),				-- Trigger Period in us (Lo)
						3		=> int2vec(0, 16),					-- Trigger Period in us (Hi)
						4		=> int2vec(10, 16),					-- Settling Time in us
						5		=> int2vec(8, 16),					-- Test Image Width
						6		=> int2vec(8, 16),					-- Test Image Height
						7		=> int2vec(0, 16),					-- Test Image H Blank in us
						8		=> x"1234",							-- Test Image Pattern
						9		=> int2vec(10, 8) & int2vec(1, 8),	-- Output V/H Blank
						10		=> int2vec(8, 8) & int2vec(8, 8),	-- Upscale Factor Y & X
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
	USE_SENSOR		=> false,
	LUTS			=> 1
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
	
	LUT_WRITE_O		=> lut_write,
	LUT_ACK_I		=> lut_ack,
	LUT_ADDR_O		=> lut_addr,
	LUT_DATA_O		=> lut_data
);

end toplevel;
