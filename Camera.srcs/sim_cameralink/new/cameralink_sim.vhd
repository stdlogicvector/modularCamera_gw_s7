library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use STD.TEXTIO.all;
use work.types.all;
use work.util.all;

entity cameralink_sim is
Generic (
	CLOCK_MHZ		: real	  := 80.0; --MHz
	WIDTH			: integer := 320;
	HEIGHT			: integer := 240;
	CHANNELS		: integer := 3;
	BPP				: integer := 8;
	N				: integer := 7;	-- SERDES Factor
	D				: integer := 4;	-- Data Lines
	CLOCK_PATTERN	: std_logic_vector(N-1 downto 0) := "1100011";
	INTERLEAVED		: boolean := false;
	LINE_PAUSE		: time := 1us;
	FRAME_PAUSE		: time := 10us;	
	SCALE			: integer := 1;
	FILE_BASE		: string;
	FILE_EXT		: string
);
Port (
	RST_I			: in	std_logic;
	
	-- Pixel Lines
	XCLKp_O			: out	std_logic;
	XCLKn_O			: out	std_logic;
	
	Xp_O			: out	std_logic_vector((D-1) downto 0);
	Xn_O			: out	std_logic_vector((D-1) downto 0);
	
	-- Control Lines
	CCp_I			: in	std_logic_vector(3 downto 0) := (others => '0');
	CCn_I			: in	std_logic_vector(3 downto 0) := (others => '1');
	
	-- Serial Lines
	SERTFGp_O		: out	std_logic := '0';	
	SERTFGn_O		: out	std_logic := '1';
	SERTCp_I		: in	std_logic;
	SERTCn_I		: in	std_logic	
);
end cameralink_sim;

architecture Behavioral of cameralink_sim is

signal clk			: std_logic := '0';

signal xclk			: std_logic;
signal x			: std_logic_vector(D-1 downto 0);
signal cc			: std_logic_vector(3 downto 0);

constant MAX_COL	: integer := WIDTH/CHANNELS-1;

signal row			: integer := 0;
signal col			: integer := 0;
signal loaded		: integer := -1;

signal fval			: std_logic := '0';
signal lval			: std_logic := '0';
signal dval			: std_logic := '0';
signal data			: std_logic_vector((BPP*CHANNELS)-1 downto 0) := (others => '0');

type data_ch_t		is array(0 to D-1) of std_logic_vector(N-1 downto 0);
signal data_ch		: data_ch_t := (others => (others => '0'));

signal i			: integer range 0 to N-1 := 0;

type state_t is (S_IDLE, S_DATA, S_EOL, S_LINE_PAUSE, S_EOF, S_FRAME_PAUSE);
signal state		: state_t := S_IDLE;

constant LINE_PAUSE_CNT		: integer := integer(real(LINE_PAUSE  / 1000ns) * CLOCK_MHZ);
constant FRAME_PAUSE_CNT	: integer := integer(real(FRAME_PAUSE / 1000ns) * CLOCK_MHZ);

signal timer				: integer := 0;

shared variable filename 	: line;
shared variable image		: image_tp := NULL;
shared variable frame		: integer := 0;

begin

XCLKp_O <=     xclk;
XCLKn_O <= not xclk;

Xp_O <=     x;
Xn_O <= not x;

cc <= CCp_I and not CCn_I;

data_ch(0) <= (
	 0	=> data(8),			-- 8
	 1	=> data(5),			-- 5
	 2	=> data(4),			-- 4
	 3	=> data(3),			-- 3
	 4	=> data(2),			-- 2
	 5	=> data(1),			-- 1
	 6	=> data(0)			-- 0
);

data_ch(1) <= (		
	0	=> data(13),		-- 13
	1	=> data(12),		-- 12
	2	=> data(21),		-- 21
	3	=> data(20),		-- 20
	4	=> data(11),		-- 11
	5	=> data(10),		-- 10
	6	=> data(9)			-- 9
);

data_ch(2) <= (		
	0	=> dval,			-- DVAL
	1	=> fval,			-- FVAL
	2	=> lval,			-- LVAL
	3	=> data(17),		-- 17
	4	=> data(16),		-- 16
	5	=> data(15),		-- 15
	6	=> data(14)			-- 14
);

data_ch(3) <= (		
	0	=> '0',				-- SPARE
	1	=> data(19),		-- 19
	2	=> data(18),		-- 18
	3	=> data(23),		-- 23
	4	=> data(22),		-- 22
	5	=> data(7),			-- 7
	6	=> data(6)			-- 6
);

process
begin
	wait for 1us / (CLOCK_MHZ * N);

	xclk <= CLOCK_PATTERN(i);
	
	for c in 0 to D-1 loop
		x(c) <= data_ch(c)(i);
	end loop;
	
	if i < N-1 then
		i <= i + 1;
		clk <= '0';
	else
		i <= 0;
		clk <= '1';
	end if; 
end process;

process(fval, RST_I)
begin
	if (image = NULL) then
		deallocate(image);
		loaded <= -1;
		
		if NOT fileExists(FILE_BASE & integer'image(frame) & FILE_EXT) then				
			frame := 0;
		end if;
		
		image := loadPGM(FILE_BASE & integer'image(frame) & FILE_EXT);
		loaded <= frame;
	
	end if;
end process;

process(clk)
begin
	if rising_edge(clk) then
		if RST_I = '1' then
			frame	:= 0;
			state 	<= S_IDLE;
			
			if (image /= NULL) then
				image := NULL;
			end if;
		else
			case (state) is
			when S_IDLE =>
				fval <= '0';
				lval <= '0';
				dval <= '0';
				data <= (others => '0');
				
				if (cc(0) = '1') then
					state	<= S_LINE_PAUSE;
					fval	<= '1';
					col 	<= 0;
					row		<= 0;
				end if;

			when S_LINE_PAUSE =>
				
				if timer = LINE_PAUSE_CNT then
					lval <= '1';
					timer <= 0;
					state <= S_DATA;
				else
					timer <= timer + 1;
				end if;

			when S_DATA =>
		
				if INTERLEAVED = TRUE then
					for c in 0 to CHANNELS-1 loop
						data((c+1) * BPP-1 downto c*BPP) <= int2vec(image(col + c * 2**CHANNELS, row) * SCALE, BPP);
					end loop;
				else
					for c in 0 to CHANNELS-1 loop
						data((c+1) * BPP-1 downto c*BPP) <= int2vec(image(col * CHANNELS + c, row) * SCALE, BPP);
					end loop;
				end if;
								
				if col = ((image'HIGH(1)+1)/CHANNELS)-1 then
					dval 	<= '0';
					col 	<= 0;
					state	<= S_EOL;
				else
					dval	<= '1';
					col		<= col + 1;
				end if;
			 
			 when S_EOL =>
				lval <= '0';
				
				if (row = image'HIGH(2) OR (WIDTH > 0 AND row = WIDTH-1)) then
					row		<= 0;
					state	<= S_EOF;
				else
					row <= row + 1;
					state <= S_LINE_PAUSE;
				end if;
		
			when S_EOF =>
				fval	<= '0';
				frame	:= frame + 1;
				image := NULL;
				state <= S_FRAME_PAUSE;
		
			when S_FRAME_PAUSE =>
				if timer = FRAME_PAUSE_CNT then
					timer <= 0;
         			state <= S_IDLE;
				else
					timer <= timer + 1;
				end if;
			 
			end case;
		end if;	
	end if;
end process;

end Behavioral;
