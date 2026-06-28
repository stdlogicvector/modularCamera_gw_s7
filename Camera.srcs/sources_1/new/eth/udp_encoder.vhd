library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity udp_encoder is
	port(
		-- system signals
		CLK_I			: in	std_logic;
		RESET_I			: in	std_logic;
		
		-- to upper layer
		START_O			: out	std_logic := '0';
		BUSY_I			: in	std_logic;
		READY_I			: in	std_logic;
		
		DV_O			: out 	std_logic := '0';
		DATA_O			: out	std_logic_vector(7 downto 0) := (others => 'Z');
		
		DST_IP_O		: out	std_logic_vector(31 downto 0) := (others => 'Z');
		DST_MAC_O		: out	std_logic_vector(47 downto 0) := (others => 'Z');
		PROTOCOL_O		: out	std_logic_vector( 7 downto 0) := (others => 'Z');
		LENGTH_O		: out	std_logic_vector(15 downto 0) := (others => 'Z');
		
		-- to lower layer
		START_I			: in	std_logic;
		BUSY_O			: out	std_logic := '0';
		READY_O			: out	std_logic := '0';
		
		DV_I			: in 	std_logic;
		DATA_I			: in	std_logic_vector(7 downto 0) := (others => '0');
		
		DST_MAC_I		: in	std_logic_vector(47 downto 0);
		DST_IP_I		: in	std_logic_vector(31 downto 0);
		SRC_PORT_I		: in	std_logic_vector(15 downto 0);
		DST_PORT_I		: in	std_logic_vector(15 downto 0);
		LENGTH_I		: in	std_logic_vector(15 downto 0)

	);
end udp_encoder;

architecture Behavioral of udp_encoder is
	-- types
	type state_t is (
		S_IDLE,
		S_WAIT_FOR_ETH,
		S_WAIT_FOR_RDY,
		S_SRC_PORT,
		S_DST_PORT,
		S_LENGTH,
		S_CHECKSUM,
		S_PAYLOAD
	);
	
	-- statemachine
	signal state 	: state_t := S_IDLE;

	-- counters
	signal byte_count 	: integer range 0 to 2 := 0;
	
	-- control signals
	signal active 	: std_logic := '0';
	
	signal start	: std_logic := '0';
	signal dv		: std_logic := '0';
	signal TX_DATA_O	: std_logic_vector(7 downto 0) := (others => '0');
	
	-- fields of the ip header
	signal dst_mac	: std_logic_vector(47 downto 0) := (others => '0');
	signal dst_ip	: std_logic_vector(31 downto 0) := (others => '0');
	signal dst_port	: std_logic_vector(15 downto 0) := (others => '0');
	signal src_port	: std_logic_vector(15 downto 0) := (others => '0');
	signal pkt_len	: std_logic_vector(15 downto 0) := (others => '0');
	signal checksum	: std_logic_vector(15 downto 0) := (others => '0');
		
begin

---------------------------------------------------------------------------------------------
-- signal assignments
---------------------------------------------------------------------------------------------

START_O 	<= start		when active = '1' else '0';
DV_O	  	<= dv			when active = '1' else '0';
DATA_O  	<= TX_DATA_O	when active = '1' else (others => 'Z');

DST_IP_O	<= dst_ip	when active = '1' else (others => 'Z');
DST_MAC_O	<= dst_mac	when active = '1' else (others => 'Z');
PROTOCOL_O 	<= x"11" 	when active = '1' else (others => 'Z');
LENGTH_O	<= pkt_len	when active = '1' else (others => 'Z');

---------------------------------------------------------------------------------------------
-- processes
---------------------------------------------------------------------------------------------

fsm: process(CLK_I)
procedure transmit(p : std_logic_vector; next_state : state_t) is
	begin
		-- we split the vector into bytes and send them MSB first
		if (byte_count < (p'length/8)) then
			TX_DATA_O <= byte(p, (p'length/8) - byte_count - 1);
		end if;
			
		-- on the next-to-eol byte we change to the next state
		if (byte_count = (p'length/8) - 1)
		then
			byte_count <= 0;
			state <= next_state;
		end if;
	end procedure;
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			state 	<= S_IDLE;
			active 	<= '0';
			BUSY_O	<= '0';
		else
			start <= '0';
			TX_DATA_O <= (others => '0');
			
			if (state /= S_IDLE AND READY_I = '1') then
				byte_count <= byte_count + 1;
			end if;
			
			case state is 
			when S_IDLE =>
				dv	  <= '0';
				BUSY_O <= '0';
				READY_O <= '0';
				active <= '0';

				if (START_I = '1') then
					BUSY_O <= '1';
					state 		<= S_WAIT_FOR_ETH;
					dst_mac	 	<= DST_MAC_I;
					dst_ip 		<= DST_IP_I;
					dst_port	<= DST_PORT_I;
					src_port	<= SRC_PORT_I;
					pkt_len 	<= add(LENGTH_I, 8);  -- +8 Bytes Header
				end if;
				
			when S_WAIT_FOR_ETH =>
				byte_count	<= 0;				

				if (BUSY_I = '0') then
					active 	<= '1';
					start 	<= '1';
					state <= S_WAIT_FOR_RDY;
				end if;
				
			when S_WAIT_FOR_RDY =>
				byte_count	<= 0;

				if (READY_I = '1') then
					dv	  		<= '1';
					state		<= S_SRC_PORT;
				end if;
			
			when S_SRC_PORT =>
				transmit(src_port, S_DST_PORT);
				
			when S_DST_PORT =>
				transmit(dst_port, S_LENGTH);
				
			when S_LENGTH =>
				transmit(pkt_len, S_CHECKSUM);
				
				if (byte_count = 1) then
					READY_O <= '1';
				end if;
				
			when S_CHECKSUM =>
				transmit(x"0000", S_PAYLOAD);
			
			when S_PAYLOAD =>
				TX_DATA_O	<= DATA_I;
				dv			<= DV_I;
				byte_count	<= 0;
				
				if (DV_I = '0') then
					state <= S_IDLE;
				end if;

			end case;
		end if;
	end if;
end process;

end Behavioral;

