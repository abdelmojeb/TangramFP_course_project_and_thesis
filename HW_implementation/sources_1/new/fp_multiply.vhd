----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/09/2024 06:43:05 PM
-- Design Name: 
-- Module Name: fp_mult - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
--arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity fp_mult is
generic (width : integer range 8 to 32 := 24; cut : integer range 1 to 16 := 11);
    Port ( 
           clk : in STD_LOGIC;
           n_rst : in STD_LOGIC;
           mantissa_a,mantissa_b : in STD_LOGIC_VECTOR (23 downto 0);
           exp_ab_in : in unsigned (10 downto 0);
           mode : in std_logic_vector (1 downto 0);
           dnt_mult : in std_logic;
           exp_ab: out unsigned (10 downto 0);
           mantissa_ab_norm: out STD_LOGIC_VECTOR (51 downto 0):=(others=>'0')

);
end fp_mult;

architecture Behavioral of fp_mult is
    component kacy_32_mult generic(width : integer ; cut : integer);
        port (
--                clk : in std_logic; n_rst : in std_logic;
                u : in std_logic_vector(width-1 downto 0);
                v : in std_logic_vector(width-1 downto 0);
                mode : in std_logic_vector(1 downto 0);
                mantissa : out std_logic_vector(2*width-1 downto 0)
            );
    end component;

signal mantissa_ab : std_logic_vector(47 downto 0);

begin
kacy_mult : kacy_32_mult 
            generic map (
                 width => width,
                 cut  => cut)
            port map (

                  u=>mantissa_a, v=>mantissa_b,
                  mode=>mode,
                  mantissa=>mantissa_ab);

    
    --normalization of the result
    process(clk)
        begin
        if rising_edge(clk) then
            if (n_rst = '0' or dnt_mult = '1')then
                mantissa_ab_norm <= (others => '0');
                exp_ab <= (others=>'0');
           else
               if (mantissa_ab(47)= '1') then
                    mantissa_ab_norm <= mantissa_ab(46 downto 0) & "00000";
                    exp_ab <= exp_ab_in + to_unsigned(1,11);
               elsif mantissa_ab(46) = '1' then
                    mantissa_ab_norm <= mantissa_ab(45 downto 0) & "000000";
                    exp_ab <=  exp_ab_in;
              else 
                    exp_ab <= (others => '0');
                    mantissa_ab_norm <= (others => '0');    
              end if;
          end if; 
        end if;
        end process;

end Behavioral;
