library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sha1 is
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
--           serial_tx : out  STD_LOGIC;
--           serial_rx : in  STD_LOGIC;
           leds : out  STD_LOGIC_VECTOR (7 downto 0));
end sha1;

architecture Behavioral of sha1 is

	-- These are pre-defined starting places for the A, B, C, D, and E variables
	constant h0 : unsigned(31 downto 0) := "01100111010001010010001100000001";
	constant h1 : unsigned(31 downto 0) := "11101111110011011010101110001001";
	constant h2 : unsigned(31 downto 0) := "10011000101110101101110011111110";
	constant h3 : unsigned(31 downto 0) := "00010000001100100101010001110110";
	constant h4 : unsigned(31 downto 0) := "11000011110100101110000111110000";
	
	-- The text to be hashed.  Must be in ASCII hex!!
	constant text : unsigned(47 downto 0) := x"412054657374";
	
	-- The 512 bit block of data that will be hashed
	signal blk : unsigned(511 downto 0) := (others => '0');
	
	-- Each word is 32 bits
	subtype word is unsigned(31 downto 0);
	-- The 512 bit data will be hashed across 80 32-bit words
	type words_type is array(79 downto 0) of word;
	-- Init all the words to all zeros
	signal words : words_type := (others => (others => '0'));
	
	-- State machine
	--  load = load all of the text into the block of data to be hashed
	--  zero = pad a one to the end of the text
	--  length = append the length of the text (in bits) to the end of the block of data to be hashed
	--  load_words = split the 512 bit data block and split into 16 32-bit words
	--  calculate_words = do the first level hashing to expand the 16 32-bit words into an additional 64 32-bit words
	--  main = the main hashing loop
	--  cleanup = build the 160 bit final hash value
	--  done = infinte loop since everything is finished
	type state_type is (load, zero, length, load_words, calculate_words, main, cleanup, done);
	-- Default the state to load
	signal state : state_type := load;
	-- Will hold the final 160 bit hash
	signal final : unsigned(159 downto 0) := (others => '0');

begin

	
	process(clk, rst)
		-- Keeps track of the current word number in the calculate_words state
		variable calculate_words_stage : integer range 16 to words'high := 16;
		-- A-E are used as intermediary values for the main loop
		variable A : unsigned(31 downto 0) := h0;
		variable B : unsigned(31 downto 0) := h1;
		variable C : unsigned(31 downto 0) := h2;
		variable D : unsigned(31 downto 0) := h3;
		variable E : unsigned(31 downto 0) := h4;
		-- F, K and temp are all intermediary values for hashing
		variable F : unsigned(31 downto 0) := (others => '0');
		variable K : unsigned(31 downto 0) := (others => '0');
		variable temp : unsigned(31 downto 0) := (others => '0');
		-- Keeps track of the current word being worked on in the main state
		variable main_stage : integer range 0 to 79 := 0;
	begin
		if(rst = '1') then
			-- Set all the defaults
			state <= load;
			calculate_words_stage := 16;
			A := h0;
			B := h1;
			C := h2;
			D := h3;
			E := h4;
			F := (others => '0');
			K := (others => '0');
			temp := (others => '0');
			main_stage := 0;
		elsif(rising_edge(clk)) then
			-- state machine
			case state is 
				when load =>
					-- set the start of the block to contain the text to be hashed
					blk(511 downto 511-text'high) <= text;
					state <= zero;
				when zero =>
					-- Append a 1 to the end of the text in the block
					blk(510-text'high) <= '1';
					state <= length;
				when length =>
					-- Set the tail of the block to contain the length of the text in bits
					-- This length should only be 64 bits!
					blk(63 downto 0) <= to_unsigned(text'length, 64);
					state <= load_words;
				when load_words =>
					-- Split blk into 16 32-bit words
					-- This can all be done in one shot (no extra state machine required)
					for i in 0 to 15 loop
						words(i) <= blk(511 - (i * 32) downto 511 - (i * 32) - 31);
					end loop;
					state <= calculate_words;
				when calculate_words =>
					-- This cannot be done in a loop for some reason...
					-- For each of the remaining words (16 - 79), do a calculation
					words(calculate_words_stage) <= (words(calculate_words_stage - 3) xor words(calculate_words_stage - 8)
						xor words(calculate_words_stage - 14) xor words(calculate_words_stage - 16)) rol 1;
					
					-- Check to see if the last word was reached this cycle
					if(calculate_words_stage = words'high) then
						-- reset the counter for subsiquent calls
						calculate_words_stage := 16;
						state <= main;
					else
						-- not done yet.  increment the counter for the next pass
						calculate_words_stage := calculate_words_stage + 1;
					end if;
				when main =>
					-- This is where the bulk of the magic happens.
					
					-- There are 4 'functions' to run.  The function called is dependant
					-- on which word the loop is currently on
					
					if(main_stage >= 0 and main_stage <= 19) then
						f := (B and C) or ((not B) and D);
						k := x"5A827999";
					elsif(main_stage >= 20 and main_stage <= 39) then
						f := B xor C xor D;
						k := x"6ED9EBA1";
					elsif(main_stage >= 40 and main_stage <= 59) then
						f := (b and c) or (b and d) or (c and d);
						k := x"8F1BBCDC";
					elsif(main_stage >= 60 and main_stage <= 79) then
						f := b xor c xor d;
						k := x"CA62C1D6";
					end if;
					
					-- This could be done inline on the 'a := temp', but it's a little cleaner here
					temp := (a rol 5) + f + e + k + words(main_stage);
					
					-- Move some values around
					e := d;
					d := c;
					c := b rol 30;
					b := a;
					a := temp;
					
					-- Check to see if the last word was just finished
					if(main_stage = 79) then
						-- All done hashing!
						state <= cleanup;
					else
						-- Not done yet.  Increment for the next pass
						main_stage := main_stage + 1;
					end if;
				when cleanup =>
					-- Set the final variable that is the 160-bit hash
					final <= (h0 + a) & (h1 + b) & (h2 + c) & (h3 + d) & (h4 + e);
					state <= done;
				when others =>
					-- Catch all (includes done)
					null;
			end case;
		end if;
	end process;

end Behavioral;

