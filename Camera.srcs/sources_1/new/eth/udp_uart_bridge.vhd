library IEEE, UNISIM, UNIMACRO;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity udp_uart_bridge is
	generic (
		PORT_NR				: integer	:= 16#1337#;
		MAX_LENGTH			: integer	:= 1024;		-- Maximum Bytes in one Response Packet
		MAX_IDLECHARS		: integer	:= 4;			-- Character times idle before TX
		
		MODE				: string := "SLOW";			-- FAST or SLOW
		OVERSAMPLE			: integer := 16;
		CLK_MHZ				: real := 80.0;
		BAUDRATE			: integer := 921600;
		DATA_BITS			: integer := 8;				-- 6, 7, 8, 9
		PARITY_BIT			: character := 'N';			-- N(one), O(dd), E(ven)
		STOP_BITS			: real := 1.0;				-- 1.0, 1.5, 2.0
		START_BIT			: std_logic := '0';
		
		TX					: boolean := true;
		RX					: boolean := true
	);
	port (
		-- system signals
		CLK_I				: in	std_logic;
		RESET_I				: in	std_logic;
		
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
		
		-- uart interface
		TX_DONE_O			: out	STD_LOGIC := '0';
		
		TX_O				: out	STD_LOGIC := NOT START_BIT;
		RX_I				: in	STD_LOGIC := NOT START_BIT
	);
end udp_uart_bridge;

architecture Behavioral of udp_uart_bridge is

signal os_clk		: STD_LOGIC := '0';

signal tx_char		: STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
signal rx_char		: STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');

signal tx_busy		: STD_LOGIC := '0';

signal send			: STD_LOGIC := '0';
signal recv			: STD_LOGIC := '0';

signal rx_idle		: STD_LOGIC := '0';
signal idle_chars	: integer range 0 to MAX_IDLECHARS := 0;

type tx_state_t	is (S_TX_IDLE, S_TX_READ, S_TX_PUT, S_TX_WAIT);
signal tx_state 	: tx_state_t := S_TX_IDLE;

type rx_state_t	is (S_RX_IDLE, S_RX_PUT, S_RX_WAIT);
signal rx_state 	: rx_state_t := S_RX_IDLE;

signal udp_rts		: STD_LOGIC := '0';
signal udp_put_char	: STD_LOGIC := '0';
signal udp_put_ack	: STD_LOGIC := '0';
signal udp_tx_char	: STD_LOGIC_VECTOR(DATA_BITS-1 downto 0);
signal udp_tx_full	: STD_LOGIC := '0';
signal udp_tx_empty	: STD_LOGIC := '0';

signal udp_get_char	: STD_LOGIC := '0';
signal udp_get_ack	: STD_LOGIC := '0';
signal udp_rx_char	: STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
signal udp_rx_empty	: STD_LOGIC := '0';

begin

udp : entity work.udp_uart
generic map (
	PORT_NR				=> PORT_NR,
	
	RX					=> RX,
	TX					=> TX
)
port map (
	CLK_I				=> CLK_I,
	RESET_I				=> RESET_I,
	
	RX_BUSY_O			=> open,
	TX_BUSY_O			=> open,
	
	UDP_RX_DONE_I		=> UDP_RX_DONE_I,
	UDP_RX_DV_I			=> UDP_RX_DV_I,
	UDP_RX_DATA_I		=> UDP_RX_DATA_I,
	UDP_RX_SRC_IP_I		=> UDP_RX_SRC_IP_I,
	UDP_RX_SRC_MAC_I	=> UDP_RX_SRC_MAC_I,
	UDP_RX_SRC_PORT_I	=> UDP_RX_SRC_PORT_I,
	UDP_RX_DST_PORT_I	=> UDP_RX_DST_PORT_I,
	
	UDP_TX_START_O		=> UDP_TX_START_O,
	UDP_TX_READY_I		=> UDP_TX_READY_I,
	UDP_TX_RTS_O		=> UDP_TX_RTS_O,
	UDP_TX_BUSY_I		=> UDP_TX_BUSY_I,
	
	UDP_TX_DV_O			=> UDP_TX_DV_O,
	UDP_TX_DATA_O		=> UDP_TX_DATA_O,
	UDP_TX_DST_IP_O		=> UDP_TX_DST_IP_O,
	UDP_TX_DST_MAC_O	=> UDP_TX_DST_MAC_O,
	UDP_TX_SRC_PORT_O	=> UDP_TX_SRC_PORT_O,
	UDP_TX_DST_PORT_O	=> UDP_TX_DST_PORT_O,
	UDP_TX_DATA_SIZE_O	=> UDP_TX_DATA_SIZE_O,
	
	RTS_I				=> udp_rts,
	PUT_CHAR_I			=> udp_put_char,
	PUT_ACK_O			=> udp_put_ack,
	TX_CHAR_I			=> udp_tx_char,
	TX_FULL_O			=> udp_tx_full,
	TX_EMPTY_O			=> udp_tx_empty,
	
	GET_CHAR_I			=> udp_get_char,
	GET_ACK_O			=> udp_get_ack,
	RX_CHAR_O			=> udp_rx_char,
	RX_EMPTY_O			=> udp_rx_empty
);

TX_ENABLE : if TX = TRUE generate

TX_MODE_SLOW : if MODE = "SLOW" generate

tx_fsm : entity work.uart_tx
	GENERIC MAP (
		OVERSAMPLE	=> OVERSAMPLE,
		DATA_BITS	=> DATA_BITS,
		PARITY_BIT	=> PARITY_BIT,
		STOP_BITS	=> STOP_BITS
	)
	PORT MAP (
		RESET_I		=> RESET_I,
		CLK_I		=> CLK_I,
		OS_CLK_I	=> os_clk,
		
		TX_O		=> TX_O,
		
		TX_CHAR_I	=> tx_char,
		SEND_I		=> send,
		BUSY_O		=> tx_busy
	);
	
end generate;

TX_MODE_FAST : if MODE = "FAST" generate

tx_fsm : entity work.uart_fast_tx
	GENERIC MAP (
		DIVIDER		=> integer(CLK_MHZ * 1000000.0 / real(BAUDRATE)),	-- 125MHz / 25MHz = 5
		DATA_BITS	=> DATA_BITS,
		PARITY_BIT	=> PARITY_BIT,
		STOP_BITS	=> STOP_BITS,
		START_BIT	=> START_BIT
	)
	PORT MAP (
		RST_I		=> RESET_I,
		CLK_I		=> CLK_I,
		
		TX_O		=> TX_O,
		
		TX_CHAR_I	=> tx_char,
		SEND_I		=> send,
		BUSY_O		=> tx_busy
	);

end generate;

transmit : process(CLK_I)		-- Transmit chars
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			tx_state 		<= S_TX_IDLE;
			tx_char			<= (others => '0');
			send 			<= '0';
		else
			TX_DONE_O 		<= '0'; 
			udp_get_char 	<= '0';
		
			case tx_state is
			when S_TX_IDLE =>
				if (udp_rx_empty = '0') then	-- FIFO not empty -> send chars
					udp_get_char	<= '1';
					tx_state 		<= S_TX_READ;
				end if;
				
			when S_TX_READ =>
				if (udp_get_ack = '1') then
					tx_char 		<= udp_rx_char;
					send 			<= '1';
					tx_state 		<= S_TX_PUT;
				end if;
				
			when S_TX_PUT =>
				if (tx_busy = '1') then
					send 		<= '0';
					tx_state 	<= S_TX_WAIT;
				end if;
			
			when S_TX_WAIT =>
				if (tx_busy = '0') then
					tx_state <= S_TX_IDLE;
					
					if (udp_rx_empty = '1') then		-- This was the last char
						TX_DONE_O <= '1';
					end if;
					
				end if;
			end case;
		end if;
	end if;
end process transmit;

end generate;	-- TX_ENABLE = TRUE

TX_DISABLE : if TX = FALSE generate

transmit : process(CLK_I)		-- "Transmit" chars to keep fifo from overflowing
begin
	if rising_edge(CLK_I) then
		udp_get_char <= udp_rx_empty;
	end if;
end process;

end generate;	-- TX_ENABLE = FALSE

RX_ENABLE : if RX = TRUE generate
	
RX_MODE_SLOW : if MODE = "SLOW" generate
	
rx_fsm : entity work.uart_rx
	GENERIC MAP (
		OVERSAMPLE	=> OVERSAMPLE,
		DATA_BITS	=> DATA_BITS,
		PARITY_BIT	=> PARITY_BIT,
		STOP_BITS	=> STOP_BITS
	)
	PORT MAP (
		RESET_I		=> RESET_I,
		CLK_I		=> CLK_I,
		OS_CLK_I 	=> os_clk,
		
		RX_I		=> RX_I,
		RX_CHAR_O	=> rx_char,
		RECV_O		=> recv
	);

end generate;

RX_MODE_FAST : if MODE = "FAST" generate	

rx_fsm : entity work.uart_fast_rx
	GENERIC MAP (
		DIVIDER		=> integer(CLK_MHZ * 1000000.0 / real(BAUDRATE)),
		DATA_BITS	=> DATA_BITS,
		PARITY_BIT	=> PARITY_BIT,
		STOP_BITS	=> STOP_BITS,
		START_BIT	=> START_BIT,
		ALIGNMENT	=> FALSE
	)
	PORT MAP (
		RST_I		=> RESET_I,
		CLK_I		=> CLK_I,
		
		RX_I		=> RX_I,
		
		RX_CHAR_O	=> rx_char,
		RECV_O		=> recv,
		
		IDLE_O		=> rx_idle
	);

end generate;

receive : process(CLK_I)	-- Put chars into FIFO
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			rx_state		<= S_RX_IDLE;
			udp_tx_char 	<= (others => '0');
			udp_put_char	<= '0';
		else
			udp_rts <= '0';
			
			case rx_state is
			when S_RX_IDLE =>
						
				if (recv = '1' AND udp_tx_full = '0') then	-- New char received and FIFO not full
					idle_chars		<= 0;
				
					udp_put_char	<= '1';
					udp_tx_char		<= rx_char;
					rx_state		<= S_RX_PUT;
				else
					if rx_idle = '1' and udp_tx_empty = '0' then
						if idle_chars < MAX_IDLECHARS then
							idle_chars <= idle_chars + 1;
						else
							idle_chars <= 0;
							udp_rts <= '1';
						end if;
					end if;
				end if;
		
			when S_RX_PUT =>
				if (udp_put_ack = '1') then
					udp_put_char	<= '0';
					rx_state		<= S_RX_WAIT;
				end if;
				
			when S_RX_WAIT =>
				if (recv = '0') then
					rx_state <= S_RX_IDLE;
				end if;
				
			end case;
		end if;
	end if;
end process receive;

end generate;	-- RX_ENABLE = TRUE

RX_DISABLE : if RX = FALSE generate

-- Nothing to do here

end generate;	-- RX_ENABLE = FALSE

CLK_MODE : if MODE = "SLOW" generate

baud_gen : entity work.uart_baudrate
	generic map (
		OVERSAMPLE	=> OVERSAMPLE,
		CLOCKRATE	=> integer(CLK_MHZ* 1000000.0),
		BAUDRATE	=> BAUDRATE
	)
	port map (
		RESET_I		=> RESET_I,
		CLK_I		=> CLK_I,
		OS_CLK_O	=> os_clk
	);

end generate;

-- No Oversampling Clock necessary in MODE=FAST

end Behavioral;