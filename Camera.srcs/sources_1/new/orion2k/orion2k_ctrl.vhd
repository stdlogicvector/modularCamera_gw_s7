library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.ALL;
use work.types.all;
use work.util.all;

entity orion2k_ctrl is
Generic (
	PRESCALER	: integer := 25
);
Port (
	CLK_I		: in	STD_LOGIC;
	RST_I		: in	STD_LOGIC;
	
	BUSY_O		: out	STD_LOGIC;
	DONE_O		: out	STD_LOGIC;
	
	FORCE_I		: in	STD_LOGIC := '0';
	READ_I		: in	STD_LOGIC;
	WRITE_I		: in	STD_LOGIC;
	
	ADDR_I		: in	STD_LOGIC_VECTOR(7 downto 0);
	DATA_I		: in	STD_LOGIC_VECTOR(7 downto 0);
	DATA_O		: out	STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

	UPDATE_O	: out	STD_LOGIC;
	CSN_O		: out	STD_LOGIC;
	SCK_O		: out	STD_LOGIC;
	MISO_I		: in	STD_LOGIC;
	MOSI_O		: out	STD_LOGIC
);
end orion2k_ctrl;

architecture Behavioral of orion2k_ctrl is

signal prescale			: integer range 0 to PRESCALER-1 := 0;
signal bit_clock		: std_logic := '0';

constant READ_REQUEST	: std_logic_vector(4 downto 0) := b"01111";
constant CMD_WIDTH		: integer := 16;
constant DATA_WIDTH		: integer := 8;

constant DELAY_WRITE	: integer := 4-1;	-- Additional Clocks after Writing
constant DELAY_READ		: integer := 5-1;	-- Additional Clocks between writing address and readout

signal data_in			: std_logic_vector((DATA_WIDTH-1) downto 0) := (others => '0');
signal cmd_out			: std_logic_vector((CMD_WIDTH-1)  downto 0) := (others => '0');
signal forced			: std_logic := '0';
signal rw				: std_logic := '0';	-- 1 = Read, 0 = Write

type sync_state_t is (S_IDLE, S_WAIT_FOR_START, S_WAIT_FOR_END);
signal sync_state : sync_state_t := S_IDLE;

type state_t is (S_IDLE, S_SEND, S_WRITE_DELAY, S_READ_DELAY, S_READOUT, S_FORCE_WRITE);
signal state : state_t := S_IDLE;

signal transmit		: std_logic := '0';
signal busy			: std_logic := '0';
signal sck_en		: std_logic := '0';

signal bits 		: integer range 0 to CMD_WIDTH := 0;

signal clk_edge 	: std_logic_vector(1 downto 0) := "00";

begin

bitclkgen : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			prescale  <= 0;
			bit_clock <= '0';
		else
			if prescale = PRESCALER-1 then
				prescale  <= 0;
				bit_clock <= not bit_clock;
			else
				prescale  <= prescale + 1;
			end if;
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
						rw 		<= '1';
						cmd_out <= "000" & ADDR_I(4 downto 0) & "000" & READ_REQUEST;
											
						transmit	<= '1';
						BUSY_O		<= '1';
						
						sync_state	<= S_WAIT_FOR_START;
					elsif (WRITE_I = '1' AND READ_I = '0') then
						rw		<= '0';
						forced	<= FORCE_I;
						cmd_out <= DATA_I & "000" & ADDR_I(4 downto 0);
						
						transmit	<= '1';
						BUSY_O		<= '1';
						
						sync_state	<= S_WAIT_FOR_START;
					end if;	
					
				when S_WAIT_FOR_START =>						-- Wait for SPI statemachine to start busy
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
		elsif (clk_edge = "10") then 	--Falling Edge
		
			case (state) is
				when S_IDLE =>
					-- Defaults 
					UPDATE_O<= '0';
					MOSI_O	<= 'Z';
					CSN_O	<= '1';
					busy	<= '0';
					sck_en	<= '0';
				
					if (transmit = '1') then
						bits  <= 0;
						state <= S_SEND;
					end if;
					
				when S_SEND =>
					CSN_O	<= '0';
					busy	<= '1';
					sck_en	<= '1';
					
					if (bits = CMD_WIDTH) then
						bits	<= 0;
						MOSI_O	<= '0';
						
						if (rw = '1') then
							state <= S_READ_DELAY;
						else
							state <= S_WRITE_DELAY;
						end if;
					else
						bits	<= bits + 1;
						MOSI_O	<= cmd_out((CMD_WIDTH - 1) - bits);
					end if;
				
				when S_WRITE_DELAY =>
					if (bits = DELAY_WRITE - 1) then
						bits <= 0;
						
						if (forced = '1') then
							state		<= S_FORCE_WRITE;
							UPDATE_O	<= '1';
						else
							state <= S_IDLE;
						end if;
					else
						bits <= bits + 1;
					end if;
				
				when S_FORCE_WRITE =>
					UPDATE_O	<= '0';
					state		<= S_IDLE;
				
				when S_READ_DELAY =>
					if (bits = DELAY_READ-1) then
						bits	<= 0;
						state	<= S_READOUT;
					else
						bits	<= bits + 1;
					end if;
				
				when S_READOUT =>
					if (bits = DATA_WIDTH) then
						bits	<= 0;
						state	<= S_IDLE;
					else
						bits	<= bits + 1;
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
		elsif (clk_edge = "01") then 	-- Rising Edge
			if (state = S_READOUT) then
				data_in <= data_in((DATA_WIDTH - 2) downto 0) & MISO_I;
			end if;
		end if;
	end if;
end process;

end Behavioral;
