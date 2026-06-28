library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use work.util.all;

entity ev76c560_ctrl is
Generic (
	CLK_MHZ		: real := 100.0;
	PAUSE_US	: real := 1.0;
	SIMULATION	: boolean := false
);
Port (
	CLK_I		: in	STD_LOGIC;
	RST_I		: in	STD_LOGIC;
	
	EN_1V8_O	: out	STD_LOGIC;
	EN_3V3_O	: out	STD_LOGIC;
	EN_CLK_O	: out	STD_LOGIC;
	RST_O		: out	STD_LOGIC;
	
	ENABLE_I	: in	STD_LOGIC;
	INIT_O		: out	STD_LOGIC := '0';
	
	BUSY_O		: out	STD_LOGIC;
	DONE_O		: out	STD_LOGIC;
	
	READ_I		: in	STD_LOGIC;
	WRITE_I		: in	STD_LOGIC;
	
	ADDR_I		: in	STD_LOGIC_VECTOR( 7 downto 0);
	DATA_I		: in	STD_LOGIC_VECTOR(15 downto 0);
	DATA_O		: out	STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

	SPI_BUSY_I	: in	STD_LOGIC;
	SPI_SEND_O	: out	STD_LOGIC := 'Z';
	SPI_CONT_O	: out	STD_LOGIC := 'Z';
	SPI_KEEP_O	: out	STD_LOGIC := 'Z';
	SPI_SLAVE_O	: out	STD_LOGIC_VECTOR(0 downto 0) := "Z";
	
	SPI_TX_O	: out	STD_LOGIC_VECTOR(7 downto 0) := (others => 'Z');
	SPI_RX_I	: in	STD_LOGIC_VECTOR(7 downto 0)	
);
end ev76c560_ctrl;

architecture Behavioral of ev76c560_ctrl is

-- Power Sequencing

constant CLK_PERIOD	: real := 1000.0 / CLK_MHZ;
constant PAUSE_CNT	: integer := integer(PAUSE_US * 1000.0 / CLK_PERIOD); 

signal counter		: integer range 0 to PAUSE_CNT := 0;
signal power		: std_logic_vector(4 downto 0) := (others => '0');

type p_state_t is (
	S_DOWN,
	S_POWER_UP,
	S_NEXT_UP,
	S_UP,
	S_POWER_DOWN,
	S_NEXT_DOWN
);

signal p_state 		: p_state_t := S_DOWN;

-- Control
type state_t is (
	S_IDLE,
	S_WAIT,
	S_SEND_ADDR,
	S_SENDING_ADDR,
	S_SEND_MSB,
	S_SENDING_MSB,
	S_SEND_LSB,
	S_SENDING_LSB,
	S_END
);

signal state		: state_t := S_IDLE;

signal write		: std_logic := '0';
signal receiving	: std_logic := '0';
signal active		: std_logic := '0';
signal send			: std_logic := '0';
signal cont			: std_logic := '0';
signal keep			: std_logic := '0';
signal tx			: std_logic_vector( 7 downto 0) := (others => '0');

signal addr			: std_logic_vector( 7 downto 0) := (others => '0');
signal data_tx		: std_logic_vector(15 downto 0) := (others => '0');
signal data_rx		: std_logic_vector(15 downto 0) := (others => '0');

begin

BUSY_O 		<= active OR receiving OR SPI_BUSY_I;

SPI_SEND_O	<= send	when active = '1' else 'Z';
SPI_CONT_O	<= cont	when active = '1' else 'Z';
SPI_KEEP_O	<= cont	when active = '1' else 'Z';
SPI_SLAVE_O	<= "0"  when active = '1' else (others => 'Z');
SPI_TX_O	<= tx	when active = '1' else (others => 'Z');

-- Power Sequencing

EN_1V8_O <= power(0);
EN_CLK_O <= power(1);
RST_O	 <= power(2);
EN_3V3_O <= power(3);

pwr_seq : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		INIT_O <= '0';
		
		case (p_state) is
		when S_DOWN =>
			power	<= (others => '0');
			counter <= 0;
			
			if (ENABLE_I = '1') then
				p_state <= S_POWER_UP;
			end if;
			
		when S_POWER_UP =>
			if counter < PAUSE_CNT then
				counter <= counter + 1;
			else
				power	<= power(power'high-1 downto 0) & '1';
				counter <= 0;
				p_state <= S_NEXT_UP;
			end if;
			
		when S_NEXT_UP =>
			if power(power'high) = '1' then
				INIT_O <= '1';
				p_state <= S_UP;
			else
				p_state <= S_POWER_UP;
			end if;
			
		when S_UP =>
			if (ENABLE_I = '0') then
				p_state <= S_POWER_DOWN;
			end if;
			
		when S_POWER_DOWN =>
			if counter < PAUSE_CNT then
				counter <= counter + 1;
			else
				power	<= "0" & power(power'high downto 1);
				counter <= 0;
				p_state <= S_NEXT_DOWN;
			end if;
			
		when S_NEXT_DOWN =>
			if power(0) = '0' then
				p_state <= S_DOWN;
			else
				p_state <= S_POWER_DOWN;
			end if;
		end case;
	end if;
end process;

-- Control

writing : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			state 			<= S_IDLE;
			active 			<= '0';
		else
			keep <= '0';
			send <= '0';
			DONE_O <= '0';
			
			case (state) is
			when S_IDLE =>
				active <= '0';

				if (WRITE_I = '1') then
					addr		<= '1' & ADDR_I(6 downto 0);
					data_tx 	<= DATA_I;
					state		<= S_WAIT;
					active 		<= '1';
					write		<= '1';
				elsif (READ_I = '1') then
					addr		<= '0' & ADDR_I(6 downto 0);
					data_tx 	<= (others => '0');
					state		<= S_WAIT;
					active 		<= '1';
					write		<= '0';
				end if;
			
			when S_WAIT =>
				tx		<= addr;
				if (SPI_BUSY_I = '0') then
					state		<= S_SEND_ADDR;
				end if;
			
			when S_SEND_ADDR =>
				cont	<= '1';
				send	<= '1';
				if (SPI_BUSY_I = '1') then
					state <= S_SENDING_ADDR;
				end if;
				
			when S_SENDING_ADDR =>
				tx	<= data_tx(15 downto 8);			
				if (SPI_BUSY_I = '0') then
					state <= S_SEND_MSB;
				end if;
			
			when S_SEND_MSB =>
				cont	<= '1';
				send	<= '1';
				if (SPI_BUSY_I = '1') then
					state <= S_SENDING_MSB;
				end if;
				
			when S_SENDING_MSB =>
				tx	<= data_tx(7 downto 0);
				data_rx(15 downto 8) <= SPI_RX_I;

				if (SPI_BUSY_I = '0') then
					state <= S_SEND_LSB;
				end if;
				
			when S_SEND_LSB =>
				cont	<= '1';
				send	<= '1';
				if (SPI_BUSY_I = '1') then
					state <= S_SENDING_LSB;
				end if;
				
			when S_SENDING_LSB =>
				data_rx(7 downto 0) <= SPI_RX_I;

				if (SPI_BUSY_I = '0') then
					state <= S_END;
				end if;
				
			when S_END =>
				DATA_O <= data_rx;
				DONE_O <= '1';
				state <= S_IDLE;
				
			end case;
		end if;
	end if;
end process;

end Behavioral;
