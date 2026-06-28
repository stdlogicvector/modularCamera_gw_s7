library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity eth_decoder is
	port(				
		-- system signals
		CLK_I      	: in	std_logic;
		RESET_I		: in 	std_logic;
	
		MAC_ADDR_I	: std_logic_vector(47 downto 0);
	
		-- GMII interface
		PHY_RXD_I	  : in std_logic_vector(7 downto 0);
		PHY_RX_DV_I	  : in std_logic;
		PHY_RX_ER_I	  : in std_logic;
		PHY_RX_EMPTY  : in std_logic;
		
		-- to next layer
		DONE_O		: out	std_logic := '0';
		DV_O		: out	std_logic := '0';
		DATA_O		: out	std_logic_vector( 7 downto 0) := (others => '0');
        BUSY_O      : out   std_logic := '0';

		-- header data
		ETHERTYPE_O	: out	std_logic_vector(15 downto 0) := (others => '0');
		SRC_MAC_O	: out	std_logic_vector(47 downto 0) := (others => '0')
		
		;DEBUG_O	: out	std_logic_vector(7 downto 0) := (others => '0')
	);
end eth_decoder;

architecture Behavioral of eth_decoder is
	-- types
	type state_t is (
	S_SFD,
	S_DST_MAC,
	S_SRC_MAC,
	S_ETHERTYPE,
	S_PAYLOAD,
	S_SKIP_PKT
	);

	--counters
	signal byte_count  	: integer range 0 to 7 := 0;

	-- receiver state machine
	signal state : state_t := S_SFD;
	
	-- ethernet frame
	signal dst_mac		: std_logic_vector(47 downto 0) := (others => '0');
	signal src_mac		: std_logic_vector(47 downto 0) := (others => '0');
	signal ethertype	: std_logic_vector(15 downto 0) := (others => '0');
	
	signal addr_match	: std_logic := '0';
begin

addr_match <= '1' when dst_mac = MAC_ADDR_I or dst_mac = x"FFFFFFFFFFFF" else '0';

DONE_O <= '1' when (state = S_PAYLOAD AND PHY_RX_DV_I = '0') else '0';

DEBUG_O(2 downto 0) <= int2vec(state_t'pos(state), 3);

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
			state 	<= S_SFD;
			BUSY_O <= '0';
		else
			DV_O <= '0';
			DEBUG_O(7 downto 3) <= (others => '0');
			
			if (PHY_RX_DV_I = '1' AND PHY_RX_ER_I = '0')
			then
                BUSY_O <= '1';
			
			    if (PHY_RX_EMPTY = '0') then 
                    case state is
                    when S_SFD =>
						DEBUG_O(4) <= '1';
                        
						if (PHY_RXD_I = "11010101") then
                            byte_count 	<= 0;
                            state 		<= S_DST_MAC;
							DEBUG_O(5) <= '1';
                        end if;
                        
                    when S_DST_MAC =>
                        dst_mac <= PHY_RXD_I & dst_mac(47 downto 8);
                        
                        receive(6, S_SRC_MAC);
                        
                    when S_SRC_MAC =>
                        src_mac <= PHY_RXD_I & src_mac(47 downto 8);
        
                        receive(6, S_ETHERTYPE);
                        
                    when S_ETHERTYPE =>
                        ethertype <= ethertype(7 downto 0) & PHY_RXD_I; -- Shift in byte-swapped
                    
                        receive(2, S_PAYLOAD);
                    
                    when S_PAYLOAD =>
                        DATA_O <= PHY_RXD_I;
                        
                        DV_O <= addr_match;
                            
                        SRC_MAC_O 	<= src_mac;
                        ETHERTYPE_O <= ethertype;
                        
                        state <= S_PAYLOAD;
                    
                    when S_SKIP_PKT =>
                        null;
                    
                    end case;
				end if;
			else
				state <= S_SFD;
				BUSY_O <= '0';
			end if;
		end if;
	end if;
end process;

end Behavioral;

