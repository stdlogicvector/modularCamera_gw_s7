library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use WORK.UTIL.ALL;

entity uart_rx is
	generic (
		OVERSAMPLE	: integer := 16;		
		DATA_BITS	: integer := 8;		-- 6, 7, 8, 9
		PARITY_BIT	: character := 'N';	-- N(one), O(dd), E(ven)
		STOP_BITS	: real := 1.0		-- 1.0, 1.5, 2.0
	);
	port (
		RST_I		: in	STD_LOGIC;
		CLK_I		: in	STD_LOGIC;
		OS_CLK_I	: in	STD_LOGIC;
		
		RX_I		: in	STD_LOGIC;
		
		RX_CHAR_O	: out	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
		RECV_O		: out	STD_LOGIC := '0'
	);
end uart_rx;

architecture RTL of uart_rx is

constant BITCENTER		: integer := integer(round(real(OVERSAMPLE) / 2.0));		-- Center of Bits = Sampling Point
constant STOPLENGTH		: integer := integer(round(real(OVERSAMPLE) * STOP_BITS));	-- Length of Stopbits in Oversampling Cycles
constant STOPSAMPLE_1	: integer := integer(real(STOPLENGTH) / (STOP_BITS * 2.0));	-- First Sampling Point for Stop Bits
constant STOPSAMPLE_2	: integer := STOPSAMPLE_1 * 2;

type state_t is (
	RESET,		-- 0	000
	IDLE,		-- 1	001
	START,		-- 2	010
	DATA,		-- 3	011
	PARITY,		-- 4	100
	STOP,		-- 5	101
	OUTPUT		-- 6	110
);
signal state : state_t := RESET;

signal tick	: integer range 0 to STOPLENGTH-1 := 0;
signal dbit	: integer range 0 to DATA_BITS-1  := 0;
signal char : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
signal prty : std_logic := '0';

signal p	: std_logic := '0';

-- synchronizer: RX_I
signal rx_sr    : std_logic_vector(1 downto 0) := (others => '1');
alias rx		: std_logic is rx_sr(rx_sr'high);


begin

-- synchronizer for external signals
sync: process(CLK_I)
begin
    if rising_edge(CLK_I) then
        if (RST_I = '1') then
            rx_sr <= (others => '1');	-- IDLE high
        else
            rx_sr <= rx_sr(0) & RX_I;            
        end if;
    end if;
end process;

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			tick	<= 0;
			RECV_O	<= '0';
			RX_CHAR_O	<= (others => '0');
			state	<= RESET;
		elsif (OS_CLK_I = '1') then			-- Use Oversampling Clock als Clock-Enable for normal Clock
			
			case (state) is
			when RESET =>
				if (rx = '1') then
					state <= IDLE;
				end if;
			
			when IDLE =>
				RECV_O <= '0';
			
				if (rx = '0') then
					tick <= 0;
					char <= (others => '0');
					prty <= '0';
					
					if (PARITY_BIT = 'E') then
						p <= '0';
					elsif (PARITY_BIT = 'O') then
						p <= '1';
					end if;
					
					state  <= START;
				end if;
				
			when START =>
				if (rx = '1') then 
				    state <= IDLE;
				end if;
			
				if (tick = BITCENTER-1) then
					tick	<= 0;
					dbit	<= 0;
					state 	<= DATA;
				else
					tick <= tick + 1;
				end if;
			
			when DATA =>
				if (tick = OVERSAMPLE-1) then
					tick <= 0;
			
					char <= rx & char(DATA_BITS-1 downto 1);
					p <= p XOR rx;
					
					if (dbit = DATA_BITS-1) then
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
				if (tick = OVERSAMPLE-1) then
					tick	<= 0;
					prty	<= rx;
					state	<= STOP;
				else
					tick <= tick + 1;
				end if;
				
			when STOP =>
				if (tick = STOPLENGTH-1) then
					tick <= 0;
					RX_CHAR_O <= char;
					state <= OUTPUT;
				else
					tick <= tick + 1;
				end if;	
			
			when OUTPUT =>
				RECV_O <= '1';
				state <= IDLE;
			
			end case;
		end if;
	end if;
end process;

end RTL;
