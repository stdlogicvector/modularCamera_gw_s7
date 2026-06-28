library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity icmp_encoder is
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
		HEADER_I		: in	std_logic_vector(31 downto 0)

	);
end icmp_encoder;

architecture Behavioral of icmp_encoder is
	-- types
	type state_t is (
		S_IDLE,
		S_CRC_GEN,
		S_WAIT_FOR_ETH,
		S_WAIT_FOR_RDY,
		S_TYPE,
		S_CODE,
		S_CHECKSUM,
		S_HEADER,
		S_PAYLOAD
	);
	
	type data_buf_t is array (0 to 63) of std_logic_vector(7 downto 0);
	
	signal payload_buf : data_buf_t := (others => (others => '0'));
	signal payload_wr : std_logic_vector(5 downto 0) := (others => '0');
	
	-- statemachine
	signal state 		: state_t := S_IDLE;

	-- counters
	signal byte_count 	: integer range 0 to 63 := 0;
	
	-- control signals
	signal active 		: std_logic := '0';
	
	signal start		: std_logic := '0';
	signal dv			: std_logic := '0';
	signal TX_DATA_O	: std_logic_vector(7 downto 0) := (others => '0');
	
	-- crc signals
	signal crc_reset 	: std_logic := '1';
	signal crc_enable	: std_logic := '0';
	signal crc_out		: std_logic_vector(15 downto 0) := (others => '0');
	signal crc_en		: std_logic := '0';
	
	-- fields of the ip HEADER_I
	signal dst_mac	: std_logic_vector(47 downto 0) := (others => '0');
	signal dst_ip	: std_logic_vector(31 downto 0) := (others => '0');
	signal header	: std_logic_vector(31 downto 0) := (others => '0');
	signal pkt_len	: std_logic_vector(15 downto 0) := (others => '0');
	signal data_len	: std_logic_vector(15 downto 0) := (others => '0');
	signal checksum	: std_logic_vector(15 downto 0) := (others => '0');
		
begin

---------------------------------------------------------------------------------------------
-- signal assignments
---------------------------------------------------------------------------------------------

START_O 	<= start 	 when active = '1' else '0';
DV_O	 	<= dv	   	 when active = '1' else '0';
DATA_O  	<= TX_DATA_O when active = '1' else (others => 'Z');

DST_IP_O	<= dst_ip	when active = '1' else (others => 'Z');
DST_MAC_O	<= dst_mac	when active = '1' else (others => 'Z');
PROTOCOL_O	<= x"01" 	when active = '1' else (others => 'Z');
LENGTH_O	<= pkt_len	when active = '1' else (others => 'Z');

---------------------------------------------------------------------------------------------
-- processes
---------------------------------------------------------------------------------------------

fsm: process(CLK_I)
procedure transmit(p : std_logic_vector; next_state : state_t) is
	begin
		-- we split the vector into bytes and send them
		if (byte_count < (p'length/8)) then
			TX_DATA_O <= byte(p, byte_count);
		end if;
			
		-- on the next-to-eol byte we change to the next state
		if (byte_count = (p'length/8) - 1)
		then
			byte_count <= 0;
			state <= next_state;
		end if;
	end procedure;
begin
	if (rising_edge(CLK_I)) then
		if (RESET_I = '1') then
			state <= S_IDLE;
			crc_reset 	<= '1';
			crc_enable	<= '0';
			active 		<= '0';
			BUSY_O	<= '0';
			payload_wr	<= (others => '0');
		else
			start <= '0';
			TX_DATA_O <= (others => '0');
			
			crc_en <= crc_enable;
			
			if (DV_I = '1') then
				payload_wr	<= inc(payload_wr);
				payload_buf(vec2int(payload_wr)) <= DATA_I;	
			end if;
		
			if state /= S_IDLE AND (READY_I = '1' OR crc_enable = '1') then
				byte_count <= byte_count + 1;
			end if;
			
			case state is 
			when S_IDLE =>
				dv	  <= '0';
				READY_O <= '0';
				BUSY_O <= '0';
				crc_reset <= '1';
				active <= '0';
				byte_count <= 0;

				if (START_I = '1') then
					BUSY_O <= '1';
					state 		<= S_CRC_GEN;
					dst_mac 	<= DST_MAC_I;
					dst_ip 		<= DST_IP_I;
					header		<= HEADER_I;
					data_len	<= "0000000000" & payload_wr;
					pkt_len(6 downto 0) <= add(payload_wr, 8, 7); -- +8 Bytes Header
					payload_wr	<= (others => '0');
				end if;
				
			when S_CRC_GEN =>
				checksum	<= (others => '0');
				crc_enable	<= '1';
				crc_reset 	<= '0';
				byte_count  <= 0;
				state 		<= S_TYPE;
			
			when S_WAIT_FOR_ETH =>
				if (BUSY_I = '0') then
					active 	<= '1';
					start 	<= '1';
					state <= S_WAIT_FOR_RDY;
				end if;
				
			when S_WAIT_FOR_RDY =>
				checksum <= crc_out(7 downto 0) & crc_out(15 downto 8);
				
				if (READY_I = '1') then
					byte_count <= 0;
					dv	  <= '1';
					state <= S_TYPE;
				end if;
			
			when S_TYPE =>
				transmit(x"00", S_CODE);
				
			when S_CODE =>
				transmit(x"00", S_CHECKSUM);
				
			when S_CHECKSUM =>
				transmit(checksum, S_HEADER);
				
			when S_HEADER =>
				transmit(header, S_PAYLOAD);
				
			when S_PAYLOAD =>
				TX_DATA_O <= payload_buf(byte_count);
				
				if (byte_count = vec2int(data_len) - 1) then
					byte_count <= 0;
					
					if (crc_enable = '1') then
						crc_enable <= '0';
						state <= S_WAIT_FOR_ETH;
					else
						state <= S_IDLE;
						dv	  <= '0';
					end if;
				end if;

			end case;
		end if;
	end if;
end process;

crc : entity work.crc16
port map(
	CLK_I		=> CLK_I,
	RESET_I		=> crc_reset,
	CRC_EN_I	=> crc_en,
	CRC_O		=> crc_out,
	DATA_I		=> TX_DATA_O
);

end Behavioral;

