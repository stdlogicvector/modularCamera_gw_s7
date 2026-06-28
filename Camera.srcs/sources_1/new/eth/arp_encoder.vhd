library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity arp_encoder is
	Generic (
		IP_ADDR		: std_logic_vector(31 downto 0)
	);
	Port (
		-- system signals
		CLK_I		: in	std_logic;
		RESET_I		: in	std_logic;
		
		MAC_ADDR_I	: in	std_logic_vector(47 downto 0);
		
		-- to upper layer
		START_O		: out	std_logic := '0';
		BUSY_I		: in	std_logic;
		READY_I		: in	std_logic;
		
		DV_O		: out 	std_logic := '0';
		DATA_O		: out	std_logic_vector(7 downto 0) := (others => 'Z');
		
		DST_MAC_O	: out	std_logic_vector(47 downto 0) := (others => 'Z');
		ETHERTYPE_O	: out	std_logic_vector(15 downto 0) := (others => 'Z');
		
		-- to lower layer
		START_I		: in	std_logic;
		BUSY_O		: out	std_logic := '0';
--		READY_O		: out	std_logic := '0';
		
		DST_MAC_I	: in	std_logic_vector(47 downto 0);
		DST_IP_I	: in	std_logic_vector(31 downto 0)

	);
end arp_encoder;

architecture Behavioral of arp_encoder is

	-- types
	type state_t is (
		S_IDLE,
		S_WAIT_FOR_ETH,
		S_WAIT_FOR_RDY,
		S_HW_TYPE,
		S_PROTO_TYPE,
		S_HW_LENGTH,
		S_PROTO_LENGTH,
		S_OPERATION,
		S_SRC_MAC,
		S_SRC_IP,
		S_DST_MAC,
		S_DST_IP,
		S_PADDING
	);
	
	constant PKT_LEN		: integer := 64;
	
	-- statemachine
	signal state : state_t := S_IDLE;

	-- local registers
	signal dst_mac	: std_logic_vector(47 downto 0) := (others => '0');
	signal dst_ip	: std_logic_vector(31 downto 0) := (others => '0');
	
	-- counters 
	signal byte_count	: integer range 0 to 63 := 0;
	
	-- control signals
	signal active 		: std_logic := '0';
	
	signal start		: std_logic := '0';
	signal dv			: std_logic := '0';
	signal TX_DATA_O	: std_logic_vector(7 downto 0) := (others => '0');	
	
begin

---------------------------------------------------------------------------------------------
-- signal assignments
---------------------------------------------------------------------------------------------

START_O 	<= start 	 when active = '1' else '0';
DV_O	  	<= dv	   	 when active = '1' else '0';
DATA_O  	<= TX_DATA_O when active = '1' else (others => 'Z');

DST_MAC_O   <= DST_MAC_I when active = '1' else (others => 'Z');
ETHERTYPE_O <= x"0806" 	 when active = '1' else (others => 'Z');

---------------------------------------------------------------------------------------------
-- processes
---------------------------------------------------------------------------------------------

fsm: process(CLK_I, RESET_I) is
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
			active <= '0';
			BUSY_O <= '0';
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
				--READY_O <= '0';
				active <= '0';
				byte_count <= 0;
				
				if (START_I = '1') then
					BUSY_O <= '1';
					state 	<= S_WAIT_FOR_ETH;
					dst_mac <= DST_MAC_I;
					dst_ip 	<= DST_IP_I;
				end if;
				
			when S_WAIT_FOR_ETH =>
				if (BUSY_I = '0') then
					active 	<= '1';
					start 	<= '1';
					state <= S_WAIT_FOR_RDY;
				end if;
				
			when S_WAIT_FOR_RDY =>
				if (READY_I = '1') then
					byte_count <= 0;
					dv	  <= '1';
					state <= S_HW_TYPE;
				end if;
				
			when S_HW_TYPE =>
				transmit(x"0100", S_PROTO_TYPE);
				
			when S_PROTO_TYPE =>
				transmit(x"0008", S_HW_LENGTH);
				
			when S_HW_LENGTH =>			
				transmit(x"06", S_PROTO_LENGTH);
				
			when S_PROTO_LENGTH =>
				transmit(x"04", S_OPERATION);
				
			when S_OPERATION =>
				transmit(x"0200", S_SRC_MAC);	-- ARP Reply
				
			when S_SRC_MAC =>			
				transmit(MAC_ADDR_I, S_SRC_IP);
				
			when S_SRC_IP =>
				transmit(IP_ADDR, S_DST_MAC);
				
			when S_DST_MAC =>			
				transmit(dst_mac, S_DST_IP);
				
			when S_DST_IP =>			
				transmit(dst_ip, S_PADDING);
						
			when S_PADDING =>
				TX_DATA_O <= (others => '0');		-- pad the rest of the packet with zeroes
				
				if (byte_count = PKT_LEN - 28 - 1) then
					state <= S_IDLE;
					dv	  <= '0';				
				end if;
				
			end case;
		end if;
	end if;
end process;

end Behavioral;

