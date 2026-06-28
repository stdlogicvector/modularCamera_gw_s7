library IEEE; 
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use Work.util.all;

entity crc16 is 
	port (
		CLK_I 	: in	std_logic;
		RESET_I	: in	std_logic;
		CRC_EN_I: in	std_logic;
  		DATA_I	: in	std_logic_vector ( 7 downto 0);
    	CRC_O 	: out	std_logic_vector (15 downto 0)
    );
end crc16;

architecture imp_crc16 of crc16 is	
  signal crc_lng	: std_logic_vector (16 downto 0) := (others => '0');
  signal crc_int	: std_logic_vector (15 downto 0) := (others => '0');
  signal crc_sum	: std_logic_vector (15 downto 0) := (others => '0');
  signal msb		: std_logic_vector ( 7 downto 0) := (others => '0');
  signal data		: std_logic_vector (15 downto 0) := (others => '0');
  signal byte		: std_logic := '0';
begin	

	crc_sum <= crc_lng(15 downto 0) + crc_lng(16);
	CRC_O 	<= NOT crc_sum;
 	data 	<= msb & DATA_I;
 
	process (CLK_I, RESET_I)
	begin
		if falling_edge(CLK_I) then 
			if (RESET_I = '1') then 
				crc_int	<= (others => '0');
				crc_lng <= (others => '0');
				msb		<= (others => '0');
				byte 	<= '0';
			else	 
				if (CRC_EN_I = '1') then 
					if (byte = '0') then
						msb <= DATA_I;
						byte <= '1';
						crc_int	<= crc_sum;
					else
						crc_lng <= ('0' & crc_int) + ('0' & data);
						byte <= '0';
					end if;
				end if; 
			end if; 
		end if;
	end process; 
    
end architecture imp_crc16; 