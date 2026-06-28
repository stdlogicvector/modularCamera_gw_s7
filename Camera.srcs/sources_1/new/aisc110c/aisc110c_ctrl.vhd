library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.ALL;
use work.types.all;
use work.util.all;

entity aisc110c_ctrl is
Port (
	CLK_I		: in	STD_LOGIC;
	RST_I		: in	STD_LOGIC;
	
	BUSY_O		: out	STD_LOGIC;
	DONE_O		: out	STD_LOGIC;
	
	READ_I		: in	STD_LOGIC;
	WRITE_I		: in	STD_LOGIC;
	
	ADDR_I		: in	STD_LOGIC_VECTOR(15 downto 0);
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
end aisc110c_ctrl;

architecture Behavioral of aisc110c_ctrl is

constant CMD_READ_LE	: std_logic_vector(7 downto 0) := x"40";
constant CMD_WRITE_LE	: std_logic_vector(7 downto 0) := x"24";
constant CMD_READ_BE	: std_logic_vector(7 downto 0) := x"32";
constant CMD_WRITE_BE	: std_logic_vector(7 downto 0) := x"36";

type r_state_t is (
	S_IDLE,
	S_RX_MSB,
	S_RX_WAIT,
	S_RX_LSB
);

signal r_state		: r_state_t := S_IDLE;

type state_t is (
	S_IDLE,
	S_WAIT,
	S_SEND_CMD,
	S_SENDING_CMD,
	S_SEND_ADDR_MSB,
	S_SENDING_ADDR_MSB,
	S_SEND_ADDR_LSB,
	S_SENDING_ADDR_LSB,
	S_SEND_DUMMY,
	S_SENDING_DUMMY,
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

signal cmd			: std_logic_vector( 7 downto 0) := (others => '0');
signal addr			: std_logic_vector(15 downto 0) := (others => '0');
signal data			: std_logic_vector(15 downto 0) := (others => '0');

begin

BUSY_O 		<= active OR receiving OR SPI_BUSY_I;

SPI_SEND_O	<= send	when active = '1' else 'Z';
SPI_CONT_O	<= cont	when active = '1' else 'Z';
SPI_KEEP_O	<= cont	when active = '1' else 'Z';
SPI_SLAVE_O	<= "0"  when active = '1' else (others => 'Z');
SPI_TX_O	<= tx	when active = '1' else (others => 'Z');

reading : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			r_state <= S_IDLE;
		else
			case (r_state) is
			when S_IDLE =>
				receiving <= '0';
				
				if (state = S_SENDING_MSB) then
					receiving <= '1';
					r_state <= S_RX_MSB;
				end if;
				
			when S_RX_MSB =>
				if (SPI_BUSY_I = '0') then
					DATA_O(15 downto 8) <= SPI_RX_I;
					r_state <= S_RX_WAIT;
				end if;
			
			when S_RX_WAIT =>
				if (state = S_SENDING_LSB) then
					r_state <= S_RX_LSB;
				end if;
			
			when S_RX_LSB =>
				if (SPI_BUSY_I = '0') then
					DATA_O(7 downto 0) <= SPI_RX_I;
					r_state <= S_IDLE;
				end if;	
			end case;
		end if;
	end if;
end process;

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
					cmd			<= CMD_WRITE_LE;
					addr		<= ADDR_I;
					data 		<= DATA_I;
					state		<= S_WAIT;
					active 		<= '1';
					write		<= '1';
				elsif (READ_I = '1') then
					cmd			<= CMD_READ_LE;
					addr		<= ADDR_I;
					data 		<= (others => '0');
					state		<= S_WAIT;
					active 		<= '1';
					write		<= '0';
				end if;
			
			when S_WAIT =>
				tx		<= cmd;
				if (SPI_BUSY_I = '0') then
					state		<= S_SEND_CMD;
				end if;
			
			when S_SEND_CMD =>
				cont	<= '1';
				send	<= '1';
				if (SPI_BUSY_I = '1') then
					state <= S_SENDING_CMD;
				end if;
				
			when S_SENDING_CMD =>
				tx	<= ADDR_I(15 downto 8);			
				if (SPI_BUSY_I = '0') then
					state <= S_SEND_ADDR_MSB;
				end if;
			
			when S_SEND_ADDR_MSB =>
				cont	<= '1';
				send	<= '1';
				if (SPI_BUSY_I = '1') then
					state <= S_SENDING_ADDR_MSB;
				end if;
				
			when S_SENDING_ADDR_MSB =>
				tx	<= ADDR_I(7 downto 0);
				if (SPI_BUSY_I = '0') then
					state <= S_SEND_ADDR_LSB;
				end if;
				
			when S_SEND_ADDR_LSB =>
				cont	<= '1';
				send	<= '1';
				if (SPI_BUSY_I = '1') then
					state <= S_SENDING_ADDR_LSB;
				end if;
				
			when S_SENDING_ADDR_LSB =>
				if write = '1' then
					tx 	<= DATA_I(15 downto 8);
				else
					tx 	<= x"00";
				end if;
				
				if (SPI_BUSY_I = '0') then
					if write = '1' then
						state <= S_SEND_MSB;
					else
						state <= S_SEND_DUMMY;
					end if;
				end if;
				
			when S_SEND_DUMMY =>
				cont	<= '1';
				send	<= '1';
				if (SPI_BUSY_I = '1') then
					state 	<= S_SENDING_DUMMY;
				end if;
				
			when S_SENDING_DUMMY =>
				if (SPI_BUSY_I = '0') then
					state <= S_SEND_MSB;
				end if;
			
			when S_SEND_MSB =>
				cont	<= '1';
				send	<= '1';
				if (SPI_BUSY_I = '1') then
					state 	<= S_SENDING_MSB;
				end if;
				
			when S_SENDING_MSB =>
				if write = '1' then
					tx 	<= DATA_I(7 downto 0);
				else
					tx 	<= x"00";
				end if;
				
				if (SPI_BUSY_I = '0') then
					state <= S_SEND_LSB;
				end if;
			
			when S_SEND_LSB =>
				cont	<= '0';
				send	<= '1';
				if (SPI_BUSY_I = '1') then
					state 	<= S_SENDING_LSB;
				end if;
				
			when S_SENDING_LSB =>
				if (SPI_BUSY_I = '0') then
					state <= S_END;
				end if;
				
			when S_END =>
				DONE_O <= '1';
				state <= S_IDLE;
				
			end case;
		end if;
	end if;
end process;

end Behavioral;
