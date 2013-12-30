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

	signal h0 : unsigned(31 downto 0) := "01100111010001010010001100000001";
	signal h1 : unsigned(31 downto 0) := "11101111110011011010101110001001";
	signal h2 : unsigned(31 downto 0) := "10011000101110101101110011111110";
	signal h3 : unsigned(31 downto 0) := "00010000001100100101010001110110";
	signal h4 : unsigned(31 downto 0) := "11000011110100101110000111110000";
	
	constant text : unsigned(47 downto 0) := x"412054657374";
	
	signal blk : unsigned(511 downto 0) := (others => '0');
	
	subtype word is unsigned(31 downto 0);
	type words_type is array(79 downto 0) of word;
	signal words : words_type := (others => (others => '0'));
	
	type state_type is (load, zero, length, load_words, calculate_words, main, cleanup, done);
	signal state : state_type := load;
	
	signal final : unsigned(159 downto 0) := (others => '0');

begin

	process(clk, rst)
		variable calculate_words_stage : integer range 16 to words'high := 16;
		variable A : unsigned(31 downto 0) := h0;
		variable B : unsigned(31 downto 0) := h1;
		variable C : unsigned(31 downto 0) := h2;
		variable D : unsigned(31 downto 0) := h3;
		variable E : unsigned(31 downto 0) := h4;
		variable F : unsigned(31 downto 0) := (others => '0');
		variable K : unsigned(31 downto 0) := (others => '0');
		variable temp : unsigned(63 downto 0) := (others => '0');
		variable main_stage : integer range 0 to 79 := 0;
	begin
		if(rst = '1') then
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
			case state is 
				when load =>
					blk(511 downto 511-text'high) <= text;
					state <= zero;
				when zero =>
					blk(510-text'high) <= '1';
					state <= length;
				when length =>
					blk(63 downto 0) <= to_unsigned(text'length, 64);
					state <= load_words;
				when load_words =>
					for i in 0 to 15 loop
						words(i) <= blk(511 - (i * 32) downto 511 - (i * 32) - 31);
					end loop;
					state <= calculate_words;
				when calculate_words =>
					words(calculate_words_stage) <= (words(calculate_words_stage - 3) xor words(calculate_words_stage - 8)
						xor words(calculate_words_stage - 14) xor words(calculate_words_stage - 16)) rol 1;
					
					if(calculate_words_stage = words'high) then
						calculate_words_stage := 16;
						state <= main;
					else
						calculate_words_stage := calculate_words_stage + 1;
					end if;
				when main =>
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
					
					temp := (a rol 5) + f + e + k + words(main_stage);
					e := d;
					d := c;
					c := b rol 30;
					b := a;
					a := temp(63 downto 32);
					
					if(main_stage = 79) then
						state <= cleanup;
					else
						main_stage := main_stage + 1;
					end if;
				when cleanup =>
					final <= (h0 + a) & (h1 + b) & (h2 + c) & (h3 + d) & (h4 + e);
					state <= done;
				when others =>
					null;
			end case;
		end if;
	end process;

end Behavioral;

