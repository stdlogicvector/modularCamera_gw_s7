library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use work.util.all;

entity python_ctrl is
Generic (
	CLK_MHZ		: real := 100.0;
	SPI_MHZ		: real := 10.0;
	PAUSE_US	: real := 10.0;
	SIMULATION	: boolean := false
);
Port (
	CLK_I		: in	STD_LOGIC;
	RST_I		: in	STD_LOGIC;
	
	EN_1V8_O	: out	STD_LOGIC;
	EN_3V3_O	: out	STD_LOGIC;
	EN_PIX_O	: out	STD_LOGIC;
	EN_CLK_O	: out	STD_LOGIC;
	RST_O		: out	STD_LOGIC;
	
	ENABLE_I	: in	STD_LOGIC;
	
	BUSY_O		: out	STD_LOGIC;
	DONE_O		: out	STD_LOGIC;
	
	READ_I		: in	STD_LOGIC;
	WRITE_I		: in	STD_LOGIC;
	
	ADDR_I		: in	STD_LOGIC_VECTOR(15 downto 0);
	DATA_I		: in	STD_LOGIC_VECTOR(15 downto 0);
	DATA_O		: out	STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

	nCS_O		: out	STD_LOGIC := '1';
	SCK_O		: out	STD_LOGIC := '0';
	MISO_I		: in	STD_LOGIC;
	MOSI_O		: out	STD_LOGIC
);
end python_ctrl;

architecture Behavioral of python_ctrl is

-- Power Sequencing

constant CLK_PERIOD	: real := 1000.0 / CLK_MHZ;
constant PAUSE_CNT	: integer := integer(PAUSE_US * 1000.0 / CLK_PERIOD); 

signal counter		: integer range 0 to PAUSE_CNT := 0;
signal power		: std_logic_vector(5 downto 0) := (others => '0');

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

constant PRESCALER	: integer := integer(CLK_MHZ / SPI_MHZ);
signal prescale		: integer range 0 to PRESCALER-1 := 0;
signal bit_clock	: std_logic := '0';

constant ADDR_WIDTH	: integer := 9;
constant DATA_WIDTH	: integer := 16;
constant CMD_WIDTH	: integer := ADDR_WIDTH + 1 + DATA_WIDTH;

signal data_in		: std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
signal cmd_out		: std_logic_vector(CMD_WIDTH-1 downto 0) := (others => '0');

type sync_state_t is (S_IDLE, S_WAIT_FOR_START, S_WAIT_FOR_END);
signal sync_state : sync_state_t := S_IDLE;

type state_t is (S_IDLE, S_SEND);
signal state : state_t := S_IDLE;

signal transmit		: std_logic := '0';
signal busy			: std_logic := '0';
signal sck_en		: std_logic := '0';

signal bits 		: integer range 0 to CMD_WIDTH-1 := 0;

signal clk_edge 	: std_logic_vector(1 downto 0) := "00";

begin

-- Power Sequencing

EN_1V8_O <= power(0);
EN_3V3_O <= power(1);
EN_PIX_O <= power(2);
EN_CLK_O <= power(3);
RST_O	 <= power(4);

pwr_seq : process(CLK_I)
begin
	if rising_edge(CLK_I) then
	
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
				power	<= power(4 downto 0) & '1';
				counter <= 0;
				p_state <= S_NEXT_UP;
			end if;
			
		when S_NEXT_UP =>
			if power(5) = '1' then
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
				power	<= "0" & power(5 downto 1);
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

bitclkgen : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if prescale = PRESCALER-1 then
			prescale  <= 0;
			bit_clock <= not bit_clock;
		else
			prescale  <= prescale + 1;
		end if;
	end if;
end process; 

SCK_O <= bit_clock and sck_en;

sync : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			clk_edge	<= "00";
			sync_state	<= S_IDLE;
		else
			clk_edge <= clk_edge(0) & bit_clock;
			
			DONE_O <= '0';
			
			case (sync_state) is
				when S_IDLE =>
					BUSY_O		<= '0';
					
					if (READ_I = '1' AND WRITE_I = '0') then
						cmd_out <= ADDR_I(ADDR_WIDTH-1 downto 0) & "0" & x"0000";
											
						transmit	<= '1';
						BUSY_O		<= '1';
						
						sync_state	<= S_WAIT_FOR_START;
					elsif (WRITE_I = '1' AND READ_I = '0') then
						cmd_out <= ADDR_I(ADDR_WIDTH-1  downto 0) & "1" & DATA_I;
						
						transmit	<= '1';
						BUSY_O		<= '1';
						
						sync_state	<= S_WAIT_FOR_START;
					end if;	
					
				when S_WAIT_FOR_START =>					-- Wait for SPI statemachine to start busy
					if (busy = '1') then
						transmit   <= '0';
						sync_state <= S_WAIT_FOR_END;
					end if;
					
				when S_WAIT_FOR_END =>						-- Wait for SPI statemachine to finish busy
					if (busy = '0') then
						DONE_O		<= '1';
						DATA_O		<= data_in;
						sync_state	<= S_IDLE;
					end if;
			end case;
		end if;
	end if;
end process;

mosi : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			state <= S_IDLE;
		elsif (clk_edge = "10") then 	--Rising Edge
		
			case (state) is
				when S_IDLE =>
					-- Defaults 
					MOSI_O	<= 'Z';
					nCS_O	<= '1';
					busy	<= '0';
					sck_en	<= '0';
				
					if (transmit = '1') then
						nCS_O	<= '0';
						bits  	<= 0;
						state	<= S_SEND;
					end if;
					
				when S_SEND =>
					nCS_O	<= '0';
					busy	<= '1';
					
					if (bits = CMD_WIDTH) then
						bits	<= 0;
						sck_en	<= '0';
						MOSI_O	<= '0';
						state	<= S_IDLE;
					else
						sck_en	<= '1';
						bits	<= bits + 1;
						MOSI_O	<= cmd_out((CMD_WIDTH - 1) - bits);
					end if;
				
			end case;
		end if;
	end if;
end process;

miso : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			data_in <= (others => '0');
		elsif (clk_edge = "10") then 	--Falling Edge
			if (bits > ADDR_WIDTH+1) then
				data_in <= data_in((DATA_WIDTH - 2) downto 0) & MISO_I;
			end if;
		end if;
	end if;
end process;

end Behavioral;
