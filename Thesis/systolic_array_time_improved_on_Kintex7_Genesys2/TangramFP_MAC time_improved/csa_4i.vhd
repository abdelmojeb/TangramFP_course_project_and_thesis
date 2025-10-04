LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY CSA4i IS
    GENERIC (n : INTEGER := 5);
    PORT (
        x : IN STD_LOGIC_VECTOR (n - 1 DOWNTO 0);
        y : IN STD_LOGIC_VECTOR (n - 1 DOWNTO 0);
        z : IN STD_LOGIC_VECTOR (n - 1 DOWNTO 0);
        w : IN STD_LOGIC_VECTOR (n - 1 DOWNTO 0);
        cout : OUT STD_LOGIC;
        s : OUT STD_LOGIC_VECTOR (n DOWNTO 0)
    );
END CSA4i;
ARCHITECTURE csa_arch OF CSA4i IS
    ATTRIBUTE use_carry_chain : STRING;
    ATTRIBUTE use_carry_chain OF csa_arch : ARCHITECTURE IS "yes";

    SIGNAL c1, c2 : STD_LOGIC_VECTOR(n - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s2, c3 : STD_LOGIC_VECTOR(n - 2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s1 : STD_LOGIC_VECTOR(n - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL c_final : STD_LOGIC := '0';

BEGIN
    -- First stage: Add x, y, and z
    first_stage : FOR i IN 0 TO n - 1 GENERATE

        s1(i) <= x(i) XOR y(i) XOR z(i); -- Sum
        c1(i) <= (x(i) AND y(i)) OR (y(i) AND z(i)) OR (z(i) AND x(i)); -- Carry
    END GENERATE;

    -- Second stage: Add s1, c1, and w
    second_stage : FOR i IN 0 TO n - 1 GENERATE
        se1 : IF i = 0 GENERATE
            s(i) <= s1(i) XOR w(i); -- Sum
            c2(i) <= s1(i) AND w(i); -- Carry
        END GENERATE se1;

        se2 : IF i > 0 GENERATE
            s2(i - 1) <= (s1(i) XOR w(i)) XOR c1(i - 1); -- Sum
            c2(i) <= (s1(i) AND w(i)) OR (c1(i - 1) AND (s1(i) XOR w(i))); -- Carry
        END GENERATE se2;
    END GENERATE;

    -- Third stage: Combine c2 and s2
    third_stage : FOR i IN 1 TO n - 2 GENERATE

        s(i + 1) <= (s2(i) XOR c2(i)) XOR c3(i - 1); -- Sum
        c3(i) <= (s2(i) AND c2(i)) OR (c3(i - 1) AND (c2(i) XOR s2(i))); -- Carry
    END GENERATE;

    -- Handle the boundary cases for third stage

    s(1) <= c2(0) XOR s2(0);
    c3(0) <= c2(0) AND s2(0);
    s(n) <= c1(n - 1) XOR c2(n - 1) XOR c3(n - 2);
    c_final <= (c1(n - 1) AND c2(n - 1)) OR (c3(n - 2) AND (c1(n - 1) XOR c2(n - 1)));

    cout <= c_final;

END csa_arch;