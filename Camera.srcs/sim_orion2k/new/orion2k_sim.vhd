library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types.all;
use work.util.all;

entity orion2k_sim is
Generic (
	PIXELS			: integer := 2128;
	RESOLUTION		: integer range 11 to 13 := 11;
	PATTERN			: std_logic_vector(15 downto 0) := x"0000"
);
Port (
	MCLKp_I			: in  STD_LOGIC;
	MCLKn_I			: in  STD_LOGIC;
	RST_I			: in  STD_LOGIC;
	
	READOUT_I		: in  STD_LOGIC;
	
	CLKp_O			: out STD_LOGIC := '0';
	CLKn_O			: out STD_LOGIC := '1';
	
	LVAL_O			: out STD_LOGIC_VECTOR(1 downto 0) := "00";
		
	SEG1_LSB_Ap_O	: out STD_LOGIC := '0';
	SEG1_LSB_An_O	: out STD_LOGIC := '1';
	
	SEG1_LSB_Bp_O	: out STD_LOGIC := '0';
	SEG1_LSB_Bn_O	: out STD_LOGIC := '1';
	
	SEG1_MSB_Ap_O	: out STD_LOGIC := '0';
	SEG1_MSB_An_O	: out STD_LOGIC := '1';
	
	SEG1_MSB_Bp_O	: out STD_LOGIC := '0';
	SEG1_MSB_Bn_O	: out STD_LOGIC := '1';
	
	SEG2_LSB_Ap_O	: out STD_LOGIC := '0';
	SEG2_LSB_An_O	: out STD_LOGIC := '1';
	
	SEG2_LSB_Bp_O	: out STD_LOGIC := '0';
	SEG2_LSB_Bn_O	: out STD_LOGIC := '1';
	
	SEG2_MSB_Ap_O	: out STD_LOGIC := '0';
	SEG2_MSB_An_O	: out STD_LOGIC := '1';
	
	SEG2_MSB_Bp_O	: out STD_LOGIC := '0';
	SEG2_MSB_Bn_O	: out STD_LOGIC := '1'
);
end orion2k_sim;

architecture Behavioral of orion2k_sim is

signal clk			: std_logic;

type state_t is (
	S_IDLE,
	S_TRAINING,
	S_DATA
);

signal start		: std_logic := '0';

signal state		: state_t := S_IDLE;
signal counter		: integer := 0;
signal bit			: integer := 0;

signal pixel		: integer := 0;
signal pixel_v		: array16_t(0 to 3);
signal output		: array16_t(0 to 3);

signal SEG1_EVEN_O	: std_logic_vector(1 downto 0) := (others => '0');
signal SEG1_ODD_O	: std_logic_vector(1 downto 0) := (others => '0');
signal SEG2_EVEN_O	: std_logic_vector(1 downto 0) := (others => '0');
signal SEG2_ODD_O	: std_logic_vector(1 downto 0) := (others => '0');

begin

dataclock : process
begin
	clock(200.0, 0ns, clk);
end process;

pixel_v(0) <= int2vec(pixel*1 +    0, 16);
pixel_v(1) <= int2vec(pixel*1 +    1, 16);
pixel_v(2) <= int2vec(pixel*1 + 1064, 16);
pixel_v(3) <= int2vec(pixel*1 + 1065, 16);

format : for i in 0 to 3 generate

output(i)(15 downto RESOLUTION + 2) <= (others => '0');
output(i)(RESOLUTION + 1 downto 9)  <= pixel_v(i)(RESOLUTION - 1 downto 7);
output(i)(8) 						<= '0';
output(i)(7 downto 1) 			    <= pixel_v(i)(6 downto 0);
output(i)(0) 						<= '0';

end generate;

SEG1_LSB_Ap_O	<= SEG1_EVEN_O(0);
SEG1_MSB_Ap_O	<= SEG1_EVEN_O(1);

SEG1_LSB_Bp_O	<= SEG1_ODD_O(0);
SEG1_MSB_Bp_O	<= SEG1_ODD_O(1);

SEG2_LSB_Ap_O	<= SEG2_EVEN_O(0);
SEG2_MSB_Ap_O	<= SEG2_EVEN_O(1);

SEG2_LSB_Bp_O	<= SEG2_ODD_O(0);
SEG2_MSB_Bp_O	<= SEG2_ODD_O(1);

SEG1_LSB_An_O	<= not SEG1_EVEN_O(0);
SEG1_MSB_An_O	<= not SEG1_EVEN_O(1);

SEG1_LSB_Bn_O	<= not SEG1_ODD_O(0);
SEG1_MSB_Bn_O	<= not SEG1_ODD_O(1);

SEG2_LSB_An_O	<= not SEG2_EVEN_O(0);
SEG2_MSB_An_O	<= not SEG2_EVEN_O(1);

SEG2_LSB_Bn_O	<= not SEG2_ODD_O(0);
SEG2_MSB_Bn_O	<= not SEG2_ODD_O(1);

data : process(clk)
begin
	if rising_edge(clk) then
		LVAL_O <= "00";
		
		CLKp_O <= not CLKp_O;
		CLKn_O <= not CLKn_O;
		
		case state is
		when S_IDLE =>
			if READOUT_I = '1' then
				start <= '1';
			end if;
			
			if bit = 0 then
				bit <= 7;
				
				if start = '1' then
					state <= S_TRAINING;
					start <= '0';
				end if;
			else
				bit <= bit - 1;
			end if;			
			
			if counter mod 2 = 0 then
				SEG1_EVEN_O <= PATTERN(bit + 8) & PATTERN(bit + 0); 
				SEG1_ODD_O  <= PATTERN(bit + 8) & PATTERN(bit + 0);
				SEG2_EVEN_O <= PATTERN(bit + 8) & PATTERN(bit + 0); 
				SEG2_ODD_O  <= PATTERN(bit + 8) & PATTERN(bit + 0);
			else
				SEG1_EVEN_O <= PATTERN(bit + 8) & PATTERN(bit + 0); 
				SEG1_ODD_O  <= PATTERN(bit + 8) & PATTERN(bit + 0);
				SEG2_EVEN_O <= PATTERN(bit + 8) & PATTERN(bit + 0); 
				SEG2_ODD_O  <= PATTERN(bit + 8) & PATTERN(bit + 0);
			end if;	
			
		when S_TRAINING =>
			if bit = 0 then
				bit <= 7;
				
				if counter = 7 then
					counter <= 0;
					state <= S_DATA;
				else
					counter <= counter + 1;
				end if;
			else
				bit <= bit - 1;
			end if;			
			
			if counter mod 2 = 0 then
				SEG1_EVEN_O <= PATTERN(bit + 8) & PATTERN(bit + 0); 
				SEG1_ODD_O  <= PATTERN(bit + 8) & PATTERN(bit + 0);
				SEG2_EVEN_O <= PATTERN(bit + 8) & PATTERN(bit + 0); 
				SEG2_ODD_O  <= PATTERN(bit + 8) & PATTERN(bit + 0);
			else
				SEG1_EVEN_O <= PATTERN(bit + 8) & PATTERN(bit + 0); 
				SEG1_ODD_O  <= PATTERN(bit + 8) & PATTERN(bit + 0);
				SEG2_EVEN_O <= PATTERN(bit + 8) & PATTERN(bit + 0); 
				SEG2_ODD_O  <= PATTERN(bit + 8) & PATTERN(bit + 0);
			end if;			
			
		when S_DATA =>
			LVAL_O <= "11";
			
			if bit = 0 then
				bit <= 7;
				
				if pixel >= (548-1)*2 then
					pixel <= 0;
					state <= S_IDLE;
				else
					pixel <= pixel + 2;
				end if;
			else
				bit <= bit - 1;
			end if;		
		
			SEG1_EVEN_O <= output(0)(bit + 8) & output(0)(bit + 0); 
			SEG1_ODD_O  <= output(1)(bit + 8) & output(1)(bit + 0);
			SEG2_EVEN_O <= output(2)(bit + 8) & output(2)(bit + 0); 
			SEG2_ODD_O  <= output(3)(bit + 8) & output(3)(bit + 0);
		
		end case;
	end if;
end process;

end Behavioral;
