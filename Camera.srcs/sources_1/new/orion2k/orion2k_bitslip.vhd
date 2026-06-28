library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED;
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity orion2k_bitslip is
	generic (
		W			: integer := 8;	-- Data Width
		S			: integer := 2;	-- Segments
		D			: integer := 4	-- Input Number per Segment
	);
	port (
		RST_I		: in  STD_LOGIC;
		DATA_CLK_I	: in  STD_LOGIC;
	
		ENABLE_I	: in  STD_LOGIC;
		PATTERN_I	: in  STD_LOGIC_VECTOR(S*W-1 downto 0);
	
		LVAL_I		: in  STD_LOGIC_VECTOR((S-1) downto 0);
		DATA_I		: in  STD_LOGIC_VECTOR(((S*D*W)-1) downto 0);	-- 8x 8bits
		
		BITSLIP_I	: in  STD_LOGIC_VECTOR(((S*D)-1) downto 0);
		
		BITSLIP_O	: out STD_LOGIC_VECTOR(((S*D)-1) downto 0)
	);
end orion2k_bitslip;

architecture RTL of orion2k_bitslip is

constant N			: integer := S*D;	-- Number of Data Channels
constant C			: integer := 5;		-- Number of DataClocks to delay LVAL

signal lval 		: std_logic_vector(N-1 downto 0) := (others => '0');

type delay_array is array ((S-1) downto 0) of std_logic_vector((C-1) downto 0);
signal lval_dly 	: delay_array := (others => (others => '0'));

type flag_array	is array(N-1 downto 0) of std_logic_vector(4 downto 0);
signal bitslip_flag		: flag_array := (others => (others => '0'));
--signal bitslip_flag	: std_logic_vector(N-1 downto 0);

type data_array is array(((S*D)-1) downto 0) of std_logic_vector(W-1 downto 0);
signal data 		: data_array := (others => (others => '0'));

signal bitslip 		: std_logic_vector(((S*D)-1) downto 0) := (others => '0');
signal bitslip_last	: std_logic_vector(((S*D)-1) downto 0) := (others => '0');
signal bitslip_edge	: std_logic_vector(((S*D)-1) downto 0) := (others => '0');

begin

BITSLIP_O <= bitslip OR bitslip_edge;

DATA_BYTES : for i in 0 to (N-1) generate
	DATA_BITS : for b in 0 to (W-1) generate
		data(i)(b) <= DATA_I(i*8 + b);
	end generate DATA_BITS;
end generate DATA_BYTES;

process (DATA_CLK_I)
variable tw : integer range 0 to 1 := 0;
begin
	if falling_edge(DATA_CLK_I) then
		if (RST_I = '1') then
			bitslip_flag		<= (others => (others => '0'));
			bitslip				<= (others => '0');
		else
			
			bitslip_last <= BITSLIP_I;
			bitslip_edge <= BITSLIP_I AND NOT bitslip_last;					-- Manual Bitslip only on rising edge
			
			lval_loop : for s in 0 to (S-1) loop							-- Delay Line Valid signal to match pipelined data output
				lval_dly(s)(0) <= LVAL_I(s);
				
				delay_loop : for i in 1 to (C-1) loop
					lval_dly(s)(i) <= lval_dly(s)(i-1);
				end loop;
			end loop;
			
			bitslip_seg : for s in 0 to (S-1) loop		-- 0,1
				bitslip_bit : for i in 0 to (D-1) loop	-- 0,1,2,3
				
					tw := (s*D+i) rem 2;
				
					bitslip_flag(s*D+i)(4 downto 1) <= bitslip_flag(s*D+i)(3 downto 0);
				
					if (ENABLE_I = '1') then
						if (or(lval_dly(s)) = '0') AND (or(bitslip_flag(s*D+i)) = '0') then 	-- Not already bitslipping or in line
							if (data(s*D+i) /= PATTERN_I((tw+1)*W-1 downto tw*W)) then			-- Training Pattern not matching
								bitslip(s*D+i) 			<= '1';									-- Send Bitslip signal
								bitslip_flag(s*D+i)(0)	<= '1';
							else
								bitslip(s*D+i) 			<= '0';
								bitslip_flag(s*D+i)(0)	<= '0';
							end if;
						else
							bitslip(s*D+i) 				<= '0';									-- Training Pattern not active
							bitslip_flag(s*D+i)(0)		<= '0';
						end if;
					else
						bitslip(s*D+i) 					<= '0';
						bitslip_flag(s*D+i)(0)			<= '0';
					end if;
				end loop;
			end loop;
			
		end if;
	end if;
end process;

end RTL;

