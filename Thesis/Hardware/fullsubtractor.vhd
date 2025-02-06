----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/13/2024 10:43:10 AM
-- Design Name: 
-- Module Name: fullsubtractor - Behavioral
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

entity fullsubtractor is
 port (
       a    : in std_logic;  -- Minuend
       b    : in std_logic;  -- Subtrahend
       bin  : in std_logic;  -- Borrow-in
       diff : out std_logic; -- Difference
       bout : out std_logic  -- Borrow-out
   );
end fullsubtractor;

architecture Behavioral of fullsubtractor is

begin
diff <= a xor b xor bin;  -- Difference calculation
    bout <= (not a and b) or (bin and (not a xor b));

end Behavioral;
