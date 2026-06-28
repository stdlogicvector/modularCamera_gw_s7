library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity udp_arbiter is
	Generic (
		PORTS	: natural	:= 2
	);
	Port(
	-- system signals
		CLK_I			: in	std_logic;
		RESET_I			: in	std_logic;
		
	-- UDP
		UDP_TX_BUSY_I	: in	std_logic := '0';
	
	-- Ports
		PORT_TX_RTS_I	: in	std_logic_vector(PORTS-1 downto 0);	-- 0 = highest priority
		PORT_TX_BUSY_O	: out	std_logic_vector(PORTS-1 downto 0) := (others => '1')
	);
end udp_arbiter;

architecture Behavioral of udp_arbiter is

type state_t is (
	S_IDLE,
	S_ENABLE_PORT,
	S_SENDING
);

signal state		: state_t := S_IDLE;
signal highest_port	: natural := 0;

begin

arbitrate : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			state			<= S_IDLE;
			PORT_TX_BUSY_O	<= (others => '1');
		else
		
			case (state) is
			when S_IDLE =>
				PORT_TX_BUSY_O <= (others => '1');	-- hold in busy until selected
				
				if (UDP_TX_BUSY_I = '0' AND PORT_TX_RTS_I /= fill(PORTS, '0')) then

					for i in 0 to PORTS-1 loop
						if (PORT_TX_RTS_I(i) = '1') then
							highest_port <= i;
							exit;
						end if;
					end loop;

					state <= S_ENABLE_PORT;
				end if;
					
			when S_ENABLE_PORT =>
				PORT_TX_BUSY_O(highest_port) <= '0';
				state <= S_SENDING;
				
			when S_SENDING=>
				if (PORT_TX_RTS_I(highest_port) = '0') then 
					state <= S_IDLE;
					PORT_TX_BUSY_O <= (others => '1');
				end if;
			
			end case;
		end if;
	end if;
end process;

end Behavioral;
