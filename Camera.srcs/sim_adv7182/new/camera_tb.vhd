library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use work.util.all;

entity camera_tb is
Generic (
	SIMULATION			: boolean := TRUE;
	UART_BAUDRATE		: integer := 921600;
	CWD					: string := "V:/vhdl/modularCamera/Camera.srcs/sim_1/new/"
);
--  Port ( );
end camera_tb;

architecture Testbench of camera_tb is

signal clk50			: std_logic := '0';
signal clk100			: std_logic := '0';
signal clk27			: std_logic := '0';


signal LLC				: std_logic := '0';
signal VSYNC			: std_logic := '0';
signal HSYNC			: std_logic := '0';
signal DATA				: std_logic_vector(7 downto 0) := (others => '0');

signal sda				: std_logic := 'H';
signal scl				: std_logic := 'H';
	
signal uart_tx			: std_logic := '1';
signal uart_rx			: std_logic := '1';

signal uart_rx_char		: std_logic_vector(7 downto 0) := x"00";

signal line_nr			: integer := 0;
signal pixel_nr			: integer := 0;
signal field			: integer := 0;
signal eav, sav			: std_logic := '0';

begin

sim : process
begin
	wait for 300us;
	
--	uart_puts("{w0855}", uart_tx, 921600);
	
--	wait for 500us;
	
--	uart_puts("{r06}", uart_tx, 921600);
	
--	wait for 500us;
		
--	uart_puts("{W030000}", uart_tx, 921600);
	
--	wait for 1us;
	
--	uart_puts("{W020190}", uart_tx, 921600);
	
--	wait for 1us;
	
--	uart_puts("{W070001}", uart_tx, 921600);
	
--	wait for 1us;
	
--	uart_puts("{W050064}", uart_tx, 921600);
	
--	wait for 1us;
	
--	uart_puts("{W060064}", uart_tx, 921600);
	
--	wait for 1us;
	
--	uart_puts("{W010313}", uart_tx, 921600);
	
--	wait for 1ms;
	
	uart_puts("{W010000}", uart_tx, 921600);
			
	wait;
end process;

LLC <= clk27;

video : process
begin
	
	for l in 1 to 525 loop	-- 525 Lines
		line_nr <= l;
		
		-- EAV
		DATA <= x"FF";
		wait until falling_edge(LLC);
		DATA <= x"00";
		wait until falling_edge(LLC);
		DATA <= x"00";
		wait until falling_edge(LLC);
		-- EAV
		DATA(4) <= '1';
		eav <= '1';
		
		-- V Blank
		if (l > 20 and l < 264)
		or (l > 283 and l < 526) then
			DATA(5) <= '0';
		else
			DATA(5) <= '1';
		end if;
		
		-- Field
		if l > 4 and l < 266 then
			DATA(6) <= '0';
			field <= 0;
		else
			DATA(6) <= '1';
			field <= 1;
		end if;
				
		DATA(7) <= '1';
		wait until falling_edge(LLC);
		eav <= '0';
		
		for v in 0 to 267 loop	-- H Blank
			pixel_nr <= v;
			
			if v mod 2 = 0 then
				DATA <= x"80";
			else
				DATA <= x"10";
			end if;
			
			wait until falling_edge(LLC);
		end loop;
		
		-- SAV
		DATA <= x"FF";
		wait until falling_edge(LLC);
		DATA <= x"00";
		wait until falling_edge(LLC);
		DATA <= x"00";
		wait until falling_edge(LLC);
		-- SAV
		DATA(4) <= '0';
		sav <= '1';
		
		-- V Blank
		if (l > 20 and l < 264)
		or (l > 283 and l < 526) then
			DATA(5) <= '0';
		else
			DATA(5) <= '1';
		end if;
		
		-- Field
		if l > 4 and l < 266 then
			DATA(6) <= '0';
		else
			DATA(6) <= '1';
		end if;
		
		DATA(7) <= '1';
	
		wait until falling_edge(LLC); 
		sav <= '0';
		
		for v in 0 to 1439 loop	-- Active Video, 720Y + 720C
			pixel_nr <= v;
			if v mod 2 = 0 then
--				if v/2 mod 2 = 0 then
--					DATA <= x"42";
--				else
--					DATA <= x"52";
--				end if;
				DATA <= int2vec(v/2, 8);
			else
				DATA <= x"59";
			end if;
			
			wait until falling_edge(LLC);
		end loop;
		
		
				
	end loop;
		
end process;

--video : process
--begin
--	VSYNC <= '1';
--	wait for 1.535ms;
--	VSYNC <= '0';
	
--	for i in 0 to 287 loop
--		wait for 10.66us;
--		HSYNC <= '1';
--		wait for 53.31us;
--		HSYNC <= '0';
--	end loop;
	
--	wait for 230ns;
--	VSYNC <= '1';
	
--	wait for 1.6ms;
--	HSYNC <= '1';
--	wait for 27.47us;
--	VSYNC <= '0';
--	wait for 25.84us;
--	HSYNC <= '0';
	
--	for i in 0 to 286 loop
--		wait for 10.66us;
--		HSYNC <= '1';
--		wait for 53.31us;
--		HSYNC <= '0';
--	end loop;
--	wait for 230ns;
--end process;

clk_50 : process
begin
	clock(50.0, 0ns, clk50);
end process;

clk_27 : process
begin
	clock(27.0, 3ns, clk27);
end process;

rx_0 : process
begin
	uart_getc(uart_rx_char, uart_rx, 921600); 
end process;

/*
sensor : entity work.adv7182_sim
generic map (
	FILE_BASE		=> CWD & "test",
	FILE_EXT		=> ".pgm",
	WIDTH			=> 120,
	HEIGHT			=> 80,
	CLOCK_MHZ		=> 80.0, --MHz
	CHANNELS		=> 3,
	BPP				=> 8,
	N				=> 7,	-- SERDES Factor
	D				=> 4,	-- Data Lines
	LINE_PAUSE		=> 100ns,
	FRAME_PAUSE		=> 1us,
	INTERLEAVED		=> false,
	CLOCK_PATTERN	=> "1100011",
	SCALE			=> 1
)
port map (
	RST_I			=> '0',
	
	XCLKp_O			=> XCLKp,
	XCLKn_O			=> XCLKn,

	Xp_O			=> Xp,
	Xn_O			=> Xn,
		
	CCp_I			=> CCp,
	CCn_I			=> CCn,
	
	SERTFGp_O		=> open,
	SERTFGn_O		=> open,
	
	SERTCp_I		=> '1',
	SERTCn_I		=> '0'
);
*/

sda <= 'H';
scl <= 'H';

cam : entity work.camera_adv7182
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
	
	-- FX3
	FX3_CLOCK_O		=> open,
	FX3_CTL_IO		=> open,
	FX3_DATA_O		=> open,
		
	UART_TX_O		=> uart_rx,
	UART_RX_I		=> uart_tx,
	UART_CTS_I		=> '0',
	UART_RTS_O		=> open,
		
	-- Sensor
	SENS_CLOCK_I	=> LLC,
	
	SENS_RESET_O	=> open,
	SENS_PWRDN_O	=> open,
	SENS_INTRQ_I	=> '1',
	SENS_VSYNC_I	=> VSYNC,
	SENS_HSYNC_I	=> HSYNC,
	SENS_DATA_I		=> DATA,
	
	SENS_SCL_IO 	=> scl,
	SENS_SDA_IO 	=> sda,
	
	-- Misc.
	LED_O			=> open,
	DBG_O			=> open	
);

end Testbench;
