library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2s is
Generic (
	CLK_MHZ		: real 		:= 100.0;
	SCK_MHZ	 	: real 		:=  3.0;
	WORD_SIZE	: integer	:= 32;
	DATA_WIDTH	: integer	:= 18
);
Port (
	RST_I		: in  STD_LOGIC;
	CLK_I		: in  STD_LOGIC;
	
	SCK_O		: out STD_LOGIC := '0';
	WS_O		: out STD_LOGIC := '0';
	SD_I		: in  STD_LOGIC;
	
	DV_O		: out STD_LOGIC := '0';
	DATA_O		: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
	DATA_L_O	: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
	DATA_R_O	: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0) := (others => '0');
);
end i2s;

architecture ArrayMode of i2s is

constant PRESCALE	: integer := integer(CLK_MHZ / (SCK_MHZ * 2.0));

signal prescaler	: integer range 0 to PRESCALE-1 := 0;
signal rising		: std_logic := '0';
signal falling		: std_logic := '0';

signal b			: integer range 0 to WORD_SIZE-1 := 0;
signal data			: std_logic_vector(WORD_SIZE-1 downto 0) := (others => '0');

begin

sck : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		rising	<= '0';
		falling <= '0';
	
		if prescaler = PRESCALE-1 then
			prescaler <= 0;
			
			if SCK_O = '0' then
				rising <= '1';
			else
				falling <= '1';
			end if;
			
			SCK_O <= not SCK_O;
		else
			prescaler <= prescaler + 1;
		end if;
	end if;
end process;

read : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		DV_O <= '0';
		
		if rising = '1' then
			data <= data(data'high-1 downto 0) & SD_I; -- Shift in MSB first
			
			if b = WORD_SIZE-1 then
				b <= 0;
			else
				b <= b + 1;
			end if;
		end if;
		
		if falling = '1' then
			if b = 31 then
				WS_O <= '1';
			elsif b = 0 then
				DV_O	<= '1';
				DATA_O	<= data(data'high downto data'high-DATA_WIDTH+1);
				
				data <= (others => '0');
				
				WS_O <= '0';
			end if;
		end if;
	end if;
end process;

end ArrayMode;

architecture StereoMode of i2s is

constant PRESCALE	: integer := integer(CLK_MHZ / (SCK_MHZ * 2.0));

signal prescaler	: integer range 0 to PRESCALE-1 := 0;
signal rising		: std_logic := '0';
signal falling		: std_logic := '0';

signal b			: integer range 0 to WORD_SIZE-1 := 0;
signal data			: std_logic_vector(WORD_SIZE-1 downto 0) := (others => '0');

begin

sck : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		rising	<= '0';
		falling <= '0';
	
		if prescaler = PRESCALE-1 then
			prescaler <= 0;
			
			if SCK_O = '0' then
				rising <= '1';
			else
				falling <= '1';
			end if;
			
			SCK_O <= not SCK_O;
		else
			prescaler <= prescaler + 1;
		end if;
	end if;
end process;

read : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		DV_O <= '0';
		
		if rising = '1' then
			data <= data(data'high-1 downto 0) & SD_I; -- Shift in MSB first
			
			if b = WORD_SIZE-1 then
				b <= 0;
			else
				b <= b + 1;
			end if;
		end if;
		
		if falling = '1' then
			if b = 31 then
				WS_O <= not WS_O;
			elsif b = 0 then
				
				if WS_O = '0' then
					DATA_L_O	<= data(data'high downto data'high-DATA_WIDTH+1);
				else
					DV_O	<= '1';
					DATA_R_O	<= data(data'high downto data'high-DATA_WIDTH+1);
				end if;
				
				data <= (others => '0');
			end if;
		end if;
	end if;
end process;

end StereoMode;