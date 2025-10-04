-- unsigned multiplication with a longer than b
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.tools.ALL;

ENTITY DaddaMultiplier_p_q IS
    GENERIC (
        n : INTEGER := 11;
        m : INTEGER := 12);--p and q cuts
    PORT (
        enable : IN STD_LOGIC;
        a : IN STD_LOGIC_VECTOR(m - 1 DOWNTO 0);
        b : IN STD_LOGIC_VECTOR(n - 1 DOWNTO 0);
        --        is_signed : in std_logic;
        -- result : out std_logic_vector(2 * n - 1 downto 0)
        orow1 : OUT STD_LOGIC_VECTOR(n + m - 1 DOWNTO 0);
        orow2 : OUT STD_LOGIC_VECTOR(n + m - 1 DOWNTO 0)
    );
END DaddaMultiplier_p_q;

ARCHITECTURE Dadda_arch OF DaddaMultiplier_p_q IS
    CONSTANT stages : NATURAL := stages(n);

    -- holds the values of the dots in the dot diagram
    TYPE DotDiagram IS ARRAY (n + m - 1 DOWNTO 0, 0 TO n - 1) OF STD_LOGIC;
    TYPE Wiring IS ARRAY (0 TO stages) OF DotDiagram;
    SIGNAL dot : Wiring;

    -- intermediate signals for adder input
    SIGNAL row1, row2 : STD_LOGIC_VECTOR(n + m - 1 DOWNTO 1);

    -- intermediate signals for adder output
    SIGNAL adder_output : STD_LOGIC_VECTOR(n + m - 1 DOWNTO 1);
    SIGNAL adder_carry : STD_LOGIC;
BEGIN

    -- process for the partial product generation and CSA tree
    main_process : PROCESS (a, b, dot)--is_signed
        TYPE Count IS ARRAY(n + m - 1 DOWNTO 0) OF NATURAL;
        VARIABLE addCount, dotCount : Count;
        VARIABLE target, halfadders, fulladders : NATURAL;
    BEGIN
        -- intialize dot count to zero
        FOR i IN 0 TO n + m - 1 LOOP
            dotCount(i) := 0;
        END LOOP;

        -- form partial products
        -- for regaining sign multiplication comment out the commented lines
        FOR i IN 0 TO m - 1 LOOP
            FOR j IN 0 TO n - 1 LOOP
                --                if (i = n - 1 xor j = n - 1) then
                --                    dot(0)(i + j, dotCount(i + j)) <= (a(i) and b(j)) xor is_signed;
                --                else
                dot(0)(i + j, dotCount(i + j)) <= a(i) AND b(j);
                --                end if;
                dotCount(i + j) := dotCount(i + j) + 1;
            END LOOP;
        END LOOP;

        -- add correction bits
        --dot(0)(n, dotCount(n)) <= is_signed;
        -- dotCount(n) := dotCount(n) + 1;
        dot(0)(n + m - 1, dotCount(n + m - 1)) <= '0';--is_signed;
        dotCount(n + m - 1) := dotCount(n + m - 1) + 1;

        target := n;
        FOR i IN 0 TO stages - 1 LOOP
            -- update target for next reduction
            target := (target * 2 + 2) / 3;

            -- initialize add count to zero
            FOR j IN 0 TO n + m - 1 LOOP
                addCount(j) := 0;
            END LOOP;

            FOR j IN 0 TO n + m - 1 LOOP
                -- calculate number of full adders and half adders
                -- based on the no. of dots and the no. of dots to be added
                fulladders := num_fa(dotCount(j), addCount(j), target);
                halfadders := num_ha(dotCount(j), addCount(j), target);

                -- update dot count
                dotCount(j) := dotCount(j) - 3 * fulladders - 2 * halfadders;

                -- update the number of dots that will be added in the next stage
                -- (this is not added to dot(...) directly because we can't use these
                -- in adders so it is convenient to distinguish between the two
                addCount(j) := addCount(j) + fulladders + halfadders;
                IF (j < n + m - 1) THEN
                    addCount(j + 1) := addCount(j + 1) + fulladders + halfadders;
                END IF;

                -- pass through leftover dots
                FOR k IN 0 TO dotCount(j) - 1 LOOP
                    dot(i + 1)(j, k) <= dot(i)(j, 3 * fulladders + 2 * halfadders + k);
                END LOOP;

                -- connect half adders
                FOR k IN 0 TO halfadders - 1 LOOP
                    dot(i + 1)(j, dotCount(j) + k) <=
                    dot(i)(j, 3 * fulladders + 2 * k) XOR
                    dot(i)(j, 3 * fulladders + 2 * k + 1);
                    dot(i + 1)(j + 1, dots_left(dotCount(j + 1), addCount(j + 1), target) +
                    num_ha(dotCount(j + 1), addCount(j + 1), target) +
                    num_fa(dotCount(j + 1), addCount(j + 1), target) + k) <=
                    dot(i)(j, 3 * fulladders + 2 * k) AND
                    dot(i)(j, 3 * fulladders + 2 * k + 1);
                END LOOP;

                -- connect full adders
                FOR k IN 0 TO fulladders - 1 LOOP
                    dot(i + 1)(j, dotCount(j) + halfadders + k) <= dot(i)(j, 3 * k) XOR
                    dot(i)(j, 3 * k + 1) XOR
                    dot(i)(j, 3 * k + 2);
                    dot(i + 1)(j + 1, dots_left(dotCount(j + 1), addCount(j + 1), target)
                    + num_ha(dotCount(j + 1), addCount(j + 1), target)
                    + num_fa(dotCount(j + 1), addCount(j + 1), target) +
                    halfadders + k) <=
                    (dot(i)(j, 3 * k) AND dot(i)(j, 3 * k + 1)) OR
                    (dot(i)(j, 3 * k) AND dot(i)(j, 3 * k + 2)) OR
                    (dot(i)(j, 3 * k + 1) AND dot(i)(j, 3 * k + 2));
                END LOOP;
            END LOOP;

            -- update dot count
            FOR j IN 0 TO n + m - 1 LOOP
                dotCount(j) := dotCount(j) + addCount(j);
            END LOOP;

        END LOOP;
    END PROCESS;

    -- update intermediate row variable
    -- (this is easier than mapping to dot diagram to the adder directly)
    rows_update : PROCESS (dot, enable)
    BEGIN
        IF (enable = '1') THEN
            row1(n + m - 1) <= dot(stages)(n + m - 1, 0);
            row2(n + m - 1) <= '0';
            FOR i IN n + m - 2 DOWNTO 1 LOOP
                row1(i) <= dot(stages)(i, 0);
                row2(i) <= dot(stages)(i, 1);
            END LOOP;
        ELSE
            row1 <= (OTHERS => '0');
            row2 <= (OTHERS => '0');
        END IF;
    END PROCESS rows_update;

    -------- move the following out of the dadda

    orow1 <= row1 & dot(stages)(0, 0);
    orow2 <= row2 & '0';

    -- adder_output <= row1 + row2;
    -- result(0) <= dot(stages)(0, 0);
    -- result(2 * n - 1 downto 1) <= adder_output(2 * n - 1 downto 1);

END Dadda_arch;