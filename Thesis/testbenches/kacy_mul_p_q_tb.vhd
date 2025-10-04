----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/14/2025 02:16:18 AM
-- Design Name: 
-- Module Name: kacy_mul_p_q_tb - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity kacy_mul_p_q_tb is
    generic(width : integer := 24; man_length : integer := 48);--(man_width_out+1)-(man_width_in+1)*2)
end kacy_mul_p_q_tb;

architecture Behavioral of Kacy_mul_p_q_tb is
    component kacy_mul_p_q is
        generic(
            width : integer := width;
            cut : integer := 11
        ); 
        port(
--            Clk : in std_logic;
--            n_rst : in std_logic;
            u : in std_logic_vector(width-1 downto 0);
            v : in std_logic_vector(width-1 downto 0);
            mode : in std_logic_vector(1 downto 0);
            mantissa : out std_logic_vector(man_length-1 downto 0)
            -- dis : out std_logic_vector(cut+1 downto 0)
    );
    end component;
    signal clk : std_logic := '0'; 
    signal n_rst : std_logic;
    signal u, v : std_logic_vector(width-1 downto 0);
    signal mode : std_logic_vector(1 downto 0);
    signal mantissa : std_logic_vector(man_length-1 downto 0);
    begin
        uut : kacy_mul_p_q  port map (--clk => clk, 
--                                 n_rst => n_rst, 
                                 u => u, v => v, 
                                 mode => mode, 
                                 mantissa => mantissa);
        clk <= not clk after 50 ns;
            
        tb: process
            begin
            wait for 100 ns;
                n_rst <= '1';
                u <=  "100000000000000000000000" ; -- std_logic_vector(to_unsigned(144, u'length));
                v <=  "100000000000000000000000"; -- std_logic_vector(to_unsigned(144, v'length));
                mode <= "00";
                wait;
            end process;
end Behavioral;
