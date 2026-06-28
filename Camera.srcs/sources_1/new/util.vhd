library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use STD.TEXTIO.ALL;
use work.types.all;

package Util is

	---------------------------------------------------------------------------------------------
	-- constants
	---------------------------------------------------------------------------------------------
	
	constant LINE_LENGTH_MAX		: integer := 256;

	shared variable RAND_SEED1		: integer := 123;
	shared variable RAND_SEED2		: integer := 345;
	
	---------------------------------------------------------------------------------------------
	-- Simulation Helpers
	---------------------------------------------------------------------------------------------

	function format_time(t : time; u : string) return string;

	procedure wait_until(t : time);

	procedure uart_getc(signal c : out std_logic_vector(7 downto 0); signal rx : in std_logic; baudrate : integer);
	procedure uart_putc(char : std_logic_vector(7 downto 0); signal tx : out std_logic; baudrate : integer);
	procedure uart_puts(str  : string; signal tx : out std_logic; baudrate : integer);

	function time2clks(t : time; f : integer) return integer;
	
	procedure pulse(idle: std_logic; mark: std_logic; len: time; signal sig : out std_logic);
	procedure clock(MHz : real; offset : time := 0 ns; signal clk : out std_logic);
	procedure clock_diff(MHz : real; offset : time := 0 ns; signal clk_p, clk_n : out std_logic);
	
	impure function fileExists(filename: string) return boolean;
	
	procedure readUntilSep(l : inout line; sep : in character; value : inout line);
	
	procedure save2file(
		signal clk 		: in std_logic;
		signal reset	: in std_logic;
		signal w_en		: in std_logic;
		signal data		: in std_logic_vector;
		signal eol		: in std_logic;
		signal eof		: in std_logic;
		
		constant sign		: boolean;
		constant segments	: in integer;
		constant seg_width	: in integer;
		constant basename	: string;
		
		variable f_nr		: inout integer;
		variable l_nr		: inout integer;
		variable p_nr		: inout integer;
		variable values 	: inout line
	);
	
	procedure save2image(
		signal clk 			: in std_logic;
		signal reset 		: in std_logic;
		signal w_en 		: in std_logic;
		signal data 		: in std_logic_vector;
		signal eof			: in std_logic;
		
		constant basename	: string;
		constant width		: integer;
		constant height		: integer;
		constant segments 	: integer;
		constant seg_width	: integer;
		constant scale_to	: natural;
		constant offset		: natural;
		
		variable frame		: inout integer;
		variable row		: inout integer;
		variable col		: inout integer;
		variable max		: inout integer;
		variable pixel		: inout scanline_tp
	);
	
	impure function loadPGM(filename: string) return image_tp;
	
	---------------------------------------------------------------------------------------------
	-- Conversions
	---------------------------------------------------------------------------------------------

	function str2int(x_str : string; radix : positive range 2 to 36 := 10) return integer;

	function real2fixed(r : real; l, u : integer) return std_logic_vector;
	function char2vec(c : character) return std_logic_vector;
	function char2vec(c : character; l : integer) return std_logic_vector;
	function int2vec(i : integer; l : integer) return std_logic_vector;
	function sint2vec(i : integer; l : integer) return std_logic_vector;
	
	function int2signed(i: integer; l : integer) return signed;
		
	function str2vec(s : string) return std_logic_vector;
	function vec2int(v : std_logic_vector) return integer;
	function svec2int(v : std_logic_vector) return integer;
	function vec2int(v : std_logic) return integer;
	
	function vec2str(v: std_logic_vector) return string;
	function svec2str(v: std_logic_vector) return string;
	
	function vec2hex(v: std_logic_vector) return string;
	
	function str2bytes(s: string) return array8_t;
	
	function bit2vec(b: std_logic; l : integer) return std_logic_vector;
	
	function bool2bit(b: boolean) return std_logic;
	function bool2bit(b: boolean_vector) return std_logic_vector;
	
	function ip2vec(f0, f1, f2, f3 : integer range 0 to 255) return std_logic_vector;
	function mac2vec(m0, m1, m2, m3, m4, m5 : std_logic_vector(7 downto 0)) return std_logic_vector;

	---------------------------------------------------------------------------------------------
	-- Math Helpers
	---------------------------------------------------------------------------------------------

	pure function clogb2 (depth : natural) return integer;
	pure function bits(n : integer) return integer;
	pure function ispowerof2(n : integer) return boolean;

	pure function count(v : std_logic_vector) return integer;

	pure function sum(v : integer_vector) return integer;
	pure function sum(v : integer_vector; upto: integer) return integer;
		
	function inc(v : std_logic_vector) return std_logic_vector;
	function dec(v : std_logic_vector) return std_logic_vector;
	
	pure function qabs(v: std_logic_vector) return std_logic_vector;
	
	function add(v : std_logic_vector; i : integer) return std_logic_vector;
	function add(v1 : std_logic_vector; v2 : std_logic_vector) return std_logic_vector;
	function add(v : std_logic_vector; i : integer; l : integer) return std_logic_vector;
	function sub(v : std_logic_vector; i : integer) return std_logic_vector;
	function sub(v1 : std_logic_vector; v2 : std_logic_vector) return std_logic_vector;
	function sub(v : std_logic_vector; i : integer; l : integer) return std_logic_vector;
	
	impure function random_int(min, max : integer) return integer;
	impure function random_real(min, max : real) return real;
	impure function random_vec(min, max : integer; l: integer) return std_logic_vector;
	impure function random_bit return std_logic;
	impure function random_time(min, max : time; unit : time := ns) return time;

	function max(l, r: integer) return integer;
	function min(l, r: integer) return integer;

	---------------------------------------------------------------------------------------------
	-- Vector Helpers
	---------------------------------------------------------------------------------------------

	pure function bit_reverse(v : std_logic_vector) return std_logic_vector;
	pure function byte_reverse(v : std_logic_vector) return std_logic_vector;
	pure function word_reverse(v: std_logic_vector) return std_logic_vector;
	
	pure function nibble(vec : std_logic_vector; index : integer) return std_logic_vector;
	pure function byte(vec : std_logic_vector; index : integer) return std_logic_vector;
	
	pure function zero_resize(v : std_logic_vector; width : natural) return std_logic_vector;
	pure function sign_resize(v : std_logic_vector; width : natural) return std_logic_vector;
	
	pure function zero_resize_u(v : std_logic_vector; width : natural) return unsigned;
	pure function sign_resize_s(v : std_logic_vector; width : natural) return signed;
	
	pure function zero_resize_u(v : unsigned; width : natural) return unsigned;
	pure function sign_resize_s(v : signed; width : natural) return signed;
	
	pure function zero_shift_right(v : std_logic_vector; steps : natural) return std_logic_vector;
	pure function sign_shift_right(v : std_logic_vector; steps : natural) return std_logic_vector;
		
	pure function or_reduce(v : std_logic_vector) return std_logic;
	pure function and_reduce(v : std_logic_vector) return std_logic;
	
	pure function pad(l : integer; v: std_logic_vector) return std_logic_vector;
	pure function pad(l : integer; v: std_logic) return std_logic_vector;
	pure function pad(l : integer; v: unsigned) return unsigned;
		
	function fill(width : natural; v : std_logic) return std_logic_vector;
	function fill(width : natural; v : std_logic_vector) return std_logic_vector;
	
	---------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------
	
	function calc_oversample(clk_freq : integer; baudrate : integer) return integer;
	function switch(c : boolean; t : integer; f : integer) return integer;
	function switch(c : boolean; t : real; f : real) return real;
	function switch(c : boolean; t : string; f : string) return string;
	function switch(c : boolean; t : std_logic_vector; f : std_logic_vector) return std_logic_vector;
	function switch(c : boolean; t : bit_vector; f : bit_vector) return bit_vector;
	function switch(c : boolean; t : integer_vector; f : integer_vector) return integer_vector;
	function switch(c : boolean; t : std_logic; f : std_logic) return std_logic;
	function switch(c : boolean; t : character; f : character) return character;
	procedure log(msg: string);
	
end Util;

package body Util is

--function format_time(t : time; u : string(1 to 2)) return string
function format_time(t : time; u : string) return string
is
	variable r : real;
begin
	case (u(1 to 2)) is
	when "ps" => r := real(t / 1 ps);
	when "ns" => r := real(t / 1 ns);
	when "us" => r := real(t / 1 us);
	when "ms" => r := real(t / 1 ms); 
	when others => r := real(t / 1 ps);
	end case;
	
	return real'image(r/1000.0) & " " & u;
	
--	return time'image(t);
end function;

procedure wait_until(t : time) is
begin
	while (true) loop
		wait for 1 ns;
		exit when now >= t;
	end loop;
end procedure;

procedure uart_puts(str : string; signal tx : out std_logic; baudrate : integer)
is
	variable c : integer;
begin
	for c in 1 to str'length loop
		uart_putc(char2vec(str(c)), tx, baudrate);
	end loop;
end procedure;

procedure uart_putc(char : std_logic_vector(7 downto 0); signal tx : out std_logic; baudrate : integer)
is
	constant BITTIME	: time := (1000000.0 / real(baudrate)) * 1 us;
begin
	-- Startbit
	tx <= '0';
	wait for BITTIME;
	
	-- Databits
	for i in 0 to 7 loop
		tx <= char(i);
		wait for BITTIME;
	end loop;
	
	-- Stopbit
	tx <= '1';
	
	wait for BITTIME * 2;
end procedure;

procedure uart_getc(signal c : out std_logic_vector(7 downto 0); signal rx : in std_logic; baudrate : integer) 
is
	constant BITTIME	: time := (1000000.0 / real(baudrate)) * 1 us;
	variable tmp		: std_logic_vector(7 downto 0) := x"00"; 
begin
	wait until rx = '0';			-- Start Bit
	tmp := x"00";
	wait for BITTIME * 1.5;			-- Center of First Bit
	
	for i in 0 to 7 loop
		tmp(i) := rx;				-- 8 Databits
		wait for BITTIME;
	end loop;
	
	if (rx = '0') then
		wait until rx = '1';		-- Stop Bit
	end if;

	c <= tmp;
end procedure;

impure function fileExists(filename: string) return boolean is
	variable open_status :FILE_OPEN_STATUS;
	file     infile      :text;
begin
	file_open(open_status, infile, filename, read_mode);
	if open_status /= open_ok then
		return false;
	else
		file_close(infile);
		return true;
	end if;
end function;

procedure save2file(
		signal clk 		: in std_logic;
		signal reset	: in std_logic;
		signal w_en		: in std_logic;
		signal data		: in std_logic_vector;
		signal eol		: in std_logic;
		signal eof		: in std_logic;
		
		constant sign		: boolean;
		constant segments	: in integer;
		constant seg_width	: in integer;
		constant basename	: string;
		
		variable f_nr		: inout integer;
		variable l_nr		: inout integer;
		variable p_nr		: inout integer;
		variable values 	: inout line
) is
	FILE out_file       : text;
	variable filename	: line;
	variable buf		: line;
	
	variable value_str	: line;
	variable value_int	: integer;
	variable value_vec	: std_logic_vector(seg_width-1 downto 0);
begin
	if rising_edge(clk) then
		if reset = '1' then
			f_nr := 0;
			l_nr := 0;
			p_nr := 0;		
		
			-- Empty the file
			deallocate(filename);
			write(filename, basename & "_" & integer'image(f_nr) & ".csv");

			file_open(out_file, filename.all, write_mode);
			file_close(out_file);
			
		elsif w_en = '1' then
			p_nr := p_nr + 1;
			
			for i in 0 to segments-1 loop
				value_vec := data((i+1)*seg_width-1 downto i*seg_width);
				if (sign = true) then
					value_int := to_integer(signed(value_vec));
				else
					value_int := to_integer(unsigned(value_vec));
				end if;
				write(values, value_int);
				write(values, ',');
			end loop;
		
		elsif eol = '1' and p_nr /= 0 then
			l_nr := l_nr + 1;
			p_nr := 0;		

			deallocate(filename);
			write(filename, basename & "_" & integer'image(f_nr) & ".csv");
			
			file_open(out_file, filename.all, append_mode);
			writeline(out_file, values);
			file_close(out_file);
		
		elsif eof = '1' and l_nr /= 0 then	-- Prevent multiple files in case of long eof-pulse
			f_nr := f_nr + 1;
			l_nr := 0;
			p_nr := 0;
		
			deallocate(filename);
			write(filename, basename & "_" & integer'image(f_nr) & ".csv");

			file_open(out_file, filename.all, write_mode);
			file_close(out_file);
		
		end if;
	end if;
end procedure;

procedure save2image(
    signal clk 			: in std_logic;
	signal reset 		: in std_logic;
	signal w_en 		: in std_logic;
	signal data 		: in std_logic_vector;
	signal eof			: in std_logic;
	
	constant basename	: string;
	constant width		: integer;
	constant height		: integer;
	constant segments 	: integer;
	constant seg_width	: integer;
	constant scale_to	: natural;
	constant offset		: natural;
	
	variable frame		: inout integer;
	variable row		: inout integer;
	variable col		: inout integer;
	variable max		: inout integer;
	variable pixel		: inout scanline_tp
) is
	FILE out_file       : text;
	variable filename	: line;
	variable max_val	: integer;
	variable value_str	: line;
	variable value_int	: integer;
	variable value_vec	: std_logic_vector(seg_width-1 downto 0);
	variable buf		: line;
	variable value_flt	: real;
	variable factor		: real;
begin
	if rising_edge(clk) then
		if reset = '1' then
			frame := 0;
			row := 0;
			col := 0;
			max := 0;
			
			if (scale_to = 0) then max_val := (2**seg_width)-1; else max_val := scale_to; end if;
			
			deallocate(pixel);
			pixel := new scanline_t(0 to width-1);
			
			deallocate(filename);
			write(filename, basename & "_" & integer'image(frame) & ".pgm");
			
			-- Empty the file & write header
			file_open(out_file, filename.all, write_mode);
			deallocate(buf);
			write(buf, "P2" & LF & integer'image(width) & LF & integer'image(height) & LF & integer'image(max_val) & LF);
			writeline(out_file, buf);
			file_close(out_file);
					
		elsif w_en = '1' then
			for i in 0 to segments-1 loop
				value_vec := data((i+1)*seg_width-1 downto i*seg_width);
				
				if (offset /= 0) then
					value_int := to_integer(signed(value_vec)) + offset;
				else
					value_int := to_integer(unsigned(value_vec));
				end if;
						
				pixel(col) := value_int;
				
				if (value_int > max) then
					max := value_int;
				end if;
				
				col := col + 1;
			end loop;
			 
			if (col = width) then
				if (scale_to /= 0) then
					if (max > 0) then	factor := real(scale_to) / real(max); else factor := 0.0; end if;
				else
					factor := 1.0;
				end if; 
			
				write(filename, basename & "_" & integer'image(frame) & ".pgm");
				file_open(out_file, filename.all, append_mode);
				deallocate(buf);
				write(buf, "# Line " & integer'image(row) & " Max: " & integer'image(max) & " Factor: " & real'image(factor));
				writeline(out_file, buf);
				
				for i in 0 to width-1 loop
					value_flt := real(pixel(i)) * factor;
					write(buf, integer'image(integer(floor(value_flt))), right, 4);
					write(buf, ' ');
					
					if ((i+1) mod 16 = 0) then
						write(buf, LF);
					end if;
				end loop;
				writeline(out_file, buf);
				
				row := row + 1;
				col := 0;
				max := 0;
				
				file_close(out_file);
			end if;
			
		elsif eof = '1' and row /= 0 then	-- Prevent multiple files in case of long eof-pulse
			frame := frame + 1;
			row := 0;
			col := 0;
			max := 0;
			
			if (scale_to = 0) then max_val := (2**seg_width)-1; else max_val := scale_to; end if;
			
			deallocate(filename);
			write(filename, basename & "_" & integer'image(frame) & ".pgm");
			
			-- Empty the file & write header
			file_open(out_file, filename.all, write_mode);
			deallocate(buf);
			write(buf, "P2" & LF & integer'image(width) & LF & integer'image(height) & LF & integer'image(max_val) & LF);
			writeline(out_file, buf);
			file_close(out_file);
			
		end if;	
	
	end if;
end procedure;

impure function loadPGM(filename: string) return image_tp
is
	file pgmfile           : text;
	variable width, height : natural;                     	-- storage for image dimensions
	variable l             : line;                          -- buffer for a line of text
	variable s             : string(1 to 2);                -- to check the P2 header
	variable ints          : integer_vector(1 to 3);        -- store the first three integers (width, height and depth)
	variable int           : integer;                       -- temporary storage
	variable ch            : character;                     -- temporary storage
	variable good          : boolean;                       -- to record whether a read is successful or not
	variable count         : positive;                      -- keep track of how many numbers we've read
	variable empty_image   : image_tp := null;       	 	-- return this on error
	variable ret           : image_tp;                		-- actual return value
	variable x, y          : natural;                   	-- coordinate tracking
begin  -- function pgm_read
	-- setup some defaults
	width  := 0;
	height := 0;

	file_open(pgmfile, filename, read_mode);
	readline(pgmfile, l);
	read(l, s(1));
	read(l, s(2), good);

	if not good or s /= "P2" then
		report "PGM file '"&filename&"' not P2 type" severity warning;
		file_close(pgmfile);
		return empty_image;
	end if;
	
	allints : loop  			-- read until we have 3 integers (width, height and max value).  
		line_reading : loop
			readline(pgmfile, l);
			exit when l.all(1) = '#';                        -- skip comments;
			if l'length = 0 then
				report "EOF reached in pgmfile before opening integers found" severity warning;
				file_close(pgmfile);
				return empty_image;
			end if;
			number_reading : loop
				read(l, ints(count), good);
				exit number_reading when not good;
				count := count + 1;
				exit allints        when count > ints'high;
			end loop;
		end loop;
		exit when count > ints'high;
	end loop;
	  
	width  := ints(1);
	height := ints(2);
	
	x      := 0;
	y      := 0;
	ret    := new image_t(0 to width-1, 0 to height-1);
	
	allpixels : loop
		readline(pgmfile, l);
		exit when l = null;
		exit when l'length = 0;
		loop
			read(l, int, good);
			exit           when not good;
			ret(x, y) := int;
			exit allpixels when x = width-1 and y = height-1;
			x         := x + 1;
			if x >= width then
				x := 0;
				y := y + 1;
			end if;
		end loop;
	end loop allpixels;
	
	assert (x = width-1 and y = height-1)
		report "Don't seem to have read all the pixels I should have"
		severity warning;
		
	log("Loaded " & filename);
		
	return ret;
	
end function;

function switch(c : boolean; t : integer; f : integer) return integer is
begin
	if (c = true) then
		return t;
	else
		return f;
	end if;
end function;

function switch(c : boolean; t : real; f : real) return real is
begin
	if (c = true) then
		return t;
	else
		return f;
	end if;
end function;

function switch(c : boolean; t : string; f : string) return string is
begin
	if (c = true) then
		return t;
	else
		return f;
	end if;
end function;

function switch(c : boolean; t : std_logic_vector; f : std_logic_vector) return std_logic_vector is
begin
	if (c = true) then
		return t;
	else
		return f;
	end if;
end function;

function switch(c : boolean; t : bit_vector; f : bit_vector) return bit_vector is
begin
	if (c = true) then
		return t;
	else
		return f;
	end if;
end function;

function switch(c : boolean; t : integer_vector; f : integer_vector) return integer_vector is
begin
	if (c = true) then
		return t;
	else
		return f;
	end if;
end function;

function switch(c : boolean; t : std_logic; f : std_logic) return std_logic is
begin
	if (c = true) then
		return t;
	else
		return f;
	end if;
end function;

function switch(c : boolean; t : character; f : character) return character is
begin
	if (c = true) then
		return t;
	else
		return f;
	end if;
end function;

procedure log(msg: string) is
begin
	--report format_time(now, "us") & " : " & msg severity note;
	assert false report msg severity note;
end procedure;

procedure pulse(idle: std_logic; mark: std_logic; len: time; signal sig : out std_logic) is
begin
	sig <= mark;
	wait for len;
	sig <= idle;
end procedure pulse;

procedure clock(MHz : real; offset : time := 0 ns; signal clk : out std_logic) is
begin
	clk <= '0';
	wait for 1.0us / MHz;
	wait for offset;
	loop
		wait for 0.5us / MHz;
		clk <= '0';
		wait for 0.5us / MHz;
		clk <= '1';
	end loop;
end procedure clock;

procedure clock_diff(MHz : real; offset : time := 0 ns; signal clk_p, clk_n : out std_logic) is
begin
	clk_p <= '0';
	clk_n <= '1';
	wait for 1.0us / MHz;
	wait for offset;
	loop
		wait for 0.5us / MHz;
		clk_p <= '0';
		clk_n <= '1';
		wait for 0.5us / MHz;
		clk_p <= '1';
		clk_n <= '0';
	end loop;
end procedure clock_diff;

pure function pad(l : integer; v: std_logic_vector) return std_logic_vector
is
	variable h : integer := v'length;
	variable padded : std_logic_vector(abs(l)-1 downto 0) := (others => '0');
begin
	if (abs(l) <= h) then
		return v;
	end if;

	if (0 < l) then
		padded(h-1 downto 0) := v(v'high downto v'low);				-- Pad left
	elsif (l < 0) then
		padded(abs(l)-1 downto abs(l)-h) := v(v'high downto v'low);	-- Pad right
	end if;
	
	return padded;
end function;

pure function pad(l : integer; v: std_logic) return std_logic_vector
is
	variable vv : std_logic_vector(0 downto 0) := (0 => v);
begin
	return pad(l, vv);
end function;

pure function pad(l : integer; v: unsigned) return unsigned
is
	variable h : integer := v'length;
	variable padded : unsigned(abs(l)-1 downto 0) := (others => '0');
begin
	if (abs(l) <= h) then
		return v;
	end if;

	if (l > 0) then
		padded(h-1 downto 0) := v(v'high downto v'low);				-- Pad left
	elsif (l < 0) then
		padded(abs(l)-1 downto abs(l)-h) := v(v'high downto v'low);	-- Pad right
	end if;
	
	return padded;
end function;

function fill(width : natural; v : std_logic) return std_logic_vector
is
	variable Z : std_logic_vector(width-1 downto 0) := (others => v);
begin
	return Z;
end function;

function fill(width : natural; v : std_logic_vector) return std_logic_vector
is
	variable l : integer := v'length;
	variable Z : std_logic_vector(width-1 downto 0) := (others => '0');
begin
	assert width mod v'length = 0 report "fill: Width of result must be evenly divisible by length of fillpattern." severity failure;
	
	for i in 0 to (width / l)-1 loop
		Z((i+1)*l-1 downto i*l) := v;
	end loop;
	
	return Z;
end function;
				
function calc_oversample(clk_freq : integer; baudrate : integer) return integer is
	variable result : real;
	variable remainder : real;
	variable minimum : real := 1.0;
	variable oversample : integer := 16;
	variable divider : integer;
begin

for os in 16 downto 8 loop
	result := real(clk_freq) / (real(baudrate) * real(os));
	remainder := abs(result - round(result));
	
	if (remainder < minimum) then
		minimum := remainder;
		oversample := os;
	end if;
end loop; 

log("UART Oversampling = " & integer'image(oversample) & " for " & integer'image(baudrate) & "baud at " & integer'image(clk_freq) & "Hz");

divider := integer(round(real(clk_freq) / (real(baudrate) * real(oversample)))) - 1;

log("UART Clock Divider = " & integer'image(divider));

return oversample;

end function calc_oversample;

pure function clogb2(depth : natural) return integer is
begin
	return integer(ceil(log2(real(depth))));
end function;

pure function nibble(vec : std_logic_vector; index : integer) return std_logic_vector is
begin
	return vec((index * 4 + 3) downto (index * 4));
end function;

pure function byte(vec : std_logic_vector; index : integer) return std_logic_vector is
	variable i : std_logic_vector(vec'high downto 0);
	variable r : std_logic_vector(7 downto 0);
begin
	i := vec;
	r := i((index * 8 + 7) downto (index * 8));
	return r;
end function;

pure function zero_resize(v : std_logic_vector; width : natural) return std_logic_vector is
begin
	return std_logic_vector(resize(unsigned(v), width));
end function;

pure function zero_resize_u(v : std_logic_vector; width : natural) return unsigned is
begin
	return resize(unsigned(v), width);
end function;

pure function zero_resize_u(v : unsigned; width : natural) return unsigned is
begin
	return resize(v, width);
end function;

pure function sign_resize(v : std_logic_vector; width : natural) return std_logic_vector is
begin
	return std_logic_vector(resize(signed(v), width));
end function;

pure function sign_resize_s(v : std_logic_vector; width : natural) return signed is
begin
	return resize(signed(v), width);
end function;

pure function sign_resize_s(v : signed; width : natural) return signed is
begin
	return resize(v, width);
end function;

pure function zero_shift_right(v : std_logic_vector; steps : natural) return std_logic_vector is
begin
	return std_logic_vector(shift_right(unsigned(v), steps));
end function;

pure function sign_shift_right(v : std_logic_vector; steps : natural) return std_logic_vector is
begin
	return std_logic_vector(shift_right(signed(v), steps));
end function;

pure function or_reduce(v : std_logic_vector) return std_logic is
begin
	if v /= fill(v'length, '0') then
		return '1';
	else
		return '0';
	end if;
end function;

pure function and_reduce(v : std_logic_vector) return std_logic is
begin
	if v /= fill(v'length, '1') then
		return '0';
	else
		return '1';
	end if;
end function;

pure function bit_reverse(v : std_logic_vector) return std_logic_vector is
	variable r : std_logic_vector(v'high downto v'low);
begin
	for I in 0 to v'high-v'low loop
		r(v'high-I) := v(v'low+I);
	end loop;	
	
	return r;
end function bit_reverse;

pure function byte_reverse(v : std_logic_vector) return std_logic_vector is
	variable r : std_logic_vector(v'high downto v'low);
	variable b : integer;
begin
	assert v'length mod 8 = 0 report "Vector length must be a multiple of 8 for byte_reverse()" severity error;

	b := v'length/8;
	
	for I in 0 to b-1 loop
		r(v'high - (I*8) downto v'high - ((I+1)*8)+1) := v(v'low + ((I+1)*8)-1 downto v'low + I*8);
	end loop;	
	
	return r;
end function byte_reverse;

pure function word_reverse(v: std_logic_vector) return std_logic_vector is
	variable r : std_logic_vector(v'high downto v'low);
variable b : integer;
begin
	assert v'length mod 16 = 0 report "Vector length must be a multiple of 16 for word_reverse()" severity error;
	
	b := v'length/16;
	
	for I in 0 to b-1 loop
		r(v'high - (I*16) downto v'high - ((I+1)*16)+1) := v(v'low + ((I+1)*16)-1 downto v'low + I*16);
	end loop;	
	
	return r;
end function word_reverse;

function ip2vec(f0, f1, f2, f3 : integer range 0 to 255) return std_logic_vector is
	variable vec : std_logic_vector(31 downto 0);
begin
	vec( 7 downto  0) := int2vec(f0, 8);
	vec(15 downto  8) := int2vec(f1, 8);
	vec(23 downto 16) := int2vec(f2, 8);
	vec(31 downto 24) := int2vec(f3, 8);

	return vec;
end function ip2vec;

function mac2vec(m0, m1, m2, m3, m4, m5 : std_logic_vector(7 downto 0)) return std_logic_vector is
	variable vec : std_logic_vector(47 downto 0);
begin
	vec( 7 downto  0) := m0;
	vec(15 downto  8) := m1;
	vec(23 downto 16) := m2;
	vec(31 downto 24) := m3;
	vec(39 downto 32) := m4;
	vec(47 downto 40) := m5;

	return vec;
end function mac2vec;

function real2fixed(r : real; l, u : integer) return std_logic_vector is
	variable i : integer;
begin
	i := integer(round(r * real(2**u)));
	return std_logic_vector(to_signed(i, l));
end function real2fixed;

function time2clks(t : time; f : integer) return integer is
	variable p : time;
	variable c : integer;
begin
	p := (1000000000.0 / real(f)) * 1 ns;
	c := integer(round(real(t / p)));

	return c;
end function time2clks;

function char2vec(c : character) return std_logic_vector is
begin
	return std_logic_vector(to_unsigned(character'pos(c), 8));
end function char2vec;

function char2vec(c : character; l : integer) return std_logic_vector is
begin
	return std_logic_vector(to_unsigned(character'pos(c), l));
end function char2vec;

function str2vec(s : string) return std_logic_vector is
	variable v : std_logic_vector(s'length*8-1 downto 0);
begin
--	for I in 1 to s'length loop
--		v(I*8-1 downto (I-1)*8) := char2vec(s(I));
--	end loop;	
	
	for I in 0 to s'length-1 loop
		v((I+1)*8-1 downto (I)*8) := char2vec(s(s'length-I));
	end loop;	

	return v;
end function str2vec;

function vec2str(v: std_logic_vector) return string is
begin
	return integer'image(vec2int(v));
end function;

function svec2str(v: std_logic_vector) return string is
begin
	return integer'image(svec2int(v));
end function;

function vec2hex(v: std_logic_vector) return string is
	variable L : LINE;
begin
	hwrite(L, v);
	return L.all;
end function;

function str2bytes(s: string) return array8_t is
	variable bytes : array8_t(0 to s'length-1) := (others => x"00");
begin
	for I in 0 to s'length-1 loop
		bytes(I) := char2vec(s(I+1));
	end loop;	
	
	return bytes;
end function;

function bit2vec(b: std_logic; l : integer) return std_logic_vector is
	variable v : std_logic_vector(l-1 downto 0);
begin
	v := (others => b);
	return v;
end function bit2vec;

function vec2int(v : std_logic_vector) return integer is
begin
	return to_integer(unsigned(v));
end function vec2int;

function bool2bit(b: boolean) return std_logic is
begin
	if b = true then
		return '1';
	else
		return '0';
	end if;	
end function bool2bit;

function bool2bit(b: boolean_vector) return std_logic_vector is
variable v : std_logic_vector(b'high downto b'low) := (others => '0');
begin
	for i in b'low to b'high loop
		v(i) := '1' when b(i) = true else '0';
	end loop;
	
	return v;
end function bool2bit;

function svec2int(v : std_logic_vector) return integer is
begin
	return to_integer(signed(v));
end function svec2int;

function vec2int(v : std_logic) return integer is
begin
	if v = '1' then
		return 1;
	else
		return 0;
	end if;
end function vec2int;

function int2vec(i : integer; l : integer) return std_logic_vector is
begin
	return std_logic_vector(to_unsigned(i, l));
end function int2vec;

function sint2vec(i : integer; l : integer) return std_logic_vector is
begin
	return std_logic_vector(to_signed(i, l));
end function sint2vec;

function int2signed(i: integer; l : integer) return signed is
begin
	return to_signed(i, l);
end function int2signed;

function inc(v : std_logic_vector) return std_logic_vector is
begin
	return int2vec(vec2int(v) + 1, v'length);
end function inc;

function dec(v : std_logic_vector) return std_logic_vector is
begin
	return int2vec(vec2int(v) - 1, v'length);
end function dec;

pure function qabs(v: std_logic_vector) return std_logic_vector is
begin
	return '0' & (v(v'high-1 downto v'low) XOR fill(v'length-1, v(v'high)));
end function qabs;

function add(v : std_logic_vector; i : integer) return std_logic_vector is
begin
	return int2vec(vec2int(v) + i, v'length);
end function add;

function add(v : std_logic_vector; i : integer; l : integer) return std_logic_vector is
begin
	return int2vec(vec2int(v) + i, l);
end function add;

function add(v1 : std_logic_vector; v2 : std_logic_vector) return std_logic_vector is
begin
	return int2vec(vec2int(v1) + vec2int(v2), max(v1'length, v2'length));
end function add;

function sub(v : std_logic_vector; i : integer) return std_logic_vector is
begin
	return int2vec(vec2int(v) - i, v'length);
end function sub;

function sub(v1 : std_logic_vector; v2 : std_logic_vector) return std_logic_vector is
begin
	return int2vec(vec2int(v1) - vec2int(v2), max(v1'length, v2'length));
end function sub;

function sub(v : std_logic_vector; i : integer; l : integer) return std_logic_vector is
begin
	return int2vec(vec2int(v) - i, l);
end function sub;

impure function random_int(min, max : integer) return integer is
	variable r : real;
begin
	uniform(RAND_SEED1, RAND_SEED2, r);
	return integer(round(r * real(max - min + 1) + real(min) - 0.5));
end function random_int;

impure function random_real(min, max : real) return real is
	variable r : real;
begin
	uniform(RAND_SEED1, RAND_SEED2, r);
	return r * (max - min) + min;
end function random_real;

impure function random_vec(min, max : integer; l : integer) return std_logic_vector is
begin
 	return int2vec(random_int(min, max), l);
end function random_vec;

impure function random_bit return std_logic is
	variable r : real;
	variable result : std_logic := '0';
begin
	uniform(RAND_SEED1, RAND_SEED2, r);
	
    result :=  '1' when r > 0.5 else '0';
    
    return result;
end function random_bit;

impure function random_time(min, max : time; unit : time := ns) return time is
  variable r, r_scaled, min_real, max_real : real;
begin
	uniform(RAND_SEED1, RAND_SEED2, r);
	
	min_real := real(min / unit);
	max_real := real(max / unit);
	r_scaled := r * (max_real - min_real) + min_real;
	
	return real(r_scaled) * unit;
end function;

pure function bits(n : integer) return integer is
begin
	return integer(ceil(log2(real(n))));
end bits;

pure function ispowerof2(n : integer) return boolean is
variable v,v1,z : std_logic_vector(bits(n)-1 downto 0);
begin
	v  := int2vec(n  , bits(n));
	v1 := int2vec(n-1, bits(n));
	z  := int2vec(0  , bits(n));
	
	if (v AND v1) = z then
		return true;
	else
		return false;
	end if;
end ispowerof2;

pure function count(v : std_logic_vector) return integer is
	variable c : integer := 0;
begin
	for i in v'range loop
		if v(i) = '1' then
			c := c + 1;
		end if;
	end loop;
	
	return c;
end count;

pure function sum(v : integer_vector) return integer is
variable s : integer := 0;
begin
	for i in 0 to v'length-1 loop
		s := s + v(v'left + i);
	end loop;
	
	return s;
end sum;

pure function sum(v : integer_vector; upto: integer) return integer is
variable s : integer := 0;
begin
	if upto < 0 then
		return 0;
	end if;
		
	for i in 0 to min(upto, v'length-1) loop
		s := s + v(v'left + i);
	end loop;
	
	return s;
end sum;

function max(l, r: integer) return integer is
begin
	if l > r then
		return l;
	else
		return r;
	end if;
end;

function min(l, r: integer) return integer is
begin
	if l < r then
		return l;
	else
		return r;
	end if;
end;

procedure readUntilSep(l : inout line; sep : in character; value : inout line) is
	variable return_string : string(1 to LINE_LENGTH_MAX);
	variable read_char : character;
	variable read_ok : boolean := true;
	variable index : integer := 1;
begin
	read(l, read_char, read_ok);

	while read_ok loop
		if (read_char = sep) OR (read_char = character'val(0)) then
			write(value, return_string);
			return;
		else
			return_string(index) := read_char;
			index := index + 1;
		end if;
		
		read(l, read_char, read_ok);
	end loop;
	
	write(value, return_string);
	return;
end procedure readUntilSep;

function str2int(x_str : string; radix : positive range 2 to 36 := 10) return integer is
    constant STR_LEN          : integer := x_str'length;
    
    variable chr_val          : integer;
    variable ret_int          : integer := 0;
    variable do_mult          : boolean := true;
    variable power            : integer := 0;
begin

for i in STR_LEN downto 1 loop
  case x_str(i) is
	when '0'       =>   chr_val := 0;
	when '1'       =>   chr_val := 1;
	when '2'       =>   chr_val := 2;
	when '3'       =>   chr_val := 3;
	when '4'       =>   chr_val := 4;
	when '5'       =>   chr_val := 5;
	when '6'       =>   chr_val := 6;
	when '7'       =>   chr_val := 7;
	when '8'       =>   chr_val := 8;
	when '9'       =>   chr_val := 9;
	when 'A' | 'a' =>   chr_val := 10;
	when 'B' | 'b' =>   chr_val := 11;
	when 'C' | 'c' =>   chr_val := 12;
	when 'D' | 'd' =>   chr_val := 13;
	when 'E' | 'e' =>   chr_val := 14;
	when 'F' | 'f' =>   chr_val := 15;
	when 'G' | 'g' =>   chr_val := 16;
	when 'H' | 'h' =>   chr_val := 17;
	when 'I' | 'i' =>   chr_val := 18;
	when 'J' | 'j' =>   chr_val := 19;
	when 'K' | 'k' =>   chr_val := 20;
	when 'L' | 'l' =>   chr_val := 21;
	when 'M' | 'm' =>   chr_val := 22;
	when 'N' | 'n' =>   chr_val := 23;
	when 'O' | 'o' =>   chr_val := 24;
	when 'P' | 'p' =>   chr_val := 25;
	when 'Q' | 'q' =>   chr_val := 26;
	when 'R' | 'r' =>   chr_val := 27;
	when 'S' | 's' =>   chr_val := 28;
	when 'T' | 't' =>   chr_val := 29;
	when 'U' | 'u' =>   chr_val := 30;
	when 'V' | 'v' =>   chr_val := 31;
	when 'W' | 'w' =>   chr_val := 32;
	when 'X' | 'x' =>   chr_val := 33;
	when 'Y' | 'y' =>   chr_val := 34;
	when 'Z' | 'z' =>   chr_val := 35;                           
	when '-' =>   
	  if i /= 1 then
		report "Minus sign must be at the front of the string" severity failure;
	  else
		ret_int           := 0 - ret_int;
		chr_val           := 0;
		do_mult           := false;    --Minus sign - do not do any number manipulation
	  end if;
				 
	when others => report "Illegal character for conversion from string to integer" severity failure;
  end case;
  
  if chr_val >= radix then report "Illegal character at this radix" severity failure; end if;
	
  if do_mult then
	ret_int               := ret_int + (chr_val * (radix**power));
  end if;
	
  power                   := power + 1;
	  
end loop;

return ret_int;

end function;

end Util;