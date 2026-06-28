library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use STD.TEXTIO.all;
use work.types.all;
use work.util.all;

entity aisc110c_sim is
Generic (
	WIDTH		: integer := 320;
	HEIGHT		: integer := 240;
	CHANNELS	: integer := 4;
	BPP			: integer := 8;
	MIN_INTERVAL: integer := 2496;
	PREAMBLE	: integer := 0;
	INTERLEAVED	: boolean := false;
	SCALE		: integer := 1;
	FILE_BASE	: string;
	FILE_EXT	: string
);
Port (
	CLK_I		: in	std_logic;
	RST_I		: in	std_logic;
	
	TRIGGER_I	: in	std_logic;
	
	CLK_O		: out	std_logic := '0';
	DVAL_O		: out	std_logic := '0';
	FSYNC_O		: out	std_logic := '0';
	DATA_O		: out	std_logic_vector((CHANNELS*BPP)-1 downto 0) := (others => '0')	
);
end aisc110c_sim;

architecture Behavioral of aisc110c_sim is

constant MAX_COL	: integer := WIDTH/CHANNELS-1;

signal frame		: integer := 0;
signal row			: integer := 0;
signal col			: integer := 0;
signal loaded		: integer := -1;

signal timer		: integer := MIN_INTERVAL;

type state_t is (S_IDLE, S_PRECLOCK, S_PREAMBLE, S_DATA, S_POSTCLOCK);
signal state		: state_t := S_IDLE;

shared variable filename 	: line;

begin

CLK_O <= CLK_I when state /= S_IDLE else '0';

process(CLK_I)
	variable image : image_tp := NULL;
begin
	if rising_edge(CLK_I) then
		if RST_I = '1' then
			frame	<= 0;
			row		<= 0;
			col		<= 0;
			timer	<= MIN_INTERVAL;
			
			if (image /= NULL) then
				deallocate(image);
				image := NULL;
				loaded <= -1;
			end if;
		else
			DVAL_O	<= '0';
			FSYNC_O	<= '0';
			timer	<= timer + 1;
			
			if (image = NULL) then
				log(FILE_BASE & integer'image(frame) & FILE_EXT);
				
				if NOT fileExists(FILE_BASE & integer'image(frame) & FILE_EXT) then				
					frame <= 0;
				else
					image := loadPGM(FILE_BASE & integer'image(frame) & FILE_EXT);
					loaded <= frame;
				end if;
				
			else
				
				case (state) is
				when S_IDLE =>
					if (TRIGGER_I = '1') and (timer >= MIN_INTERVAL-1) then
						state <= S_PRECLOCK;
						
						timer <= 0;
						col <= 0;
					end if;
					
				when S_PRECLOCK =>
					if timer >= 20 then
						timer <= 0;
						
						if PREAMBLE = 0 then
							state <= S_DATA;
						else
							state <= S_PREAMBLE;
						end if;
					else
						timer <= timer + 1;
					end if;
					
				when S_PREAMBLE =>
					if col = 0 then
						FSYNC_O	<= '1';
					end if;
					
					if col = ((image'HIGH(1)+1)/CHANNELS)-1 then
						col 	<= 0;
								
						if row = PREAMBLE-1 then
							state	<= S_DATA;
							row <= 0;
						else
							row <= row + 1;
						end if;
					else
						col <= col + 1;
					end if;
										
				when S_DATA =>
					DVAL_O <= '1';
					
					if INTERLEAVED = TRUE then
						for c in 0 to CHANNELS-1 loop
							DATA_O((c+1) * BPP-1 downto c*BPP) <= int2vec(image(col + c * 2**CHANNELS, row) * SCALE, BPP);
						end loop;
					else
						for c in 0 to CHANNELS-1 loop
							DATA_O((c+1) * BPP-1 downto c*BPP) <= int2vec(image(col * CHANNELS + c, row) * SCALE, BPP);
						end loop;
					end if;

					if col = 0 then
						FSYNC_O	<= '1';
					end if;
								
					if col = ((image'HIGH(1)+1)/CHANNELS)-1 then
						col 	<= 0;
					
						if (row = image'HIGH(2) OR (HEIGHT > 0 AND row = HEIGHT-1)) then
						    timer <= 0;
							state <= S_POSTCLOCK;
							row <= 0;
							frame <= frame + 1;
							deallocate(image);
							image := NULL;
							loaded <= -1;
						else
							row <= row + 1;
						end if;
					else
						col <= col + 1;
					end if;
				
				when S_POSTCLOCK =>
					if timer >= 20 then
						timer <= 0;
						state <= S_IDLE;
					else
						timer <= timer + 1;
					end if;
				 
				end case;
			end if;
		end if;
	end if;
end process;

end Behavioral;
