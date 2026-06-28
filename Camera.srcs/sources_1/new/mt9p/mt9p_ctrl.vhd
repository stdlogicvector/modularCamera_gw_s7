library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.ALL;
use work.types.all;
use work.util.all;

entity mt9p_ctrl is
Generic (
	ADDRESS		: std_logic_vector(7 downto 0) := x"90"; -- Saddr = low -> 0x90; Saddr = high -> 0xBA
	SIMULATION	: boolean := FALSE
);
Port (
	CLK_I		: in	STD_LOGIC;
	RST_I		: in	STD_LOGIC;
	
	nRST_O		: out	STD_LOGIC := '0';
	nSTANDBY_O	: out	STD_LOGIC := '0';
	
	BUSY_O		: out	STD_LOGIC;
	DONE_O		: out	STD_LOGIC;
	
	READ_I		: in	STD_LOGIC;
	WRITE_I		: in	STD_LOGIC;
	
	ADDR_I		: in	STD_LOGIC_VECTOR(7 downto 0);
	DATA_I		: in	STD_LOGIC_VECTOR(15 downto 0);
	DATA_O		: out	STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

	I2C_REQ_O	: out	STD_LOGIC := '0';
	I2C_DV_O	: out	STD_LOGIC := '0';
	I2C_ADDR_O	: out 	STD_LOGIC_VECTOR(6 downto 0);
	I2C_RW_O	: out	STD_LOGIC := '0';
	I2C_DATA_I	: in	STD_LOGIC_VECTOR(7 downto 0);
	I2C_DATA_O	: out	STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	I2C_BUSY_I	: in	STD_LOGIC
);
end mt9p_ctrl;

architecture Behavioral of mt9p_ctrl is

type state_t is
(
	S_IDLE,
	S_WAIT_FOR_ARB,
	S_SEND_ADDR,
	S_SEND_VALUE_HI,
	S_SEND_VALUE_LO,
	S_READ_VALUE_HI,
	S_READ_VALUE_LO,
	S_END
);

signal state	: state_t := S_IDLE;
signal nextstate: state_t := S_IDLE;

signal reg_addr	: std_logic_vector(7 downto 0);
signal reg_val	: std_logic_vector(15 downto 0);

signal rw		: std_logic := '0';

constant RST_TIME	: integer := switch(SIMULATION, 5000, 500000);
signal counter		: integer range 0 to RST_TIME := 0;

type init_state_t is
(
	S_PWRDWN,
	S_RESET,
	S_IDLE
);

signal init_state	: init_state_t := S_PWRDWN;

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then

		case init_state is
		when S_PWRDWN =>
			nRST_O	 	<= '0';
			
			if counter = RST_TIME then
				nSTANDBY_O	<= '1';
				init_state	<= S_RESET;
				counter		<= 0;
			else
				nSTANDBY_O	<= '0';
				counter 	<= counter + 1;
			end if;
		
		when S_RESET =>
			if counter = RST_TIME then
				nRST_O		<= '1';
				init_state	<= S_IDLE;
				counter		<= 0;
			else
				nRST_O	 	<= '0';
				counter 	<= counter + 1;
			end if;
		
		when S_IDLE =>
			nSTANDBY_O	<= '1';
			nRST_O	 	<= '1';
			init_state	<= S_IDLE;
		end case;

		case state is
		when S_IDLE =>
			I2C_REQ_O <= '0';
			I2C_DV_O <= '0';
			DONE_O <= '0';
			BUSY_O <= '0';
			
			reg_addr <= ADDR_I;
			reg_val	 <= DATA_I;
			
			I2C_RW_O <= '0';
			I2C_ADDR_O <= ADDRESS(7 downto 1);
			
			if WRITE_I = '1' then
				I2C_REQ_O <= '1';
				BUSY_O <= '1';
				rw <= '1';
				
				state <= S_WAIT_FOR_ARB;
				nextstate <= S_SEND_ADDR;
			elsif READ_I = '1' then
				I2C_REQ_O <= '1';
				BUSY_O <= '1';
				rw <= '0';
				
				state <= S_WAIT_FOR_ARB;
				nextstate <= S_SEND_ADDR;
			end if;
			
		when S_WAIT_FOR_ARB =>
			if I2C_BUSY_I = '0' then
				state <= nextstate;
			end if;
		
		when S_SEND_ADDR =>
			I2C_DV_O <= '1';
			I2C_DATA_O <= reg_addr;
			
			if I2C_BUSY_I = '1' then
				state <= S_WAIT_FOR_ARB;
				
				if rw = '1' then
					I2C_DATA_O <= reg_val(15 downto 8);
					nextstate <= S_SEND_VALUE_HI;
				else
					I2C_RW_O <= '1';
					nextstate <= S_READ_VALUE_HI;
				end if;
			end if;
			
		when S_READ_VALUE_HI =>
			I2C_DV_O <= '1';
			
			if I2C_BUSY_I = '1' then
				state <= S_WAIT_FOR_ARB;
				nextstate <= S_READ_VALUE_LO;
			end if;
			
		when S_READ_VALUE_LO =>
			I2C_DV_O <= '1';
			
			if I2C_BUSY_I = '1' then
				I2C_DV_O <= '0';
				DATA_O(15 downto 8) <= I2C_DATA_I;
				state <= S_WAIT_FOR_ARB;
				nextstate <= S_END;
			end if;
			
		when S_SEND_VALUE_HI =>
			I2C_DV_O <= '1';

			if I2C_BUSY_I = '1' then
				I2C_DATA_O <= reg_val(7 downto 0);
				state <= S_WAIT_FOR_ARB;
				nextstate <= S_SEND_VALUE_LO;
			end if;
		
		when S_SEND_VALUE_LO =>
			I2C_DV_O <= '1';

			if I2C_BUSY_I = '1' then
				I2C_DV_O <= '0';
				state <= S_WAIT_FOR_ARB;
				nextstate <= S_END;
			end if;
			
		when S_END =>
			DONE_O <= '1';
			DATA_O(7 downto 0) <= I2C_DATA_I;
			state <= S_IDLE;
			
		end case;
	end if;
end process;

end Behavioral;
