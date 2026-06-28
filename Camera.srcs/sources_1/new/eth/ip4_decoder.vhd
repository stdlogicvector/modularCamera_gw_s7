library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity ip4_decoder is
	Generic (
		IP_ADDR		: std_logic_vector(31 downto 0)
	);
	port(
		-- system signals
		CLK_I			: in	std_logic;
		RESET_I			: in	std_logic;
		
		-- from upper layer
		ETH_TYPE_I		: in	std_logic_vector(15 downto 0) := (others => '0');
		ETH_DV_I		: in	std_logic;
		ETH_DATA_I		: in	std_logic_vector(7 downto 0);
		ETH_DONE_I      : in    std_logic;
		
		-- to next layer
		DONE_O			: out	std_logic := '0';
		DV_O			: out	std_logic := '0';
		DATA_O			: out	std_logic_vector( 7 downto 0) := (others => '0');
		BUSY_O          : out   std_logic;		

		-- header DATA_O
		SRC_IP_O		: out 	std_logic_vector(31 downto 0) := (others => '0');
		PROTOCOL_O		: out	std_logic_vector( 7 downto 0) := (others => '0');
		DATA_SIZE_O		: out	std_logic_vector(15 downto 0) := (others => '0')
	);
end ip4_decoder;

architecture Behavioral of ip4_decoder is
	-- types
	type state_t is (
		S_VERSION,
		S_SKIP_0,
		S_LENGTH,
		S_SKIP_1,
		S_PROTOCOL,
		S_CHECKSUM,
		S_SRC_IP,
		S_DST_IP,
		
		S_PAYLOAD,

		S_SKIP_PACKET
	);
	
	-- statemachine
	signal state 	: state_t := S_VERSION;

	-- counters
	signal byte_count 	: integer range 0 to 2047 := 0;
	
	constant ip_address : std_logic_vector(31 downto 0) := IP_ADDR;
	
	-- fields of the ip header
	signal src_ip_addr	: std_logic_vector(31 downto 0) := (others => '0');
	signal dst_ip_addr	: std_logic_vector(31 downto 0) := (others => '0');
	signal protocol_nr_i: std_logic_vector( 7 downto 0) := (others => '0');
	signal pkt_size		: std_logic_vector(15 downto 0) := (others => '0');
	signal data_size_i	: std_logic_vector(15 downto 0) := (others => '0');
		
	signal addr_match	: std_logic := '0';
begin

---------------------------------------------------------------------------------------------
-- signal assignments
---------------------------------------------------------------------------------------------

addr_match <= '1' when dst_ip_addr = ip_address or dst_ip_addr = x"FFFFFFFF" else '0';

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
			state  <= S_VERSION;
			BUSY_O <= '0';
		else
			DONE_O  <= '0';
			DV_O <= '0';

			if (ETH_DONE_I = '1') then
				state <= S_VERSION;
				BUSY_O <= '0';

			elsif (ETH_DV_I = '1' AND ETH_TYPE_I = x"0800")
			then
                BUSY_O <= '1';

				case state is 
				when S_VERSION =>
					if (ETH_DATA_I = x"45") then	-- IPv4 / 5*4 Bytes Header
						state <= S_SKIP_0;
					else 
						state <= S_SKIP_PACKET;
					end if;

				when S_SKIP_0 =>
					state <= S_LENGTH;
					byte_count <= 0;
					
				when S_LENGTH =>
					pkt_size <= pkt_size(7 downto 0) & ETH_DATA_I; -- Byte swapped
					receive(2, S_SKIP_1);
				
				when S_SKIP_1 =>
					receive(5, S_PROTOCOL);
					
				when S_PROTOCOL =>
					protocol_nr_i <= ETH_DATA_I;
					
					data_size_i <= sub(pkt_size, 20);	-- Subtract IP4 Header (20 bytes)
					
					byte_count <= 0;
					state <= S_CHECKSUM;
					
				when S_CHECKSUM =>
					receive(2, S_SRC_IP);
					
				when S_SRC_IP =>
					src_ip_addr <= ETH_DATA_I & src_ip_addr(31 downto 8);
					
					receive(4, S_DST_IP);
					
				when S_DST_IP =>
					dst_ip_addr <= ETH_DATA_I & dst_ip_addr(31 downto 8);
					
					receive(4, S_PAYLOAD);
					
				when S_PAYLOAD =>			
					DATA_O <= ETH_DATA_I;
					byte_count <= byte_count + 1;
					
					if (int2vec(byte_count, 16) < data_size_i) then
						DV_O <= addr_match;
						
						SRC_IP_O	<= src_ip_addr;
						PROTOCOL_O  <= protocol_nr_i;
						DATA_SIZE_O	<= data_size_i;
						
						state <= S_PAYLOAD;
					else
						state <= S_SKIP_PACKET;
						DONE_O  <= addr_match;
					end if;
					
				when S_SKIP_PACKET =>
					null;
					
				end case;
			end if;	
		end if;
	end if;
end process;

end Behavioral;

