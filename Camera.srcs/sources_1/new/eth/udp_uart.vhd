library IEEE, UNISIM, UNIMACRO;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNIMACRO.vcomponents.all;
use work.util.all;

entity udp_uart is
	generic (
		PORT_NR				: integer	:= 16#1337#;
		MAX_LENGTH			: integer	:= 1024;		-- Maximum Bytes in one Response Packet
		DATA_BITS			: integer	:= 8;
		
		TX					: boolean := true;
		RX					: boolean := true
	);
	port (
		-- system signals
		CLK_I				: in	std_logic;
		RESET_I				: in	std_logic;
		
		RX_BUSY_O			: out	std_logic := '0';
		TX_BUSY_O			: out	std_logic := '0';
		
		-- udp rx inteface
		UDP_RX_DONE_I		: in	std_logic;
		UDP_RX_DV_I			: in	std_logic;
		UDP_RX_DATA_I		: in	std_logic_vector( 7 downto 0);
		UDP_RX_SRC_MAC_I	: in	std_logic_vector(47 downto 0);
		UDP_RX_SRC_IP_I		: in	std_logic_vector(31 downto 0);
		UDP_RX_SRC_PORT_I	: in	std_logic_vector(15 downto 0);
		UDP_RX_DST_PORT_I	: in	std_logic_vector(15 downto 0);
		
		-- udp tx interface
		UDP_TX_RTS_O		: out	std_logic := '0';
		UDP_TX_START_O		: out	std_logic := '0';
		UDP_TX_READY_I		: in	std_logic;
		UDP_TX_BUSY_I		: in	std_logic;
		
		UDP_TX_DV_O			: out	std_logic := '0';
		UDP_TX_DATA_O		: out	std_logic_vector( 7 downto 0) := (others => 'Z');
		UDP_TX_DST_MAC_O	: out	std_logic_vector(47 downto 0) := (others => 'Z');
		UDP_TX_DST_IP_O		: out	std_logic_vector(31 downto 0) := (others => 'Z');
		UDP_TX_SRC_PORT_O	: out	std_logic_vector(15 downto 0) := (others => 'Z');
		UDP_TX_DST_PORT_O	: out	std_logic_vector(15 downto 0) := (others => 'Z');
		UDP_TX_DATA_SIZE_O	: out	std_logic_vector(15 downto 0) := (others => 'Z');
		
		-- fifo interface
		RTS_I				: in	STD_LOGIC := '0';
		PUT_CHAR_I			: in	STD_LOGIC;
		PUT_ACK_O			: out 	STD_LOGIC := '0';
		TX_CHAR_I			: in 	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0);
		TX_FULL_O			: out	STD_LOGIC := '0';
		TX_EMPTY_O			: out	STD_LOGIC := '0';
		
		GET_CHAR_I			: in	STD_LOGIC;
		GET_ACK_O			: out	STD_LOGIC := '0';
		RX_CHAR_O			: out	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
		RX_EMPTY_O			: out	STD_LOGIC := '1'
	);
end udp_uart;

architecture Behavioral of udp_uart is

constant CMD_PORT	: std_logic_vector(15 downto 0) := int2vec(PORT_NR, 16);

signal fifo_reset	: STD_LOGIC_VECTOR(5 downto 0) := "111110";

signal rx_put		: std_logic := '0';
signal rx_put_ack	: std_logic := '0';
signal rx_wrerr		: STD_LOGIC := '0';
signal rx_full		: std_logic := '0';
signal rx_data_i	: std_logic_vector(DATA_BITS-1 downto 0);

signal rx_get		: std_logic := '0';
signal rx_get_ack	: std_logic := '0';
signal rx_rderr		: STD_LOGIC := '0';
signal rx_empty		: std_logic := '0';
signal rx_data_o	: std_logic_vector(DATA_BITS-1 downto 0);

signal tx_put		: std_logic := '0';
signal tx_put_ack	: std_logic := '0';
signal tx_wrerr		: STD_LOGIC := '0';
signal tx_full		: std_logic := '0';
signal tx_data_i	: std_logic_vector(DATA_BITS-1 downto 0);

signal tx_get		: std_logic := '0';
signal tx_get_ack	: std_logic := '0';
signal tx_rderr		: STD_LOGIC := '0';
signal tx_empty		: std_logic := '0';
signal tx_data_o	: std_logic_vector(DATA_BITS-1 downto 0);

type udp_rx_state_t is (
	S_RECEIVE,
	S_END
);

signal udp_rx_state		: udp_rx_state_t := S_RECEIVE;

signal udp_rx_busy		: std_logic := '0';
signal udp_tx_busy		: std_logic := '0';

signal tx_counter		: std_logic_vector(15 downto 0) := (others => '0');
constant count_width	: integer := clogb2(MAX_LENGTH);
constant max_data_size	: std_logic_vector(count_width-1 downto 0) := int2vec(MAX_LENGTH-1, count_width);
signal byte_count		: std_logic_vector(count_width-1 downto 0) := (others => '0');

signal active			: std_logic := '0';
signal tx_en			: std_logic := '0';
signal tx_start			: std_logic := '0';
signal tx_data			: std_logic_vector( 7 downto 0) := (others => '0');
signal tx_dst_mac		: std_logic_vector(47 downto 0) := (others => '0');
signal tx_dst_ip		: std_logic_vector(31 downto 0) := (others => '0');
signal tx_src_port		: std_logic_vector(15 downto 0) := (others => '0');
signal tx_dst_port		: std_logic_vector(15 downto 0) := (others => '0');
signal tx_data_size		: std_logic_vector(15 downto 0) := (others => '0');

type tx_state_t is (
	S_TX_IDLE,
	S_TX_WAIT_FOR_BUSY,
	S_TX_DELAY,
	S_TX_START,
	S_TX_WAIT_FOR_READY,
	S_TX_TRANSMIT
);

signal tx_state		: tx_state_t := S_TX_IDLE;

begin

RX_ENABLE : if RX = TRUE generate

-- RX (UDP -> UART)

-- RST must be held high for at least five WRCLK clock cycles,
-- and WREN must be low before RST becomes active high,
-- and WREN remains low during this reset cycle.

/*

-- Spartan 6

rx_fifo : entity work.uart_fifo
port map(
	rst			=> fifo_reset(fifo_reset'high),
	clk			=> CLK_I,
	
	wr_en 		=> rx_put,
	overflow 	=> rx_wrerr,
	full 		=> rx_full,
	din			=> rx_data_i,
	
	rd_en 		=> rx_get,
	underflow	=> rx_rderr, 	
	empty 		=> rx_empty,
	dout		=> rx_data_o
);
*/

-- Spartan 7

rx_fifo : FIFO_SYNC_MACRO
generic map (
	DEVICE				=> "7SERIES", 
	ALMOST_FULL_OFFSET	=> X"07FC",
	ALMOST_EMPTY_OFFSET => X"0005",
	DATA_WIDTH			=> DATA_BITS,   			
	FIFO_SIZE			=> "18Kb"
) 
port map (
	rst			=> fifo_reset(fifo_reset'high),
	clk			=> CLK_I,
	
	WREN 		=> rx_put,
	WRERR 		=> rx_wrerr,
	ALMOSTFULL 	=> open,
	FULL 		=> rx_full,
	WRCOUNT 	=> open, 
	DI 			=> rx_data_i,
	
	RDEN 		=> rx_get,
	RDERR		=> rx_rderr, 	
	ALMOSTEMPTY => open,
	EMPTY 		=> rx_empty,
	RDCOUNT 	=> open,
	DO 			=> rx_data_o
);

rx_ack : process (CLK_I)
begin
	if rising_edge(CLK_I) then
		rx_put_ack <= NOT rx_wrerr AND NOT rx_full AND rx_put;
		rx_get_ack <= NOT rx_rderr AND NOT rx_empty AND rx_get;
	end if;
end process;

rx_get 		<= GET_CHAR_I;
GET_ACK_O	<= rx_get_ack;
RX_CHAR_O	<= rx_data_o;
RX_EMPTY_O	<= rx_empty;

RX_BUSY_O	<= udp_rx_busy OR NOT rx_empty;	-- be busy as soon as a char has arrived in the fifo

udp2fifo : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			fifo_reset		<= "111110";
			udp_rx_state	<= S_RECEIVE;
			udp_rx_busy		<= '0';
		else
			rx_put 			<= '0';
			
			if (fifo_reset(fifo_reset'high) = '1') then
				fifo_reset(fifo_reset'high downto 1) <= fifo_reset(fifo_reset'high-1 downto 0);
			end if; 
	
			if (UDP_RX_DST_PORT_I = CMD_PORT) then
				if (UDP_RX_DV_I = '1') then
					udp_rx_busy	<= '1';
					
					rx_put 		<= '1';
					rx_data_i 	<= UDP_RX_DATA_I AND x"7F"; -- Mask MSB to work around UDP RX errors
					
					-- TODO: Handle lost chars in case of TX_FULL_I = '1'
				end if;
				
				if (UDP_RX_DONE_I = '1') then
					udp_rx_busy		<= '0';
					
					tx_dst_mac		<= UDP_RX_SRC_MAC_I;
					tx_dst_ip		<= UDP_RX_SRC_IP_I;
					tx_dst_port		<= UDP_RX_SRC_PORT_I;
					tx_src_port		<= CMD_PORT;
				end if;
			end if;
		end if;
	end if;
end process;

end generate;	-- RX_ENABLE = TRUE

TX_ENABLE : if TX = TRUE generate

-- RST must be held high for at least five WRCLK clock cycles,
-- and WREN must be low before RST becomes active high,
-- and WREN remains low during this reset cycle.

/*

-- Spartan 6

tx_fifo : entity work.uart_fifo
port map (
	rst			=> fifo_reset(fifo_reset'high),
	clk			=> CLK_I,
	
	wr_en 		=> tx_put,
	overflow 	=> tx_wrerr,
	full 		=> tx_full,
	din 		=> tx_data_i,
	
	rd_en 		=> tx_get and not tx_get_ack,
	underflow	=> tx_rderr, 	
	empty 		=> tx_empty,
	dout 		=> tx_data_o
);
*/

-- Spartan 7

tx_fifo : FIFO_SYNC_MACRO
generic map (
	DEVICE				=> "7SERIES", 
	ALMOST_FULL_OFFSET	=> X"07FC",
	ALMOST_EMPTY_OFFSET => X"0005",
	DATA_WIDTH			=> DATA_BITS,   			
	FIFO_SIZE			=> "18Kb"
) 
port map (
	rst			=> fifo_reset(fifo_reset'high),
	clk			=> CLK_I,
	
	WREN 		=> tx_put,
	WRERR 		=> tx_wrerr,
	ALMOSTFULL 	=> open,
	FULL 		=> tx_full,
	WRCOUNT 	=> open, 
	DI 			=> tx_data_i,
	
	RDEN 		=> tx_get,
	RDERR		=> tx_rderr, 	
	ALMOSTEMPTY => open,
	EMPTY 		=> tx_empty,
	RDCOUNT 	=> open,
	DO 			=> tx_data_o
);

tx_ack : process (CLK_I)
begin
	if rising_edge(CLK_I) then
		tx_put_ack <= NOT tx_wrerr AND NOT tx_full  AND tx_put;
		tx_get_ack <= NOT tx_rderr AND NOT tx_empty AND tx_get;
	end if;
end process;

tx_put 		<= PUT_CHAR_I;
PUT_ACK_O	<= tx_put_ack;
TX_FULL_O	<= tx_full;
TX_EMPTY_O	<= tx_empty;
tx_data_i	<= TX_CHAR_I;

-- TX (UART -> UDP)

UDP_TX_START_O		<= tx_start		when active = '1' else '0';
UDP_TX_DV_O			<= tx_en		when active = '1' else '0';
UDP_TX_DATA_O		<= tx_data		when active = '1' else (others => 'Z');
UDP_TX_DST_MAC_O	<= tx_dst_mac	when active = '1' else (others => 'Z');
UDP_TX_DST_IP_O		<= tx_dst_ip	when active = '1' else (others => 'Z');
UDP_TX_DST_PORT_O	<= tx_dst_port	when active = '1' else (others => 'Z');
UDP_TX_SRC_PORT_O	<= tx_src_port	when active = '1' else (others => 'Z');
UDP_TX_DATA_SIZE_O	<= tx_data_size	when active = '1' else (others => 'Z');

tx_data		<= tx_data_o;
tx_en		<= tx_get_ack;

TX_BUSY_O	<=  udp_tx_busy;

fifo2udp : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			tx_state	<= S_TX_IDLE;
			UDP_TX_RTS_O<= '0';
			tx_get		<= '0';
			active		<= '0';
		else
			tx_start	<= '0';
			
			if (PUT_CHAR_I = '1') then
				tx_counter <= inc(tx_counter);
			end if;
			
			case (tx_state) is
			when S_TX_IDLE =>
				active		<= '0';
				UDP_TX_RTS_O<= '0';
				udp_tx_busy <= '0';
			
				if (RTS_I = '1' and tx_empty = '0') then
					UDP_TX_RTS_O	<= '1';
					udp_tx_busy		<= '1';
					tx_data_size	<= tx_counter;
					tx_counter 		<= (others => '0');
					tx_state 		<= S_TX_WAIT_FOR_BUSY;
				end if;
						
			when S_TX_WAIT_FOR_BUSY =>
				if (UDP_TX_BUSY_I = '0') then
					active	 <= '1';
					tx_state <= S_TX_DELAY;
				end if;
				
			when S_TX_DELAY =>
				tx_state <= S_TX_START;
				
			when S_TX_START =>
				tx_start	<= '1';
				tx_state	<= S_TX_WAIT_FOR_READY;
				
			when S_TX_WAIT_FOR_READY =>
				if (UDP_TX_READY_I = '1') then
					tx_get	 	<= '1';
					byte_count	<= inc(byte_count);
					tx_state	<= S_TX_TRANSMIT;
				end if;

			when S_TX_TRANSMIT =>
				if (tx_get_ack = '1') then
					if (byte_count >= tx_data_size(count_width-1 downto 0)) OR (byte_count = max_data_size) then
						tx_get 	 	<= '0';
						tx_state 	<= S_TX_IDLE;
						byte_count	<= (others => '0');
					else
						byte_count <= inc(byte_count);
					end if;
				end if;
			end case;
		end if;
	end if;
end process;

end generate;	-- TX_ENABLE = TRUE

end Behavioral;