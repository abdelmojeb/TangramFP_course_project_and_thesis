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
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY CSA2iPQ IS
    GENERIC (
        n : INTEGER := 22;
        p : INTEGER RANGE 0 TO 16 := 5;
        cut : INTEGER RANGE 0 TO 16 := 5);
    PORT (
        x : IN STD_LOGIC_VECTOR (n - 1 DOWNTO 0);
        y : IN STD_LOGIC_VECTOR (P + cut + 1 DOWNTO 0);
        z : IN STD_LOGIC;
        s : OUT STD_LOGIC_VECTOR (n DOWNTO 0)
    );
END CSA2iPQ;

ARCHITECTURE csa_arch OF CSA2iPQ IS
    SIGNAL c : STD_LOGIC_VECTOR(n - cut - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN
    -- First stage: Full adder for x + y + z
    first : FOR i IN cut TO p + 2 * cut + 1 GENERATE
        s(i) <= (x(i) XOR y(i - cut)) XOR c(i - cut); -- Sum
        c(i + 1 - cut) <= (x(i) AND y(i - cut)) OR (c(i - cut) AND (y(i - cut) XOR x(i))); -- Carry
    END GENERATE first;
    second : FOR i IN p + 2 * cut + 2 TO n - 3 GENERATE
        s(i) <= x(i) XOR c(i - cut);
        c(i + 1 - cut) <= x(i) AND c(i - cut);
    END GENERATE;
    s(n - 2) <= x(n - 2) XOR z XOR c(n - 2 - cut);
    c(n - 1 - cut) <= (x(n - 2) AND z) OR (c(n - 2 - cut) AND(x(n - 2) XOR z));
    s(n - 1) <= x(n - 1) XOR c(n - 1 - cut);
    s(n) <= x(n - 1) AND c(n - 1 - cut);
    s(cut - 1 DOWNTO 0) <= x(cut - 1 DOWNTO 0);
END csa_arch;