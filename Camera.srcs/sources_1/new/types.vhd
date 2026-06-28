library IEEE;
use IEEE.STD_LOGIC_1164.all;

package types is

	---------------------------------------------------------------------------------------------
	-- attributes
	---------------------------------------------------------------------------------------------

	attribute line_buffer_type	: string;	-- "{bufgdll | ibufg | bufgp | ibuf | bufr | none}";
	attribute clock_signal		: string;	-- "{yes | no}";
	attribute ram_style			: string;	-- "{block | distributed | registers}";
	attribute rom_style			: string;	-- "{block | distributed | registers}";
	attribute U_SET				: string;	-- Group Design Elements
	attribute HU_SET			: string;	-- Group Design Elements Hierachically
	attribute ASYNC_REG 		: string;	-- "{TRUE  | FALSE}";

	---------------------------------------------------------------------------------------------
	-- constants
	---------------------------------------------------------------------------------------------

	constant BPP					: integer := 10;

	---------------------------------------------------------------------------------------------
	-- types
	---------------------------------------------------------------------------------------------

-- Only necessary in ISE
--	type integer_vector is array(natural range <>) of integer;
--	type boolean_vector is array(natural range <>) of boolean;

	type stringarray_t is array(natural range <>) of string(1 to 80);
	
	type array32_t	is array(natural range <>) of std_logic_vector(31 downto 0);
	type array20_t	is array(natural range <>) of std_logic_vector(19 downto 0);
	type array16_t	is array(natural range <>) of std_logic_vector(15 downto 0);
	type array12_t	is array(natural range <>) of std_logic_vector(11 downto 0);
	type array11_t	is array(natural range <>) of std_logic_vector(10 downto 0);
	type array10_t	is array(natural range <>) of std_logic_vector(9 downto 0);
	type array9_t	is array(natural range <>) of std_logic_vector(8 downto 0);
	type array8_t	is array(natural range <>) of std_logic_vector(7 downto 0);
	type array4_t	is array(natural range <>) of std_logic_vector(3 downto 0);

	type bit_array	is array(natural range <>) of std_logic;
	
	--type std_logic_array is array(natural range <>) of std_logic_vector;
	
	type fft_scale_t is array(0 to 4) of integer range 0 to 3;
	
	type line_t is record
		n	: integer;
		x	: real;
		y	: real;
		dx	: real;
		dy	: real;
		dt	: time;
	end record line_t;

	type figure_t is array(natural range <>) of line_t;
	
	subtype pixel_t		is integer range 0 to (2**BPP-1);
	type scanline_t		is array(natural range <>) of pixel_t;
	type scanline_tp	is access scanline_t;
	type image_t		is array(natural range <>, natural range <>) of pixel_t; 
	type image_tp		is access image_t;
	
	constant RISING					: std_logic_vector(1 downto 0) := "01";
	constant FALLING				: std_logic_vector(1 downto 0) := "10";

end types;

package body types is
 
end types;
