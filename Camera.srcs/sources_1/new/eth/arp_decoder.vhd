library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity arp_decoder is
	Generic (
		IP_ADDR		: std_logic_vector(31 downto 0)
	);
	port(
		-- system signals
		CLK_I			: in	std_logic;
		RESET_I			: in	std_logic;
		
		MAC_ADDR_I		: in	std_logic_vector(47 downto 0);
		
		-- from upper layer
		ETH_TYPE_I		: in	std_logic_vector(15 downto 0) := (others => '0');
		ETH_DV_I		: in	std_logic;
		ETH_DATA_I		: in	std_logic_vector(7 downto 0);
		ETH_DONE_I      : in    std_logic;
		
		-- to next layer
		DONE_O			: out	std_logic := '0';
		--DV_O			: out	std_logic := '0';
		--DATA_O		: out	std_logic_vector( 7 downto 0) := (others => '0');
		BUSY_O          : out   std_logic := '0';
		
		-- header data
		SRC_IP_O		: out 	std_logic_vector(31 downto 0) := (others => '0');
		SRC_MAC_O		: out	std_logic_vector(47 downto 0) := (others => '0')
	);
end arp_decoder;

architecture Behavioral of arp_decoder is
	-- types
	type state_t is (
		S_SKIP_HEADER,
		S_OPERATION,
		S_SRC_MAC,
		S_SRC_IP,
		S_DST_MAC,
		S_DST_IP,
		S_PAYLOAD,
		S_SKIP_PACKET
	);
	
	-- statemachine
	signal state 	: state_t := S_SKIP_HEADER;

	-- counters
	signal byte_count 	: integer range 0 to 7 := 0;
	
	-- fields of the arp header
	signal src_mac_addr	: std_logic_vector(47 downto 0) := (others => '0');
	signal src_ip_addr	: std_logic_vector(31 downto 0) := (others => '0');
	signal dst_mac_addr	: std_logic_vector(47 downto 0) := (others => '0');
	signal dst_ip_addr	: std_logic_vector(31 downto 0) := (others => '0');
	
	signal addr_match	: std_logic := '0';

begin

---------------------------------------------------------------------------------------------
-- signal assignments
---------------------------------------------------------------------------------------------

addr_match <= '1' when dst_ip_addr = IP_ADDR else '0';

--DONE_O <= '1' when (state = S_PAYLOAD AND ETH_DV_I = '0') else '0';

---------------------------------------------------------------------------------------------
-- processes
---------------------------------------------------------------------------------------------

rx: process(CLK_I)
procedure receive(l : integer; next_state : state_t) is
begin
	if (byte_count = l-1) then
		byte_count <= 0;
		state <= next_state;
	else
		byte_count <= byte_count + 1;
	end if;
end procedure;

begin
	if (rising_edge(CLK_I)) then
		if (RESET_I = '1') then
			state  <= S_SKIP_HEADER;
			BUSY_O <= '0';
		else
			--DV_O <= '0';
			DONE_O <= '0';
			
			if (ETH_DONE_I = '1') then
			     state <= S_SKIP_HEADER;
			     BUSY_O <= '0';
			end if;
			
			if (ETH_DV_I = '1' AND ETH_TYPE_I = x"0806")
			then
				case state is
				when S_SKIP_HEADER =>
				    BUSY_O <= '1';
					receive(7, S_OPERATION);
					 
				when S_OPERATION =>
					if (ETH_DATA_I = x"01") then	-- ARP Request
						state <= S_SRC_MAC;
					else 
						state <= S_SKIP_PACKET;
					end if;
				
				when S_SRC_MAC =>
					src_mac_addr <= ETH_DATA_I & src_mac_addr(47 downto 8);
					receive(6, S_SRC_IP);
					
				when S_SRC_IP =>
					src_ip_addr <= ETH_DATA_I & src_ip_addr(31 downto 8);
					receive(4, S_DST_MAC);
				
				when S_DST_MAC =>
					dst_mac_addr <= ETH_DATA_I & dst_mac_addr(47 downto 8);
					receive(6, S_DST_IP);
					
				when S_DST_IP =>
					dst_ip_addr <= ETH_DATA_I & dst_ip_addr(31 downto 8);
					receive(4, S_PAYLOAD);
					
				when S_PAYLOAD =>
					--DATA_O <= ETH_DATA_I;
					--DV_O <= addr_match;
					
					SRC_MAC_O	<= src_mac_addr;
					SRC_IP_O	<= src_ip_addr;
				
					DONE_O <= addr_match;
					state <= S_SKIP_PACKET;
				
				when S_SKIP_PACKET =>
					null;
					
				end case;
				
			else
			end if;	
		end if;
	end if;
end process;

end Behavioral;

