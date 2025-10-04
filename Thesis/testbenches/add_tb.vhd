----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/16/2025 03:30:07 AM
-- Design Name: 
-- Module Name: add_tb - Behavioral
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
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity add_tb is
    generic(precision : integer range 0 to 64 := 64; 
  man_width : integer range 0 to 64 := 52; 
  exp_width: integer range 0 to 31 := 11);
end add_tb;

architecture Behavioral of add_tb is


    component add_fp 
      generic (precision : integer range 0 to 64;--:= 32; 
      man_width : integer range 0 to 64;--:= 23; 
      exp_width: integer range 0 to 31--:= 8
      );
      Port (exp_ain,exp_bin : in unsigned(exp_width-1 downto 0);
            man_ain, man_bin : in std_logic_vector(man_width downto 0);
            sign_a,sign_b : in std_logic;
            z_sum : std_logic;
            result : out std_logic_vector(precision-1 downto 0));
    end component;
   
    signal clk : std_logic := '0'; 
    signal n_rst : std_logic;
    signal sum_32_in, ab_add_in : std_logic_vector(man_width downto 0);
    signal sum_pre_out : std_logic_vector(precision-1 downto 0);
    signal exp_cn_addin,exp_ab_addin : unsigned(exp_width-1 downto 0);
    signal z_sum , sign_c,sign_ab : std_logic := '0';
    begin
        uut : add_fp  
     generic map (precision => precision, man_width => man_width,exp_width=>exp_width)
       Port map (
             exp_ain => exp_cn_addin,
             exp_bin => exp_ab_addin,
             man_ain => sum_32_in,
             man_bin=> ab_add_in,
             sign_a => sign_c,
             sign_b => sign_ab,
             z_sum => z_sum,
             result => sum_pre_out);
        clk <= not clk after 50 ns;
            
        tb: process
            begin
            wait for 100 ns;
                n_rst <= '1';
                exp_cn_addin <=  "01111111111";
                exp_ab_addin <= "01111111111";
                sum_32_in <= (others => '0');
                ab_add_in <= "01"&std_logic_vector(to_unsigned(0,51));
                sign_c <= '0';
                sign_ab<= '1';
                z_sum <= '1';
                wait;
            end process;
end Behavioral;
