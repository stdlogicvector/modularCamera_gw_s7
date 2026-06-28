library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use work.util.all;

entity capsense is
Generic (
	DRIVE_TIME	: integer := 50
);
Port (
	CLK_I		: in	STD_LOGIC;
	RST_I		: in	STD_LOGIC;
	
	PIN_IO		: inout STD_LOGIC;
	DETECT_O	: out	STD_LOGIC := '0';
	
	EN_I		: in	STD_LOGIC;
	SENSE_I 	: in	STD_LOGIC_VECTOR(15 downto 0) := int2vec(5000, 16);
	
	DV_O		: out	STD_LOGIC := '0';
	VALUE_O 	: out	STD_LOGIC_VECTOR(15 downto 0) := (others => '0')
);
end capsense;

architecture Behavioral of capsense is

type state_t	is (S_IDLE, S_CLEAR, S_DRIVE, S_SENSE);

signal state	: state_t := S_IDLE;

constant INPUT	: std_logic := '1';
constant OUTPUT	: std_logic := '0';

signal pin_i	: std_logic;
signal pin_o	: std_logic := '0';
signal pin_t	: std_logic := INPUT;

signal done		: std_logic := '0';

signal timer	: integer range 0 to 2**16-1 := 0;

begin

PIN : IOBUF
generic map
(
	DRIVE		=> 12,
	IOSTANDARD	=> "DEFAULT",
	SLEW		=> "SLOW"
)
port map
(
	IO 	=> PIN_IO,			-- Buffer inout port (connect directly to top-level port)
  	O	=> pin_i,			-- Buffer output
    I 	=> pin_o,			-- Buffer input
  	T 	=> pin_t	     	-- 3-state enable input, high=input, low=output 
);

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		DETECT_O <= '0';
		DV_O	 <= '0';
		
		case state is
		when S_IDLE =>
			pin_t <= INPUT;
				
			if EN_I = '1' then
				state <= S_CLEAR;
			end if;
			
		when S_CLEAR =>
			pin_t <= OUTPUT;
			pin_o <= '0';
			timer <= 0;
			
			state <= S_DRIVE;
			
		when S_DRIVE =>
			pin_t <= OUTPUT;
			pin_o <= '1';
			
			if timer > DRIVE_TIME then
				timer <= 0;
				state <= S_SENSE;
			else
				timer <= timer + 1;
			end if;
		
		when S_SENSE =>
			pin_t <= INPUT;
			
			if pin_i = '0' and done = '0' then
				done     <= '1';
				DETECT_O <= '1';
				VALUE_O  <= int2vec(timer, VALUE_O'length);
			end if;
			
			if timer = vec2int(SENSE_I) then
				timer <= 0;
				done  <= '0';
				DV_O  <= '1';
				state <= S_IDLE;
			else
				timer <= timer + 1;
			end if;			
		
		end case;
	end if;
end process;

end Behavioral;
