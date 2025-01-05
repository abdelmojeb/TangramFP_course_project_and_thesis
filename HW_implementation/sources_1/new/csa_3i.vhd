library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CSA3i is
    generic(n : integer := 4);
    Port ( x : in  std_logic_vector (n-1 downto 0);
           y : in  std_logic_vector (n-1 downto 0);
           z : in  std_logic_vector (n-1 downto 0);
           cout : out std_logic;
           s : out std_logic_vector (n downto 0)
         );
end CSA3i;

architecture csa_arch of CSA3i is

component fulladder is
    port (a : in std_logic;
          b : in std_logic;
          cin : in std_logic;
          sum : out std_logic;
          carry : out std_logic
         );
end component;

signal c1,s1,c2 : unsigned (n-1 downto 0) := (others => '0');

begin

    first_stage:
    for i in 0 to n-1 generate
        fa : fulladder
            port map(
                a => x(i),
                b => y(i),
                cin => z(i),
                sum => s1(i),
                carry => c1(i));
    end generate;

    second_stage:
    for i in 0 to n-2 generate
        fa : fulladder
            port map(
                a => s1(i+1),
                b => c1(i),
                cin => c2(i),
                sum => s(i+1),
                carry => c2(i+1)
                );
    end generate;
-- fa_inst20 : fulladder port map(s1(1),c1(0),c2(0),s(1),c2(1));
-- fa_inst21 : fulladder port map(s1(2),c1(1),c2(1),s(2),c2(2));
-- fa_inst22 : fulladder port map(s1(3),c1(2),c2(2),s(3),c2(3));

third_stage : fulladder port map('0', c1(n-1), c2(n-1), s(n), cout);

s(0) <= s1(0);

end csa_arch;
