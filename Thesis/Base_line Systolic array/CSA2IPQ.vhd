----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/26/2025 06:26:21 PM
-- Design Name: 
-- Module Name: CSA2i - Behavioral
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CSA2iPQ is
    generic(n : integer := 22; p : integer range 0 to 16 := 5;
    cut : integer range 0 to 16 := 5);
    Port ( x : in  std_logic_vector (n-1 downto 0);
           y : in  std_logic_vector (P+cut+1 downto 0);
           z : in  std_logic;
           s : out std_logic_vector (n downto 0)
         );
end CSA2iPQ;

architecture csa_arch of CSA2iPQ is
signal c : std_logic_vector(n-cut-1 downto 0) := (others => '0');
begin
-- First stage: Full adder for x + y + z
    first: for i in cut to p+2*cut+1 generate
        s(i) <= (x(i) xor y(i-cut)) xor c(i-cut); -- Sum
        c(i+1-cut) <= (x(i) and y(i-cut)) or (c(i-cut) and (y(i-cut) xor x(i))); -- Carry
    end generate first;
    second: for i in p+2*cut+2 to n-3 generate
        s(i) <= x(i) xor c(i-cut);
        c(i+1-cut) <= x(i) and c(i-cut);
    end generate;
    s(n-2) <= x(n-2) xor z xor c(n-2-cut);
    c(n-1-cut) <= (x(n-2) and z)or (c(n-2-cut) and(x(n-2) xor z));
    s(n-1) <= x(n-1) xor c(n-1-cut);
    s(n) <= x(n-1) and c(n-1-cut);
    s(cut-1 downto 0) <= x(cut-1 downto 0);
end csa_arch;