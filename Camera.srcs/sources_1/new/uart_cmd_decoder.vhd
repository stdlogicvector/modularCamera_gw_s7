library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.util.all;

entity uart_cmd_decoder is
	generic (
		DATA_BITS		: integer	:= 8;
		MAX_ARGS		: integer	:= 10;
		USE_SENSOR		: boolean	:= false;
		USE_ETH			: boolean	:= false;
		SENS_ADDR_BYTES	: integer	:= 2;
		SENS_DATA_BYTES	: integer	:= 2;
		LUTS			: integer	:= 1
	);
	port (
		CLK_I			: in	std_logic;
		RESET_I			: in	std_logic;
	
		-- Control Connections
		BUSY_O			: out	std_logic := '0';
		UART_BUSY_I		: in	std_logic := '0';
		
		NEW_CMD_I		: in	std_logic := '0';
		CMD_ACK_O 		: out	std_logic := '0';
		CMD_NACK_O		: out	std_logic := '0';
		CMD_ID_I		: in	std_logic_vector(DATA_BITS-1 downto 0);
		CMD_ARGS_I		: in	std_logic_vector((MAX_ARGS*DATA_BITS)-1 downto 0);
		
		NEW_ACK_O		: out	std_logic := '0';
		NEW_NACK_O		: out	std_logic := '0';
		NEW_DONE_O		: out	std_logic := '0';
		
		NEW_REPLY_O		: out	std_logic := '0';
		LONG_REPLY_O	: out	std_logic := '0';
		REPLY_ACK_I		: in	std_logic := '0';
		REPLY_ID_O		: out	std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
		REPLY_ARGS_O	: out	std_logic_vector((MAX_ARGS*DATA_BITS)-1 downto 0) := (others => '0');
		REPLY_ARGN_O	: out	std_logic_vector(clogb2(MAX_ARGS+1) - 1 downto 0) := (others => '0');
	
		-- Internal Registers
		REG_WRITE_O		: out	std_logic := '0';
		REG_ADDR_O		: out	std_logic_vector( 7 downto 0) := (others => '0');
		REG_DATA_O		: out	std_logic_vector(15 downto 0) := (others => '0');
		REG_DATA_I		: in	std_logic_vector(15 downto 0) := (others => '0');
		
		-- Sensor Registers
		SENS_INIT_O		: out	std_logic := '0';
		SENS_BUSY_I		: in	std_logic := '0';
		SENS_DONE_I		: in	std_logic := '0';
		SENS_WRITE_O	: out	std_logic := '0';
		SENS_READ_O		: out	std_logic := '0';
		SENS_ADDR_O		: out	std_logic_vector(SENS_ADDR_BYTES*8-1 downto 0) := (others => '0');
		SENS_DATA_O		: out	std_logic_vector(SENS_DATA_BYTES*8-1 downto 0) := (others => '0');
		SENS_DATA_I		: in	std_logic_vector(SENS_DATA_BYTES*8-1 downto 0) := (others => '0');
		
		-- LUT
		LUT_WRITE_O		: out	std_logic_vector(max(LUTS, 1)-1 downto 0) := (others => '0');
		LUT_ACK_I		: in	std_logic_vector(max(LUTS, 1)-1 downto 0) := (others => '0');
		LUT_ADDR_O		: out	std_logic_vector(15 downto 0) := (others => '0');
		LUT_DATA_O		: out	std_logic_vector(31 downto 0) := (others => '0');
		
		MACIP_SET_O		: out	std_logic := '0'
	);
end uart_cmd_decoder;

architecture RTL of uart_cmd_decoder is

constant ARG_NR_WIDTH	: integer := clogb2(MAX_ARGS+1);

-- Command IDs

constant REG_READ		: character := 'R';
constant REG_WRITE		: character := 'W';

constant SENS_INIT		: character := 'i';
constant SENS_READ		: character := 'r';
constant SENS_WRITE		: character := 'w';

constant LUT_WRITE		: character := 'L';
constant LUT_ADDRESS	: character := 'P';

constant MAC_IP_SET		: character := 'D';

--------------------------------------------------------------------------------

constant id_reg_read	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(REG_READ);
constant id_reg_write	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(REG_WRITE);

constant id_sens_init	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(SENS_INIT);
constant id_sens_read	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(SENS_READ);
constant id_sens_write	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(SENS_WRITE);

constant id_lut_addr	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(LUT_ADDRESS);
constant id_lut_write	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(LUT_WRITE);

constant id_mac_ip_set	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(MAC_IP_SET);

-- Control Signals

type std_logic_bus is array(natural range <>) of std_logic_vector(DATA_BITS-1 downto 0);

type state_t is (
S_IDLE,
S_CMD,
S_WAIT_FOR_START,
S_WAIT_FOR_END,
S_REPLY,
S_WAIT_FOR_REPLY
);

signal state : state_t := S_IDLE;

signal cmd_id		: std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
signal cmd_args		: std_logic_bus(MAX_ARGS-1 downto 0) := (others => (others => '0'));
signal rpl_args		: std_logic_bus(MAX_ARGS-1 downto 0) := (others => (others => '0'));

signal ack			: std_logic := '0';
signal nack			: std_logic := '0';

signal lut_select	: std_logic_vector(LUTS-1 downto 0) := (others => '0');
signal lut_addr		: std_logic_vector(15 downto 0) := (others => '0');

begin

args : for i in 0 to MAX_ARGS-1 generate
	REPLY_ARGS_O((8*(i+1)-1) downto (8*i)) <= rpl_args(i);
end generate;

control : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			state 		 <= S_IDLE;
			cmd_id		 <= (others => '0');
			
			rpl_args	 <= (others => (others => '0'));
			REPLY_ID_O	 <= (others => '0');
		else
			CMD_ACK_O	 	<= '0';
			CMD_NACK_O		<= '0';
			
			NEW_ACK_O	 	<= '0';
			NEW_NACK_O	 	<= '0';
			NEW_DONE_O		<= '0';
			NEW_REPLY_O	 	<= '0';
			LONG_REPLY_O	<= '0';
			
			REG_WRITE_O		<= '0';
			SENS_INIT_O		<= '0';
			MACIP_SET_O		<= '0';
			LUT_WRITE_O		<= (others => '0');
			
			if USE_SENSOR = true then
				SENS_WRITE_O	<= '0';
				SENS_READ_O		<= '0';
			end if;
						
			case (state) is
			when S_IDLE =>
				BUSY_O 		<= '0';
				ack 		<= '0';
				nack 		<= '0';
			
				if (NEW_CMD_I = '1') then
					BUSY_O 		<= '1';
					CMD_ACK_O	<= '1';
					cmd_id		<= CMD_ID_I;
					
					args : for i in 0 to MAX_ARGS-1 loop
						cmd_args(i) <= 	CMD_ARGS_I((8*(i+1)-1) downto (8*i));
					end loop;

					state <= S_CMD;
				end if;
				
			when S_CMD =>
				REPLY_ID_O <= cmd_id;
				
				state <= S_WAIT_FOR_START;
				
				case cmd_id is
				when id_reg_read =>
					REG_ADDR_O <= cmd_args(0);
					REG_WRITE_O <= '0';
				
				when id_reg_write =>
					REG_ADDR_O  <= cmd_args(0);
					REG_DATA_O  <= cmd_args(1) & cmd_args(2);
					REG_WRITE_O <= '1';
					
				when id_sens_read =>
					if USE_SENSOR = true then
						if SENS_ADDR_BYTES = 1 then
							SENS_ADDR_O <= cmd_args(0);
						elsif SENS_ADDR_BYTES = 2 then
							SENS_ADDR_O <= cmd_args(0) & cmd_args(1);
						end if;
						SENS_READ_O <= '1';
					end if;
				
				when id_sens_write =>
					if USE_SENSOR = true then
						if SENS_ADDR_BYTES = 1 then
							SENS_ADDR_O <= cmd_args(0);
							
							if SENS_DATA_BYTES = 1 then
								SENS_DATA_O <= cmd_args(1);
							elsif SENS_DATA_BYTES = 2 then
								SENS_DATA_O  <= cmd_args(1) & cmd_args(2);
							end if;
							
						elsif SENS_ADDR_BYTES = 2 then
							SENS_ADDR_O <= cmd_args(0) & cmd_args(1);
							
							if SENS_DATA_BYTES = 1 then
								SENS_DATA_O <= cmd_args(2);
							elsif SENS_DATA_BYTES = 2 then
								SENS_DATA_O  <= cmd_args(2) & cmd_args(3);
							end if;
						end if;
						
						SENS_WRITE_O <= '1';
					end if;
				
				when id_sens_init =>
					if USE_SENSOR = true then
						SENS_INIT_O <= '1';
					end if;
					
				when id_lut_addr =>
					if (LUTS > 0) then
						lut_select	<= cmd_args(0)(LUTS-1 downto 0);
						lut_addr	<= cmd_args(1) & cmd_args(2);
					end if;
					
				when id_lut_write =>
					if (LUTS > 0) then
						lut_addr	<= inc(lut_addr);
						
						LUT_ADDR_O	<= lut_addr;
						LUT_DATA_O	<= cmd_args(0) & cmd_args(1) & cmd_args(2) & cmd_args(3);
					end if;
					
				when id_mac_ip_set =>
					MACIP_SET_O		<= '1';
					
				when others =>
					NULL;
				end case;
-------------------------------------------------------------------------------							
			when S_WAIT_FOR_START =>
				case cmd_id is
				
				when id_sens_read |
					 id_sens_write =>
					 if USE_SENSOR = true then
					 	if SENS_BUSY_I = '1' then
						 	state <= S_WAIT_FOR_END;
						 end if;
					else
						state <= S_WAIT_FOR_END;
					end if;
				
				when id_lut_write =>
					if (LUTS > 0) then
						LUT_WRITE_O <= lut_select;
					end if;
					state <= S_WAIT_FOR_END;
				
				when others =>
					state <= S_WAIT_FOR_END;
				end case;
-------------------------------------------------------------------------------							
			when S_WAIT_FOR_END =>
				case cmd_id is
				
				when id_sens_read |
					 id_sens_write =>
					 if USE_SENSOR = true then
						 if SENS_DONE_I = '1' then
						 	state <= S_REPLY;
						 end if;
					else
						state <= S_REPLY;
					end if;
					
				when id_lut_write =>
					if (LUTS > 0) then
						if ((LUT_ACK_I AND lut_select) = lut_select) then
							state <= S_REPLY;
						end if;
					else
						state <= S_REPLY;
					end if;
								
				when others =>
					state <= S_REPLY;
				end case;
-------------------------------------------------------------------------------			
			when S_REPLY =>
				case cmd_id is

				when id_reg_read =>
					NEW_REPLY_O		<= '1';
					rpl_args(0) 	<= REG_DATA_I(15 downto 8);
					rpl_args(1) 	<= REG_DATA_I( 7 downto 0);
					REPLY_ARGN_O	<= int2vec(2, ARG_NR_WIDTH);
					
				when id_sens_read =>
					if USE_SENSOR = true then
						NEW_REPLY_O		<= '1';
						if SENS_DATA_BYTES = 1 then
							rpl_args(0) 	<= SENS_DATA_I(7 downto 0);
						elsif SENS_DATA_BYTES = 2 then
							rpl_args(0) 	<= SENS_DATA_I(15 downto 8);
							rpl_args(1) 	<= SENS_DATA_I( 7 downto 0);
						end if;
						REPLY_ARGN_O	<= int2vec(SENS_DATA_BYTES, ARG_NR_WIDTH);
					else
						NEW_NACK_O	<= '1';
					end if;
		 
				when id_reg_write	|
					 id_sens_write	|
					 id_lut_write	|
					 id_sens_init	|
					 id_mac_ip_set	=>
					NEW_ACK_O	<= '1';				
									
				when others =>
					NEW_NACK_O	<= '1';
				end case;
				
				if (UART_BUSY_I = '0') then		-- Wait until UART is done putting reply into FIFO before trying to transmit ACK/NACK
					state <= S_WAIT_FOR_REPLY;
				else
					state <= S_REPLY;
				end if;
				
			when S_WAIT_FOR_REPLY =>
				if (REPLY_ACK_I = '1') then
					state <= S_IDLE;
				end if;
		
			end case;
		end if;
	end if;
end process;

end architecture;