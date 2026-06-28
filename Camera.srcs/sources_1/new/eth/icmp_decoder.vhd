library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity icmp_decoder is
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
		HEADER_O		: out 	std_logic_vector(31 downto 0) := (others => '0');
		
		SKIP_O : out std_logic
	);
end icmp_decoder;

architecture Behavioral of icmp_decoder is
	-- types
	type state_t is (
		S_TYPE,
		S_CODE,
		S_CHECKSUM,
		S_HEADER,
		S_PAYLOAD,
		S_SKIP_PACKET
	);
	
	-- statemachine
	signal state 	: state_t := S_TYPE;

	-- counters
	signal byte_count 	: integer range 0 to 3 := 0;
	signal eol_dv		: std_logic := '0';
	
	signal skip			: std_logic := '0';
		
	-- fields of the icmp HEADER_O
	signal icmp_header		: std_logic_vector(31 downto 0) := (others => '0');
	signal pkt_size			: std_logic_vector(15 downto 0) := (others => '0');
		
	--
	signal proto_match  : std_logic := '0';
	
begin

---------------------------------------------------------------------------------------------
-- signal assignments
---------------------------------------------------------------------------------------------

proto_match <= '1' when (IP4_PROTO_I = x"01") else '0';

SKIP_O <= skip;

---------------------------------------------------------------------------------------------
-- processes
---------------------------------------------------------------------------------------------

fsm: process(CLK_I, RESET_I)
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
			state 	<= S_TYPE;
			eol_dv	<= '0';
			skip	<= '1';
			DONE_O <= '0';
		else
			DV_O <= '0';
			eol_dv <= IP4_DV_I;
			DONE_O <= '0';
		
		    if (IP4_DONE_I = '1') then
                state <= S_TYPE;
                DONE_O <= proto_match AND NOT skip;
                skip <= '1';

		    elsif (proto_match = '1')
			then
				--DONE_O <= (eol_dv AND NOT IP4_DV_I) AND NOT skip;	-- Falling Edge Detector
				
				if (IP4_DV_I = '1')
				then			
					case state is 
					when S_TYPE =>
						pkt_size <= sub(IP4_LENGTH_I, 8);
						
						if (IP4_DATA_I = x"08") then				-- Echo Request
							state		<= S_CODE;
							byte_count	<= 0;
							skip		<= '0';
						else 
							state	<= S_SKIP_PACKET;
							skip	<= '1';
						end if;
					
					when S_CODE =>
						state <= S_CHECKSUM;
						byte_count <= 0;
						
					when S_CHECKSUM =>
						receive(2, S_HEADER);
					
					when S_HEADER =>
						icmp_header <= IP4_DATA_I & icmp_header(31 downto 8);
						receive(4, S_PAYLOAD);
						
					when S_PAYLOAD =>
						DV_O <= '1';
						DATA_O <= IP4_DATA_I;
					
						HEADER_O <= icmp_header;
					
						if (pkt_size = int2vec(0, 16)) then
							state <= S_SKIP_PACKET;
						else
							pkt_size <= dec(pkt_size);
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

