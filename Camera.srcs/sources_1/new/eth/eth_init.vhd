library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity eth_init is
	port (
		CLK_I			: in	std_logic;
		RESET_I			: in	std_logic;
		
		DONE_O			: out	std_logic := '0';
		
		CLK_READY_I		: in	std_logic;
		ETH_READY_I		: in	std_logic;
		
		TX_DIS_O		: out	std_logic := '1';

		ETH_CV_O		: out	std_logic := '0';
		ETH_CFG_O		: out	std_logic_vector(4 downto 0) := "11000";
		
		AN_CV_O			: out	std_logic := '0';
		AN_CFG_O		: out	std_logic_vector(15 downto 0) := x"01A0"
	);
end eth_init;

architecture Behavioral of eth_init is

type state_t is (
	WAIT_FOR_LOCK,
	WAIT_FOR_ETH,
	INIT_ETH,
	INIT_AUTO_NEG,
	IDLE
);

signal state 			: state_t := WAIT_FOR_LOCK;

begin

init : process (CLK_I)
begin
	if rising_edge(CLK_I)
	then
		if (RESET_I = '1')
		then
			state 			<= WAIT_FOR_LOCK;
			ETH_CFG_O		<= "11000";	-- AutoNeg + Isolate
			AN_CFG_O		<= x"01A0";
			ETH_CV_O		<= '0';
			AN_CV_O			<= '0';
			TX_DIS_O		<= '1';
			DONE_O			<= '0';
		else
			case (state) is
			when WAIT_FOR_LOCK =>
				if (CLK_READY_I = '1')
				then
					state <= WAIT_FOR_ETH;
				end if;
				
			when WAIT_FOR_ETH =>
				TX_DIS_O	<= '0';
				
				if (ETH_READY_I = '1') then
					state <= INIT_ETH;
				end if;
				
			when INIT_ETH =>
				ETH_CFG_O	<= "10000";	-- AutoNeg
				ETH_CV_O 	<= '1';
				
				state 		<= INIT_AUTO_NEG;
				
			when INIT_AUTO_NEG =>
				AN_CV_O	<= '1';
				state 	<= IDLE;

			when IDLE =>
				DONE_O	<= '1';
				state	<= IDLE;
				
			end case;
		end if;
	end if;
end process init;

end architecture;