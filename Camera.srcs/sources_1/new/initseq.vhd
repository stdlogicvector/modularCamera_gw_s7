library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use work.util.all;

entity initseq is
Generic (
	AUTO_INIT	: boolean := false;
	ADDR_WIDTH	: integer := 8;
	DATA_WIDTH	: integer := 16;
		
	INIT_VALUES	: integer_vector := (0 ,0)
);
Port (
	CLK_I		: in	STD_LOGIC;
	RST_I		: in	STD_LOGIC;

	INIT_I		: in	STD_LOGIC := '0';
	DONE_O		: out	STD_LOGIC := '0';
	
	REQ_O		: out	STD_LOGIC := '0';
	
	BUSY_I		: in	STD_LOGIC;
	DONE_I		: in	STD_LOGIC;
	
	READ_O		: out	STD_LOGIC := '0';
	WRITE_O		: out	STD_LOGIC := '0';
	
	ADDR_O		: out	STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0) := (others => '0');
	DATA_O		: out	STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
	DATA_I		: in	STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
);
end initseq;

architecture Behavioral of initseq is

constant RAM_WIDTH	: integer := max(ADDR_WIDTH, DATA_WIDTH);
constant RAM_DEPTH	: integer := clogb2(INIT_VALUES'length);
constant RAM_SIZE	: integer := 2**RAM_DEPTH;

signal counter		: std_logic_vector(RAM_DEPTH-1 downto 0) := (others => '0');
signal ram_length	: std_logic_vector(RAM_DEPTH-1 downto 0) := (others => '0');
signal ram_addr		: std_logic_vector(RAM_DEPTH-1 downto 0) := (others => '0');
signal ram_data		: std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');

type state_t is (
	S_IDLE,
	S_WAIT_FOR_FREE,
	S_LOAD_LEN,
	S_LOAD_ADDR,
	S_LOAD_DATA,
	S_WRITE,
	S_WAIT_FOR_TX,
	S_END
);

signal state		: state_t := S_IDLE;

signal autoinit		: std_logic := '0';

begin

init : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		DONE_O 		<= '0';
		WRITE_O		<= '0';
		READ_O		<= '0';
	
		case state is
		when S_IDLE =>
			REQ_O <= '0';
			
			if INIT_I = '1' 
			or (AUTO_INIT = true AND autoinit = '0') then
				REQ_O	 <= '1';
				autoinit <= '1';
				state 	 <= S_WAIT_FOR_FREE;
			end if;
			
		when S_WAIT_FOR_FREE =>
			ram_addr <= (others => '0');
			
			if BUSY_I = '0' then
				state <= S_LOAD_LEN;
			end if;
			
		when S_LOAD_LEN =>
			ram_length	<= zero_resize(ram_data, ram_length'length);
			ram_addr 	<= inc(ram_addr);
			counter		<= (others => '0');
			
			state 		<= S_LOAD_ADDR;
			
		when S_LOAD_ADDR =>
			ram_addr 	<= inc(ram_addr);
		
			if or_reduce(ram_length) = '0' then	-- No Init Sequence
				state <= S_IDLE;
			else	
				state <= S_LOAD_DATA;
			end if;
		
		when S_LOAD_DATA =>
			ADDR_O 		<= ram_data(ADDR_WIDTH-1 downto 0);
			ram_addr 	<= inc(ram_addr);
			
			state <= S_WRITE;		
			
		when S_WRITE =>
			DATA_O 		<= ram_data(DATA_WIDTH-1 downto 0);
			WRITE_O		<= '1';
			
			if BUSY_I = '1' then
				counter	<= inc(counter);
				state	<= S_WAIT_FOR_TX;
			end if;			
			
		when S_WAIT_FOR_TX =>
			if BUSY_I = '0' then
				if counter = ram_length then
					state <= S_END;
				else
					state <= S_LOAD_ADDR;
				end if;
			end if;
			
		when S_END =>
			DONE_O <= '1';
			state <= S_IDLE;
		
			
		end case;
	end if;
end process;

seq : entity work.ram
generic map (
	RAM_WIDTH		=> RAM_WIDTH,
	RAM_DEPTH		=> RAM_SIZE,
	RAM_PERF 		=> "LOW_LATENCY",
	RAM_MODE_A		=> "NO_CHANGE",
	RAM_MODE_B		=> "NO_CHANGE",
	INIT_FILE		=> "",
	INIT_VALUES		=> INIT_VALUES,
	FILE_TYPE		=> "INTARR"
)
port map (
	RESET_I			=> RST_I,
	
	A_CLK_I			=> CLK_I,	
	A_WEN_I			=> '0',				--RAW_WRITE_I,
	A_ADDR_I		=> (others => '0'),	--RAM_ADDR_I,
	A_DATA_I		=> (others => '0'),	--RAM_DATA_I,
	A_DATA_O		=> open,			--RAM_DATA_O,
	
	B_CLK_I			=> CLK_I,
	B_WEN_I			=> '0',
	B_ADDR_I		=> ram_addr,
	B_DATA_O		=> ram_data
);

end Behavioral;