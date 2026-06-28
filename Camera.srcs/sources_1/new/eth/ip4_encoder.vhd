library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity ip4_encoder is
	Generic (
		IP_ADDR		: std_logic_vector(31 downto 0)
	);
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
		
		DST_MAC_O		: out	std_logic_vector(47 downto 0) := (others => 'Z');
		ETHERTYPE_O		: out	std_logic_vector(15 downto 0) := (others => 'Z');
		
		-- to lower layer
		START_I			: in	std_logic;
		BUSY_O			: out	std_logic := '0';
		READY_O			: out	std_logic := '0';
		
		DV_I			: in 	std_logic;
		DATA_I			: in	std_logic_vector(7 downto 0) := (others => '0');
		
		DST_MAC_I		: in	std_logic_vector(47 downto 0);
		DST_IP_I		: in	std_logic_vector(31 downto 0);
		
		PROTOCOL_I		: in	std_logic_vector( 7 downto 0);
		DATA_SIZE_I		: in	std_logic_vector(15 downto 0)
	);
end ip4_encoder;

architecture Behavioral of ip4_encoder is
	-- types
	type state_t is (
		S_IDLE,
		S_CRC_GEN,
		S_WAIT_FOR_ETH,
		S_WAIT_FOR_RDY,
		S_VERSION,
		S_LENGTH,
		S_IDENT,
		S_FRAGMENT,
		S_TTL,
		S_PROTOCOL,
		S_CHECKSUM,
		S_SRC_IP,
		S_DST_IP_0,
		S_DST_IP_1,
		S_DST_IP_2,
		S_DST_IP_3,
		S_PAYLOAD
	);
	
	-- statemachine
	signal state 	: state_t := S_IDLE;

	-- counters
	signal byte_count 	: integer range 0 to 4 := 0;
	
	-- control signals
	signal active 	: std_logic := '0';
	
	signal start	: std_logic := '0';
	signal dv		: std_logic := '0';
	signal tx_data	: std_logic_vector(7 downto 0) := (others => '0');
	
	-- crc signals
	signal crc_reset 	: std_logic := '1';
	signal crc_enable	: std_logic := '0';
	signal crc_out		: std_logic_vector(15 downto 0) := (others => '0');
	signal crc_en		: std_logic := '0';
	
	-- fields of the ip header
	signal dst_mac		: std_logic_vector(47 downto 0) := (others => '0');
	signal dst_ip		: std_logic_vector(31 downto 0) := (others => '0');
	signal proto_nr		: std_logic_vector( 7 downto 0) := (others => '0');
	signal pkt_size		: std_logic_vector(15 downto 0) := (others => '0');
	signal data_size	: std_logic_vector(15 downto 0) := (others => '0');
	signal checksum		: std_logic_vector(15 downto 0) := (others => '0');
		
begin

---------------------------------------------------------------------------------------------
-- signal assignments
---------------------------------------------------------------------------------------------

START_O <= start 	 when active = '1' else '0';
DV_O	<= dv	   	 when active = '1' else '0';
DATA_O  <= tx_data	 when active = '1' else (others => 'Z');

DST_MAC_O   <= DST_MAC_I when active = '1' else (others => 'Z');
ETHERTYPE_O <= x"0800"   when active = '1' else (others => 'Z');

---------------------------------------------------------------------------------------------
-- processes
---------------------------------------------------------------------------------------------

fsm: process(CLK_I)
procedure transmit(p : std_logic_vector; next_state : state_t) is
	begin
		-- we split the vector into bytes and send them
		if (byte_count < (p'length/8)) then
			tx_data <= byte(p, byte_count);
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
		else
			start <= '0';
			tx_data <= (others => '0');
		
			crc_en <= crc_enable;
		
			if state /= S_IDLE AND (READY_I = '1' OR crc_enable = '1') then
				byte_count <= byte_count + 1;
			end if;
			
			case state is 
			when S_IDLE =>
				dv	 	  <= '0';	
				READY_O <= '0';
				BUSY_O  <= '0';				   
				crc_reset <= '1';
				active <= '0';
				
				if (START_I = '1') then
					BUSY_O <= '1';
					state 		<= S_CRC_GEN;
					dst_mac 	<= DST_MAC_I;
					dst_ip 		<= DST_IP_I;
					proto_nr	<= PROTOCOL_I;
					pkt_size	<= add(DATA_SIZE_I, 20);
					data_size	<= DATA_SIZE_I;
					byte_count	<= 0; 
				end if;
				
			when S_CRC_GEN =>
				checksum	<= (others => '0');
				crc_enable	<= '1';
				crc_reset 	<= '0';
				state 		<= S_VERSION;
			
			when S_WAIT_FOR_ETH =>
				if (BUSY_I = '0') then
					active 	<= '1';
					start 	<= '1';
					state <= S_WAIT_FOR_RDY;
				end if;
				
			when S_WAIT_FOR_RDY =>
				checksum <= crc_out(7 downto 0) & crc_out(15 downto 8);
				if (READY_I = '1') then
					byte_count	<= 0;
					dv	  		<= '1';
					state 		<= S_VERSION;
				end if;
			
			when S_VERSION =>
				transmit(x"0045", S_LENGTH);
				
			when S_LENGTH =>
				transmit(pkt_size(7 downto 0) & pkt_size(15 downto 8), S_IDENT);
				
			when S_IDENT =>
				transmit(x"0000", S_FRAGMENT);
				
			when S_FRAGMENT =>
				transmit(x"0040", S_TTL);	-- Don't fragment

			when S_TTL =>
				transmit(x"40", S_PROTOCOL);	-- TTL=64
				
			when S_PROTOCOL =>
				transmit(proto_nr, S_CHECKSUM);
				
			when S_CHECKSUM =>
				transmit(checksum, S_SRC_IP);
				
			when S_SRC_IP =>
				transmit(IP_ADDR, S_DST_IP_0);
				
			when S_DST_IP_0 =>
				tx_data <= dst_ip(7 downto 0);
				byte_count <= 0;
				state <= S_DST_IP_1;
				
			when S_DST_IP_1 =>
				tx_data <= dst_ip(15 downto 8);
				byte_count <= 0;
				state <= S_DST_IP_2;
				
				READY_O <= NOT crc_enable;	-- 2 cycles before payload is needed
				
			when S_DST_IP_2 =>
				tx_data <= dst_ip(23 downto 16);
				byte_count <= 0;
				state <= S_DST_IP_3;

			when S_DST_IP_3 =>
				tx_data <= dst_ip(31 downto 24);
				byte_count <= 0;
				
				if (crc_enable = '1') then
					crc_enable <= '0';
					state <= S_WAIT_FOR_ETH;
				else
					state <= S_PAYLOAD;
				end if;
				
			when S_PAYLOAD =>
				tx_data <= DATA_I;
				dv <= DV_I;
				
				byte_count <= 0;
								
				if (DV_I = '1') then
					state <= S_PAYLOAD;
				else
					state <= S_IDLE;
					--dv	 	   <= '0';	
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
	DATA_I		=> tx_data
);

end Behavioral;

