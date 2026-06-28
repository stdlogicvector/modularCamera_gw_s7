library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.ALL;
use work.types.all;
use work.util.all;

entity adv7182_ctrl is
Generic (
	ADDRESS		: std_logic_vector(7 downto 0) := x"40";
	SIMULATION	: boolean := FALSE
);
Port (
	CLK_I		: in	STD_LOGIC;
	RST_I		: in	STD_LOGIC;
	
	RST_O		: out	STD_LOGIC := '0';
	PWRDWN_O	: out	STD_LOGIC := '0';
	
	BUSY_O		: out	STD_LOGIC;
	DONE_O		: out	STD_LOGIC;
	
	READ_I		: in	STD_LOGIC;
	WRITE_I		: in	STD_LOGIC;
	
	ADDR_I		: in	STD_LOGIC_VECTOR(7 downto 0);
	DATA_I		: in	STD_LOGIC_VECTOR(7 downto 0);
	DATA_O		: out	STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

	I2C_REQ_O	: out	STD_LOGIC := '0';
	I2C_DV_O	: out	STD_LOGIC := '0';
	I2C_ADDR_O	: out 	STD_LOGIC_VECTOR(6 downto 0);
	I2C_RW_O	: out	STD_LOGIC := '0';
	I2C_DATA_I	: in	STD_LOGIC_VECTOR(7 downto 0);
	I2C_DATA_O	: out	STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	I2C_BUSY_I	: in	STD_LOGIC
);
end adv7182_ctrl;

architecture Behavioral of adv7182_ctrl is

type state_t is
(
	S_IDLE,
	S_WAIT_FOR_ARB,
	S_SEND_ADDR,
	S_SEND_VALUE,
	S_READ_VALUE,
	S_END
);

signal state	: state_t := S_IDLE;
signal nextstate: state_t := S_IDLE;

signal reg_addr	: std_logic_vector(7 downto 0);
signal reg_val	: std_logic_vector(7 downto 0);

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
			RST_O	 	<= '0';
			
			if counter = RST_TIME then
				PWRDWN_O	<= '1';
				init_state	<= S_RESET;
				counter		<= 0;
			else
				PWRDWN_O	<= '0';
				counter <= counter + 1;
			end if;
		
		when S_RESET =>
			if counter = RST_TIME then
				RST_O		<= '1';
				init_state	<= S_IDLE;
				counter		<= 0;
			else
				RST_O	 	<= '0';
				counter <= counter + 1;
			end if;
		
		when S_IDLE =>
			PWRDWN_O	<= '1';
			RST_O	 	<= '1';
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
					I2C_DATA_O <= reg_val;
					nextstate <= S_SEND_VALUE;
				else
					I2C_RW_O <= '1';
					nextstate <= S_READ_VALUE;
				end if;
			end if;
			
		when S_READ_VALUE =>
			I2C_DV_O <= '1';
			
			if I2C_BUSY_I = '1' then
				I2C_DV_O <= '0';
				state <= S_WAIT_FOR_ARB;
				nextstate <= S_END;
			end if;
			
		when S_SEND_VALUE =>
			I2C_DV_O <= '1';

			if I2C_BUSY_I = '1' then
				I2C_DV_O <= '0';
				state <= S_WAIT_FOR_ARB;
				nextstate <= S_END;
			end if;
			
		when S_END =>
			DONE_O <= '1';
			DATA_O <= I2C_DATA_I;
			state <= S_IDLE;
			
		end case;
	end if;
end process;

end Behavioral;
