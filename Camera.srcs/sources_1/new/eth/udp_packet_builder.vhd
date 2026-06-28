library IEEE, UNISIM, UNIMACRO;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.vcomponents.all;
use UNIMACRO.vcomponents.all;
use Work.util.all;

-- Packet Format
-- [	2 bytes Meta Length 				]
-- [	x bytes Meta Data	 				]
-- [	2 bytes Image Length(incl. Map)		]
-- [	2 bytes Image Map Length			]
-- [	x bytes Image Map					]
-- [	x bytes Image Data					]

entity udp_packet_builder is
	generic (
		LENGTH			: integer	:= 16384;
		WIDTH			: integer	:= 8;
		IMG_DELAY		: integer	:= 2
	);
	port (
		-- system signals
		CLK_I			: in	std_logic;
		RESET_I			: in	std_logic;
	
		EMPTY_O			: out	std_logic := '1';
		CLEAR_I			: in	std_logic := '0';
		FLUSH_I			: in	std_logic := '0';
		FORCE_SEND_I	: in	std_logic := '0';
		ACCEPT_O		: out	std_logic := '0';
		
		ONLY_META_I		: in	std_logic := '0';
	
		-- Internal Interface
		IMG_AVAIL_I		: in	std_logic;
		IMG_DONE_O		: out	std_logic := '0';
		IMG_ADDR_O		: out	std_logic_vector(15 downto 0);
		IMG_EOF_I		: in	std_logic;
		IMG_DATA_I		: in	std_logic_vector( 7 downto 0) := (others => '0');
		IMG_LEN_I		: in	std_logic_vector(15 downto 0);
		IMG_MAP_LEN_I	: in	std_logic_vector(15 downto 0);

		META_AVAIL_I	: in	std_logic;
		META_LEN_I		: in	std_logic_vector(15 downto 0);
		META_DV_I		: in	std_logic;
		META_READ_O		: out	std_logic := '0';
		META_DATA_I		: in	std_logic_vector( 7 downto 0);

		-- Output
		OUT_AVAIL_O		: out	std_logic := '0';
		OUT_EOF_O		: out	std_logic := '0';
		OUT_DONE_I		: in	std_logic;
		OUT_READ_I		: in	std_logic;
		OUT_DATA_O		: out	std_logic_vector(WIDTH-1 downto 0) := (others => '0');
		OUT_FRAME_O	 	: out	std_logic_vector(WIDTH-1 downto 0) := (others => '0');
		OUT_SIZE_O		: out	std_logic_vector(clogb2(LENGTH)-1 downto 0) := (others => '0');
		
		OUT_LIMIT_I		: in	std_logic_vector(clogb2(LENGTH)-1 downto 0)
	);
end udp_packet_builder;

architecture Behavioral of udp_packet_builder is

constant ADDR_WIDTH		: integer := clogb2(LENGTH);	-- 16384	->  14bit

signal no_meta			: std_logic := '0';
signal no_img			: std_logic := '0';
signal only_meta		: std_logic := '0';

signal clear_rx			: std_logic := '0';
signal clear_tx			: std_logic := '0';
signal fifo_reset		: std_logic_vector(5 downto 0) := "111110";

signal fifo_empty		: std_logic_vector(2 downto 0);
signal fifo_full		: std_logic_vector(3 downto 1);
type data_array_t		is array(natural range <>) of std_logic_vector(WIDTH-1 downto 0);
signal fifo_do			: data_array_t(2 downto 0);

signal flush			: std_logic := '0';

signal force_send		: std_logic := '0';
signal force_send_r		: std_logic := '0';

--constant IMG_DELAY		: integer := 2;
signal img_last			: std_logic_vector(IMG_DELAY-1 downto 0) := (others => '0');
signal img_read			: std_logic_vector(IMG_DELAY-1 downto 0) := (others => '0');
signal img_addr			: std_logic_vector(15 downto 0) := (others => '0');

constant META_DELAY		: integer := 2;
signal meta_last		: std_logic_vector(META_DELAY-1 downto 0) := (others => '0');
signal meta_read		: std_logic_vector(META_DELAY-1 downto 0) := (others => '0');
signal meta_addr		: std_logic_vector(15 downto 0) := (others => '0');

signal accept			: std_logic := '0';
signal in_full			: std_logic := '0';
signal in_write			: std_logic := '0';
signal in_data			: std_logic_vector(WIDTH-1 downto 0) := (others => '0');
signal in_size			: std_logic_vector(ADDR_WIDTH-1 downto 0):= (others => '0');
signal frames			: std_logic_vector(WIDTH-1 downto 0) := (others => '0');

signal last_size		: std_logic_vector(ADDR_WIDTH-1 downto 0):= (others => '0');
signal size				: std_logic_vector(ADDR_WIDTH-1 downto 0):= (others => '0');

signal last_size_r		: std_logic_vector(ADDR_WIDTH-1 downto 0):= (others => '0');
signal size_r			: std_logic_vector(ADDR_WIDTH-1 downto 0):= (others => '0');

signal last_frames		: std_logic_vector(WIDTH-1  downto 0) := (others => '0');
signal last_frames_r	: std_logic_vector(WIDTH-1  downto 0) := (others => '0');

signal rx_end			: std_logic := '0';
signal ready			: std_logic := '0';
signal send				: std_logic := '0';
signal tx_start			: std_logic := '0';
signal tx_started		: std_logic := '0';
signal tx_flag			: std_logic := '0';

signal out_read			: std_logic := '0';
signal out_empty		: std_logic := '0';
signal out_size			: std_logic_vector(ADDR_WIDTH-1 downto 0):= (others => '0');

signal img_map_len		: std_logic_vector(15 downto 0) := (others => '0');
signal img_len          : std_logic_vector(15 downto 0) := (others => '0');
signal meta_len			: std_logic_vector(15 downto 0) := (others => '0');

signal test				: std_logic_vector(2 downto 0);

type state_t is (
S_PREIDLE,				-- 0
S_IDLE,					-- 1 
S_META_SIZE_HI,			-- 2 
S_META_SIZE_LO,			-- 3
S_META_DATA,			-- 4
S_IMAGE_SIZE_LO,		-- 5
S_IMAGE_SIZE_HI,		-- 6
S_IMAGE_MAPSIZE_HI,		-- 7
S_IMAGE_MAPSIZE_LO,		-- 8
S_IMAGE_DATA,			-- 9
S_SIZE,					-- A
S_END					-- B
);

signal state			: state_t := S_IDLE;

type tx_state_t is (
S_IDLE,
S_READY,
S_READ
);

signal tx_state			: tx_state_t := S_IDLE;


begin


FIFO_0 : FIFO_DUALCLOCK_MACRO	-- 4096Bytes
generic map (
	DEVICE 				=> "7SERIES", 
	ALMOST_FULL_OFFSET	=> X"0080",
	ALMOST_EMPTY_OFFSET	=> X"0080",
	DATA_WIDTH			=> WIDTH,
	FIFO_SIZE			=> "36Kb", 
	FIRST_WORD_FALL_THROUGH => TRUE
)
port map (
	RST			=> fifo_reset(fifo_reset'high),

	WRCLK		=> CLK_I,
	WREN		=> in_write,
	ALMOSTFULL	=> open,
	WRCOUNT		=> open,
	WRERR		=> open,
	FULL		=> in_full,
	DI			=> in_data,

	RDCLK		=> CLK_I,
	RDEN		=> NOT(fifo_empty(0) OR fifo_full(1) OR fifo_reset(fifo_reset'high)),
	ALMOSTEMPTY	=> open,
	RDCOUNT		=> open,
	RDERR		=> open,
	EMPTY		=> fifo_empty(0),
	DO			=> fifo_do(0)
);

FIFO_1 : FIFO_DUALCLOCK_MACRO	-- 4096Bytes
generic map (
	DEVICE 				=> "7SERIES", 
	ALMOST_FULL_OFFSET	=> X"0080",
	ALMOST_EMPTY_OFFSET	=> X"0080",
	DATA_WIDTH			=> 8,
	FIFO_SIZE			=> "36Kb", 
	FIRST_WORD_FALL_THROUGH => TRUE
)
port map (
	RST			=> fifo_reset(fifo_reset'high),

	WRCLK		=> CLK_I,
	WREN		=> NOT(fifo_empty(0) OR fifo_full(1) OR fifo_reset(fifo_reset'high)),
	ALMOSTFULL	=> open,
	WRCOUNT		=> open,
	WRERR		=> open,
	FULL		=> fifo_full(1),
	DI			=> fifo_do(0),

	RDCLK		=> CLK_I,
	RDEN		=> NOT(fifo_empty(1) OR fifo_full(2) OR fifo_reset(fifo_reset'high)),
	ALMOSTEMPTY	=> open,
	RDCOUNT		=> open,
	RDERR		=> open,
	EMPTY		=> fifo_empty(1),
	DO			=> fifo_do(1)
);

FIFO_2 : FIFO_DUALCLOCK_MACRO	-- 4096Bytes
generic map (
	DEVICE 				=> "7SERIES", 
	ALMOST_FULL_OFFSET	=> X"0080",
	ALMOST_EMPTY_OFFSET	=> X"0080",
	DATA_WIDTH			=> 8,
	FIFO_SIZE			=> "36Kb", 
	FIRST_WORD_FALL_THROUGH => TRUE
)
port map (
	RST			=> fifo_reset(fifo_reset'high),

	WRCLK		=> CLK_I,
	WREN		=> NOT(fifo_empty(1) OR fifo_full(2) OR fifo_reset(fifo_reset'high)),
	ALMOSTFULL	=> open,
	WRCOUNT		=> open,
	WRERR		=> open,
	FULL		=> fifo_full(2),
	DI			=> fifo_do(1),

	RDCLK		=> CLK_I,
	RDEN		=> NOT(fifo_empty(2) OR fifo_full(3) OR fifo_reset(fifo_reset'high)),
	ALMOSTEMPTY	=> open,
	RDCOUNT		=> open,
	RDERR		=> open,
	EMPTY		=> fifo_empty(2),
	DO			=> fifo_do(2)
);

FIFO_3 : FIFO_DUALCLOCK_MACRO	-- 4096Bytes
generic map (
	DEVICE 				=> "7SERIES", 
	ALMOST_FULL_OFFSET	=> X"0080",
	ALMOST_EMPTY_OFFSET	=> X"0080",
	DATA_WIDTH			=> 8,
	FIFO_SIZE			=> "36Kb", 
	FIRST_WORD_FALL_THROUGH => FALSE
)
port map (
	RST			=> fifo_reset(fifo_reset'high),

	WRCLK		=> CLK_I,
	WREN		=> NOT(fifo_empty(2) OR fifo_full(3) OR fifo_reset(fifo_reset'high)),
	ALMOSTFULL	=> open,
	WRCOUNT		=> open,
	WRERR		=> open,
	FULL		=> fifo_full(3),
	DI			=> fifo_do(2),

	RDCLK		=> CLK_I,
	RDEN		=> out_read AND OUT_READ_I,
	ALMOSTEMPTY	=> open,
	RDCOUNT		=> open,
	RDERR		=> open,
	EMPTY		=> out_empty,
	DO			=> OUT_DATA_O
);


IMG_ADDR_O		<= img_addr;
ACCEPT_O		<= accept;

build : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			state		<= S_IDLE;
			in_size		<= (others => '0');
			size		<= (others => '0');
			frames		<= (others => '0');
			fifo_reset	<= "111110";
		end if;
--		else
			in_write	<= '0';
			rx_end		<= '0';
			IMG_DONE_O	<= '0';
			
			if (fifo_reset(fifo_reset'high) = '1') then
				fifo_reset(fifo_reset'high downto 1) <= fifo_reset(fifo_reset'high-1 downto 0);
			end if; 
			
			-- CLEAR_I Handling after case
			
			if (tx_start = '1') then
				tx_started <= '1';
			end if;
						
			case (state) is
			when S_PREIDLE =>
				fifo_reset	<= "111110";
				clear_rx	<= '0';
				size		<= (others => '0');
				frames		<= (others => '0');
				
				if (CLEAR_I = '0') then
					state <= S_IDLE;
				end if;
				
			when S_IDLE =>
				only_meta	<= ONLY_META_I;
				--force_send	<= FORCE_SEND_I;
				meta_len	<= META_LEN_I;
				
				no_meta		<= NOT or_reduce(META_LEN_I); -- 0 if not zero, 1 if zero	
				no_img		<= (NOT or_reduce(IMG_LEN_I)) OR ONLY_META_I; -- 0 if not zero, 1 of zero or OnlyMeta

				if (ONLY_META_I = '0') then
					img_len		<= IMG_LEN_I;
					img_map_len <= IMG_MAP_LEN_I;
				else
					img_len		<= (others => '0');
					img_map_len <= (others => '0');
				end if;
			
				if (clear_rx = '1') AND (tx_state = S_IDLE) then
					state <= S_PREIDLE;	
				end if;
			
				if tx_started = '1' then
					tx_started  <= '0';
					size 		<= sub(size, last_size_r);		-- Subtract size that is transmitted
					frames		<= sub(frames, last_frames_r);	-- Subtract frames that are submitted
				end if;
			
				if (size > OUT_LIMIT_I) then
					accept <= '0';
				else
					accept <= not in_full;
				end if;
			
				if  (IMG_AVAIL_I = '1')
				AND (META_AVAIL_I = '1')
				AND (accept = '1')
				AND (clear_rx = '0')
				then			
					state <= S_META_SIZE_LO;
				end if;
			
			when S_META_SIZE_LO =>
				in_data		<= meta_len(7 downto 0);
				
				if (in_full = '0') then
					in_write	<= '1';
					state		<= S_META_SIZE_HI;
				end if;
				
			when S_META_SIZE_HI =>
				in_data		<= meta_len(15 downto 8);

				if (in_full = '0') then
					in_write	<= '1';
					
					if (no_meta = '1') then
						state <= S_IMAGE_SIZE_HI;
					else
						state <= S_META_DATA;
					end if;
				end if;
			
			when S_META_DATA =>
				in_data <= META_DATA_I;

				if (in_full = '0') then
					in_write <= META_DV_I;
								
					if (meta_last(max(meta_last'high-1, 0)) = '1') then
						state <= S_IMAGE_SIZE_HI;
					end if;
				end if;
				
			when S_IMAGE_SIZE_HI =>
				in_data	<= img_len(7 downto 0);

				if (in_full = '0') then
					in_write	<= '1';
					state		<= S_IMAGE_SIZE_LO;
				end if;
				
			when S_IMAGE_SIZE_LO =>
				in_data	<= img_len(15 downto 8);
				
				if (in_full = '0') then
					in_write	<= '1';
					state		<= S_IMAGE_MAPSIZE_HI;
				end if;
				
			when S_IMAGE_MAPSIZE_HI =>
				in_data		<= img_map_len(7 downto 0);
				
				if (in_full = '0') then
					in_write	<= '1';
					state		<= S_IMAGE_MAPSIZE_LO;
				end if;
				
			when S_IMAGE_MAPSIZE_LO =>
				in_data		<= img_map_len(15 downto 8);
				
				if (in_full = '0') then
					in_write	<= '1';
					
					if (no_img = '1') then
						state 		<= S_SIZE;
						IMG_DONE_O	<= only_meta; -- Buffer had an Image, but we didn't transmit it
					else
						state <= S_IMAGE_DATA;
					end if;
				end if;	
			
			when S_IMAGE_DATA =>
				in_data		<= IMG_DATA_I;
				
				if (in_full = '0') then
					--in_write	<= '1';
					in_write	<= img_read(img_read'high);
					
					if (img_last(max(img_last'high-1, 0)) = '1') then
						IMG_DONE_O	<= '1';
						state 		<= S_SIZE;
					end if;
				end if;

			when S_SIZE =>
				last_size	<= size;				-- Register new FIFO size for TX
				last_frames	<= frames;				-- Register new last_frames count for TX
				
				if (IMG_AVAIL_I = '0') then
					state		<= S_END;
				end if;
			
			when S_END =>
				frames		<= inc(frames);			-- Increment last_frames Count
				size		<= add(size, in_size);	-- Add last_frames Size to FIFO Size
				in_size 	<= (others => '0');		-- Reset last_frames Size Counter
				rx_end		<= '1';					-- Signal EOF to TX
				state 		<= S_IDLE;
			
			end case;
			
			if (CLEAR_I = '1') then
				clear_rx <= '1';
				
				if in_full = '1' then
					state <= S_PREIDLE;
				end if;
			end if;
			
			if (in_write = '1') then
				in_size <= inc(in_size);			-- Count every byte written to FIFO
			end if;
--		end if;
	end if;
end process;

META_READ_O <= meta_read(0);

addr : process (CLK_I)
begin
	if rising_edge(CLK_I) then
		img_read(0)	 <= '0';
		img_read(img_read'high downto 1)	<= img_read(img_read'high-1 downto 0);
		img_last(img_last'high downto 1)	<= img_last(img_last'high-1 downto 0);
		
		meta_read(0) <= '0';
		meta_read(meta_read'high downto 1)	<= meta_read(meta_read'high-1 downto 0);
		meta_last(meta_last'high downto 1)	<= meta_last(meta_last'high-1 downto 0);
				
		case (state) is
		when S_IDLE | S_END =>
			meta_addr	<= (others => '0');
			img_addr	<= (others => '0');
			meta_last	<= (others => '0');
			img_last	<= (others => '0');
			img_read	<= (others => '0');

		when S_META_DATA =>
			if (in_full = '0') then						 
				if (meta_last(0) = '0') then
					if (meta_addr = meta_len) then
						meta_last(0) <= '1';
					else
						meta_read(0) <= '1';
						
						if (meta_read(meta_read'high) = '1') then
							meta_addr <= inc(meta_addr);
						end if;
					end if;
				end if;
			end if;
				
		when S_IMAGE_MAPSIZE_HI |
			 S_IMAGE_MAPSIZE_LO |
			 S_IMAGE_DATA =>
			if (in_full = '0') then
				if (img_last(0) = '0') then
					if (img_addr = img_len) then
						img_last(0) <= '1';
					else
						img_read(0) <= '1';
						
						img_addr <= inc(img_addr);
					end if;
				end if;
			end if;
		
		when others => NULL;	
		
		end case;

	end if;
end process;

tx : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			tx_state	<= S_IDLE;
			out_read	<= '0';
			out_size	<= (others => '0');
			ready		<= '0';
			send 		<= '0';
			force_send_r	<= '0';
			clear_tx	<= '0';
		end if;
--		else
			tx_start	<= '0';
		
			EMPTY_O <= NOT or_reduce(frames);
			
			if FLUSH_I = '1' then
				flush <= '1';
			end if;
			
			if (FORCE_SEND_I = '1') then
				force_send	<= '1';
			end if;

			if (rx_end = '1') OR (flush = '1') then
				ready 			<= '1';
				force_send_r	<= force_send OR flush;
				force_send		<= '0';
				flush			<= '0';	
				size_r			<= size;
				last_frames_r	<= last_frames;		
				if (last_size = fill(last_size'length, '0')) then -- If limit is smaller than one frame (last_size = 0, size would not shrink)
					last_size_r <= size;
				else
					last_size_r <= last_size;
				end if;
			end if;
			
			if (CLEAR_I = '1') then
				clear_tx	<= '1';
			end if;

			case (tx_state) is
		
			when S_IDLE =>
				OUT_AVAIL_O <= '0';
			
				if (clear_tx = '1') then
					clear_tx 		<= '0';
					size_r			<= (others => '0');
					force_send_r	<= '0';
				else
				
					if (rx_end = '0' AND send = '0') then												-- Wait if RX just ended to get updated size
						if (ready = '1') then															-- Frame received
							if (size_r >= OUT_LIMIT_I) then												-- Size threshold exceeded
								send <= '1';
							else																		-- Size under threshold
								if state = S_IDLE AND													-- RX idle
								   force_send_r = '1' AND frames /= fill(frames'length, '0')			-- Force Flag and Frames > 0
								then
									last_frames_r	<= frames;
									last_size_r 	<= size;
									send 			<= '1';
								end if;
							end if;
						else																			-- No Frame received since last TX
							if state = S_IDLE AND														-- RX idle
							  force_send_r = '1' AND frames /= fill(frames'length, '0')					-- Force Flag and Frames > 0
							then
								last_frames_r	<= frames;
								last_size_r 	<= size;
								size_r			<= size;		
								send 			<= '1';
							end if;
						end if;
					end if;
		  
					if (send = '1') then
						OUT_FRAME_O	<= last_frames_r;
						OUT_SIZE_O	<= last_size_r;						-- Use the last size that fit into the limit
						out_size	<= last_size_r;
						tx_start	<= '1';
						tx_state	<= S_READY;
					end if;
				end if;
				
			when S_READY =>
				OUT_AVAIL_O <= '1';
				out_read	<= '1';	-- Allow reading
				send		<= '0';
				ready		<= '0';
								
				if (OUT_READ_I = '1') then
					tx_state <= S_READ;
				end if;
				
			when S_READ => 
				if (out_size = int2vec(1, ADDR_WIDTH)) then
					out_read	<= '0';
				end if;
				
				if (OUT_DONE_I = '1') then
					if frames = fill(frames'length, '0') then
						force_send_r <= '0';
					end if;
					
					tx_state <= S_IDLE;
				end if;
			
			end case;
			
			if (OUT_READ_I = '1') then
				if (out_size /= int2vec(1, ADDR_WIDTH)) then
					out_size <= dec(out_size);
				end if;
			end if;
			
--		end if;
	end if;
end process;

end architecture;