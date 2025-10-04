library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity testbench is
generic(n : integer := 6; m : integer := 6);
end testbench;

architecture behavior of testbench is
	component DaddaMultiplier_p_q
		generic(n : integer := n; m : integer := m);
		port(
		    enable : in std_logic;
			a : in std_logic_vector(m - 1 downto 0);
			b : in std_logic_vector(n - 1 downto 0);
--			is_signed : in std_logic;
			--result : out std_logic_vector(2 * n - 1 downto 0)
			 orow1 : out std_logic_vector(n+m  - 1 downto 0);
             orow2 : out std_logic_vector(n+m  - 1 downto 0)
		);
	end component;
    signal enable: std_logic;
	signal op1 : std_logic_vector(m-1 downto 0); --:= "11111";
	signal op2 : std_logic_vector(n-1 downto 0) ;--:= "11111";
	--signal result : std_logic_vector(9 downto 0);
	signal orow1 : std_logic_vector(n+m -1 downto 0);
	signal orow2 : std_logic_vector(n+m -1 downto 0);
	signal result : std_logic_vector(n+m -1 downto 0):=(others => '0');

begin
	uut: DaddaMultiplier_p_q port map(enable => enable,
	                                a => op1, b => op2,
--	                                 is_signed => '0',
	                                  orow1 => orow1,
	                                  orow2 => orow2 );
    process(orow1,orow2) begin
        result <= orow1 + orow2;
    end process;
	tb : process
	begin
	    enable <= '1';
--		op1 <= "1110";--"11101";
--		op2 <= "1110";--"10111";
--		result <= orow1 + orow2;
		wait for 100 ns;
		
		op1 <= "011110";
		op2 <= "011110";
		
		
		wait;
	end process;
end;
