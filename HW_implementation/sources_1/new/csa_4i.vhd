library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CSA4i is
    generic(n : integer := 5);
    Port ( x : in std_logic_vector (n-1 downto 0);
           y : in std_logic_vector (n-1 downto 0);
           z : in std_logic_vector (n-1 downto 0);
           w : in std_logic_vector (n-1 downto 0);
           cout : out std_logic;
           s : out std_logic_vector (n downto 0)
         );
end CSA4i;

architecture csa_arch of CSA4i is

component fulladder is
    port (a : in std_logic;
          b : in std_logic;
          cin : in std_logic;
          sum : out std_logic;
          carry : out std_logic
         );
end component;

signal c1,s1,c2,s2,c3 : unsigned (n-1 downto 0) := (others => '0');
signal c_final : std_logic; 

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
    for i in 1 to n-1 generate
        fa : fulladder
            port map (
                a => c1(i-1),
                b => s1(i),
                cin => w(i),
                sum => s2(i),
                carry => c2(i)
            );
    end generate;

    fa_2_0 : fulladder 
        port map(a =>'0',
                b =>s1(0), 
                cin => w(0),
                sum => s(0),
                carry => c2(0));

    third_stage:
    for i in 1 to n-2 generate
        fa : fulladder
            port map(
                a => c2(i),
                b => s2(i+1),
                cin => c3(i-1),
                sum => s(i+1),
                carry => c3(i)
                );
    end generate;

    fa_3_0 : fulladder 
        port map(
                a =>'0',
                b => c2(0),
                cin => s2(1), 
                sum => s(1), 
                carry => c3(0));
    fa_3_n : fulladder 
        port map(a =>c3(n-2), 
                b =>c2(n-1), 
                cin => c1(n-1), 
                sum => s(n), 
                carry => c_final);
     cout <= c_final;
--     s(n+1) <= c_final;
end csa_arch;
