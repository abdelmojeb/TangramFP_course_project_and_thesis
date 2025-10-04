----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01/20/2025 09:33:02 PM
-- Design Name: 
-- Module Name: lzc_tb - Behavioral
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

entity lzc_tb is
--  Port ( );
end lzc_tb;

architecture Behavioral of lzc_tb is
component lzc_54
    port (
    mantissa   : in std_logic_vector(24 downto 0);
    enable: in std_logic;
    shift_count: out std_logic_vector(5 downto 0)
--    shift_all  : out std_logic
);
end component;

signal clk : std_logic := '0';
signal rst : std_logic := '0';
signal input_vector : std_logic_vector(24 downto 0) := (others => '1');
signal shift : std_logic_vector(5 downto 0);
signal enable : std_logic;

begin

-- Clock generation process
clk_process : process
begin
    while true loop
        clk <= '0';
        wait for 10 ns;
        clk <= '1';
        wait for 10 ns;
    end loop;
end process;

-- Test process
test_process : process
begin
    -- Reset
    rst <= '1';
    wait for 20 ns;
    rst <= '0';
    enable <= '1';
    wait for 20 ns;
    
    -- Apply test vectors
    for i in 0 to 25 loop
        input_vector <= std_logic_vector(shift_right(unsigned(input_vector), 1));
        wait for 20 ns;
    end loop;

    -- End simulation
    wait;
end process;

-- Instantiate the Unit Under Test (UUT)
uut: lzc_54
    Port map (
        mantissa => input_vector,
        enable => enable,
        shift_count => shift
--        shift_all => shiftall
    );
end Behavioral;