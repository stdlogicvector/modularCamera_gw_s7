library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use work.util.all;

entity FX3 is
Generic (
	DATA_WIDTH		: integer := 32;
	INVERT_CLK		: boolean := false
);
Port (
	CLK_I			: in STD_LOGIC;
	RST_I			: in STD_LOGIC;
	
	-- AXI Slave
	S_AXIS_TVALID_I	: in STD_LOGIC;
	S_AXIS_TLAST_I	: in STD_LOGIC;
	S_AXIS_TUSER_I	: in STD_LOGIC_VECTOR(1 downto 0);
	S_AXIS_TDATA_I	: in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
	S_AXIS_TREADY_O	: out STD_LOGIC := '0';
	
	THRESHOLD_I		: in STD_LOGIC := '1';
	
	HBLANK_I		: in STD_LOGIC_VECTOR(7 downto 0);
	VBLANK_I		: in STD_LOGIC_VECTOR(7 downto 0);
	
	-- FX3
	CLK_O			: out STD_LOGIC := '0';
	CTL_IO			: inout STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
	DATA_O			: out STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
	
	-- DBG
	FVAL_O			: out STD_LOGIC := '0';
	LVAL_O			: out STD_LOGIC := '0'
);
end FX3;

architecture Behavioral of FX3 is

type state_t is (S_IDLE, S_WAIT, S_LINE, S_LINE_PAUSE, S_FRAME_PAUSE);

signal state			: state_t := S_IDLE;

signal lval				: std_logic := '0';
signal fval				: std_logic := '0';

signal timer			: std_logic_vector(7 downto 0) := (others => '0');

signal eof				: std_logic := '0';

begin

FRAME_VALID : OBUF
generic map (
	DRIVE		=> 12,
	IOSTANDARD	=> "DEFAULT",
	SLEW		=> "SLOW"
)
port map (
	O			=> CTL_IO(0),
	I			=> fval 
);

FVAL_O <= fval;

LINE_VALID : OBUF
generic map (
	DRIVE		=> 12,
	IOSTANDARD	=> "DEFAULT",
	SLEW		=> "SLOW"
)
port map (
	O			=> CTL_IO(1),
	I			=> lval 
);

LVAL_O <= lval;

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		
		DATA_O(DATA_WIDTH-1 downto 0) <= S_AXIS_TDATA_I;
				
		case state is
		when S_IDLE =>
			fval			<= '0';
			lval			<= '0';
			S_AXIS_TREADY_O <= '0';
			
			if (THRESHOLD_I = '1') AND (S_AXIS_TVALID_I = '1') AND (S_AXIS_TUSER_I(0) = '1') then
				state <= S_FRAME_PAUSE;
			else
				state <= S_IDLE;
			end if;		
		
		when S_WAIT =>
			if (THRESHOLD_I = '1') AND (S_AXIS_TVALID_I = '1') then
				S_AXIS_TREADY_O <= '1';
				state <= S_LINE;
			else
				state <= S_WAIT;
			end if;				
		
		when S_LINE =>
			eof	<= S_AXIS_TUSER_I(1);

			if S_AXIS_TLAST_I = '1' then
				state			<= S_LINE_PAUSE;
				lval			<= '1';
				S_AXIS_TREADY_O <= '0';
			else
				lval			<= '1';
				state 			<= S_LINE;
				S_AXIS_TREADY_O <= '1';
			end if;
		
		when S_LINE_PAUSE =>
			lval			<= '0';
			fval			<= not eof;
			S_AXIS_TREADY_O <= '0';
			
			if (timer >= HBLANK_I) then
				timer <= (others => '0');
	
				if eof = '1' then
					state <= S_IDLE;
				elsif THRESHOLD_I = '0' then
					state <= S_WAIT;
				else
					S_AXIS_TREADY_O <= '1';
					state <= S_LINE;
				end if;
			else
				timer <= inc(timer);
			end if;
		
		when S_FRAME_PAUSE =>
			
			if (timer >= VBLANK_I) then
				timer 			<= (others => '0');
				fval			<= '1';
				S_AXIS_TREADY_O <= '1';
				state			<= S_LINE;
			else
				fval			<= '0';
				S_AXIS_TREADY_O <= '0';
				timer			<= inc(timer);
			end if;
		
		end case;
	
		if RST_I = '1' then
			state <= S_IDLE;
		end if;
	
	end if;
end process;

fx3_clk : ODDR
generic map(
	DDR_CLK_EDGE	=> "OPPOSITE_EDGE",	-- Sets output alignment to "NONE", "C0", "C1" 
	INIT			=> '0',		-- Sets initial state of the Q output to '0' or '1'
	SRTYPE			=> "ASYNC"	-- Specifies "SYNC" or "ASYNC" set/reset
)
port map (
	Q		=> CLK_O,
	C		=> CLK_I,
	CE		=> '1',
	D1		=> switch(INVERT_CLK, '0', '1'),
	D2		=> switch(INVERT_CLK, '1', '0'),
	R		=> '0',
	S		=> '0'
);

end Behavioral;
