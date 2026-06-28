library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity udp_decoder is
	port(
		-- system signals
		CLK_I			: in	std_logic;
		RESET_I			: in	std_logic;
		
		-- from upper layer
		IP4_DV_I		: in	std_logic;
		IP4_DATA_I		: in	std_logic_vector(7 downto 0);
		IP4_PROTO_I		: in	std_logic_vector(7 downto 0);
		IP4_LENGTH_I	: in	std_logic_vector(15 downto 0);
        IP4_DONE_I      : in    std_logic;		
		
		-- to next layer
		DONE_O			: out	std_logic;
		DV_O			: out	std_logic;
		DATA_O			: out	std_logic_vector( 7 downto 0) := (others => '0');
		
		-- header data
		SRC_PORT_O		: out 	std_logic_vector(15 downto 0) := (others => '0');
		DST_PORT_O		: out 	std_logic_vector(15 downto 0) := (others => '0')
		
	);
end udp_decoder;

architecture Behavioral of udp_decoder is
	-- types
	type state_t is (
		S_SRC_PORT,
		S_DST_PORT,
		S_LENGTH,
		S_CHECKSUM,
		S_PAYLOAD,
		S_SKIP_PACKET
	);
	
	-- statemachine
	signal state 	: state_t := S_SRC_PORT;

	-- counters
	signal byte_count 	: integer range 0 to 2 := 0;
	signal eol_dv		: std_logic := '0';
	
	-- fields of the udp header
	signal src_port		: std_logic_vector(15 downto 0) := (others => '0');
	signal dst_port		: std_logic_vector(15 downto 0) := (others => '0');
	signal data_len		: std_logic_vector(15 downto 0) := (others => '0');
	
	--
	signal proto_match  : std_logic := '0';

begin

---------------------------------------------------------------------------------------------
-- signal assignments
---------------------------------------------------------------------------------------------
proto_match <= '1' when (IP4_PROTO_I = x"11") else '0';

---------------------------------------------------------------------------------------------
-- processes
---------------------------------------------------------------------------------------------

fsm: process(CLK_I)
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
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			state 	<= S_SRC_PORT;
			eol_dv	<= '0';
		else
			DV_O <= '0';
			eol_dv <= IP4_DV_I;
			DONE_O <= '0';

		    if (IP4_DONE_I = '1') then
                state <= S_SRC_PORT;
                DONE_O <= proto_match;

			elsif (proto_match = '1')
			then
				--DONE_O <= eol_dv AND NOT IP4_DV_I; -- Falling Edge Detector
				
				if (IP4_DV_I = '1')
				then
					case state is 
					when S_SRC_PORT =>
						src_port <= src_port(7 downto 0) & IP4_DATA_I ;
						receive(2, S_DST_PORT);
					
					when S_DST_PORT =>
						dst_port <= dst_port(7 downto 0) & IP4_DATA_I;
	
						receive(2, S_LENGTH);
						
					when S_LENGTH =>
						data_len <= data_len(7 downto 0) & IP4_DATA_I;
	
						receive(2, S_CHECKSUM);
						
					when S_CHECKSUM =>
						receive(2, S_PAYLOAD);
					
					when S_PAYLOAD =>
						DV_O <= '1';
						DATA_O <= IP4_DATA_I;
					
						DST_PORT_O <= dst_port;
						SRC_PORT_O <= src_port;
					
						if (data_len = int2vec(8, 16)) then	-- 8 Bytes Header
							state <= S_SKIP_PACKET;
						else
							data_len <= dec(data_len);
						end if;
						
					when S_SKIP_PACKET =>
						DATA_O <= (others => '0'); -- Wait here until next packet comes in
					end case;
				end if;		
			end if;	
		end if;
	end if;
end process;

end Behavioral;

