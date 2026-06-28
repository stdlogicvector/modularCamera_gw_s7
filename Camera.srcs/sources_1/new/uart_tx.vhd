library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity uart_tx is
	generic (
		OVERSAMPLE	: integer := 16;		
		DATA_BITS	: integer := 8;			-- 6, 7, 8, 9
		PARITY_BIT	: character := 'N';		-- N(one), O(dd), E(ven)
		STOP_BITS	: real := 1.0			-- 1.0, 1.5, 2.0
	);
	port (
		RST_I		: in	STD_LOGIC;
		CLK_I		: in	STD_LOGIC;
		OS_CLK_I	: in	STD_LOGIC;
		
		TX_O		: out	STD_LOGIC;
		
		TX_CHAR_I	: in	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0);
		SEND_I		: in	STD_LOGIC;
		
		BUSY_O		: out 	STD_LOGIC
	);
end uart_tx;

architecture RTL of uart_tx is

constant STOPLENGTH		: integer := integer(round(real(OVERSAMPLE) * STOP_BITS));	-- Length of Stopbits in Oversampling Cycles

type state_t is (IDLE, START, DATA, PARITY, STOP);
signal state : state_t := IDLE;

signal tick	: integer range 0 to STOPLENGTH-1 := 0;
signal dbit	: integer range 0 to DATA_BITS-1  := 0;
signal char : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
signal prty : std_logic := '0';

begin

process(RST_I, CLK_I, OS_CLK_I)
begin
	if rising_edge(CLK_I) then
	if (RST_I = '1') then
		TX_O 		<= '1';
		BUSY_O	<= '0';
		tick 		<= 0;
		dbit 		<= 0;
		state 	<= IDLE;
	elsif (OS_CLK_I = '1') then			-- Use Oversampling Clock als Clock-Enable for normal Clock
		
		case (state) is
		when IDLE =>
			BUSY_O <= '0';
			
			if (SEND_I = '1') then
				char <= TX_CHAR_I;
				prty <= '0';

				BUSY_O <= '1';
				tick <= 0;
				state <= START;
			end if;
			
		when START =>
			TX_O <= '0';
			if (tick = OVERSAMPLE - 1) then
				tick	<= 0;
				dbit	<= 0;
				state <=	DATA;
			else
				tick <= tick + 1;
			end if;
			
		when DATA =>
			TX_O <= char(0);
			
			if (tick = OVERSAMPLE - 1) then
				tick <= 0;
				
				char <= '0' & char(DATA_BITS-1 downto 1);
				prty <= prty XOR char(0);
				
				if (dbit = DATA_BITS - 1) then
					dbit <= 0;
					
					if (PARITY_BIT /= 'N') then
						state <= PARITY;
					else
						state	<= STOP;
					end if;
				else
					dbit <= dbit + 1;
				end if;
			else
				tick <= tick + 1;
			end if;
		
		when PARITY =>
			if (PARITY_BIT = 'E') then
				TX_O <= prty;
			elsif (PARITY_BIT = 'O') then
				TX_O <= not prty;
			end if;
		
			if (tick = OVERSAMPLE - 1) then
				tick	<= 0;
				state <=	STOP;
			else
				tick <= tick + 1;
			end if;
			
		when STOP =>
			TX_O	<= '1';
			
			if (tick = STOPLENGTH - 1) then
				tick <= 0;
				state <= IDLE;
			else
				tick <= tick + 1;
			end if;	
		end case;
	end if;
	end if;
end process;

end RTL;

