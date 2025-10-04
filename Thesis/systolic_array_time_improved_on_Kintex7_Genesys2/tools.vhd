LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE tools IS
    FUNCTION clog2(n : NATURAL) RETURN NATURAL;
    FUNCTION flog2(n : NATURAL) RETURN NATURAL;
    FUNCTION max(a, b : INTEGER) RETURN INTEGER;
    FUNCTION min(a, b : INTEGER) RETURN INTEGER;
    FUNCTION stages(height : NATURAL) RETURN NATURAL;
    FUNCTION num_fa(dots, add, target : NATURAL) RETURN NATURAL;
    FUNCTION num_ha(dots, add, target : NATURAL) RETURN NATURAL;
    FUNCTION dots_left(dots, add, target : NATURAL) RETURN NATURAL;
    FUNCTION float_32_to_64 (f : STD_LOGIC_VECTOR(31 DOWNTO 0))RETURN STD_LOGIC_VECTOR;
    FUNCTION float_64_to_32 (f : STD_LOGIC_VECTOR(63 DOWNTO 0)) RETURN STD_LOGIC_VECTOR;
    FUNCTION float_to_half (f : STD_LOGIC_VECTOR(31 DOWNTO 0))RETURN STD_LOGIC_VECTOR;
    FUNCTION choose_width(p, q : INTEGER) RETURN INTEGER;
END;

PACKAGE BODY tools IS

    FUNCTION clog2 (n : NATURAL) RETURN NATURAL IS
        VARIABLE counter : NATURAL;
        VARIABLE m : NATURAL;
    BEGIN
        m := n - 1;
        counter := 1;
        WHILE (m > 1) LOOP
            m := m / 2;
            counter := counter + 1;
        END LOOP;
        RETURN counter;
    END FUNCTION;

    FUNCTION flog2 (n : NATURAL) RETURN NATURAL IS
        VARIABLE counter : NATURAL;
        VARIABLE m : NATURAL;
    BEGIN
        m := n;
        counter := 0;
        WHILE (m > 1) LOOP
            m := m / 2;
            counter := counter + 1;
        END LOOP;
        RETURN counter;
    END FUNCTION;

    FUNCTION max (a, b : INTEGER) RETURN INTEGER IS
    BEGIN
        IF (a > b) THEN
            RETURN a;
        ELSE
            RETURN b;
        END IF;
    END FUNCTION;

    FUNCTION min (a, b : INTEGER) RETURN INTEGER IS
    BEGIN
        IF (a < b) THEN
            RETURN a;
        ELSE
            RETURN b;
        END IF;
    END FUNCTION;

    FUNCTION num_fa(dots, add, target : NATURAL) RETURN NATURAL IS
    BEGIN
        RETURN min(dots / 3, max((dots + add - target) / 2, 0));
    END FUNCTION;

    FUNCTION num_ha(dots, add, target : NATURAL) RETURN NATURAL IS
        VARIABLE dots_left, target_left : NATURAL;
    BEGIN
        dots_left := dots - 2 * num_fa(dots, add, target);
        target_left := target - num_fa(dots, add, target);
        RETURN min(dots_left / 2, max(dots_left + add - target, 0));
    END FUNCTION;

    FUNCTION stages(height : NATURAL) RETURN NATURAL IS
        VARIABLE h, count : NATURAL;
    BEGIN
        h := height;
        count := 0;
        WHILE (h > 2) LOOP
            h := (h * 2 + 2) / 3;
            count := count + 1;
        END LOOP;
        RETURN count;
    END FUNCTION;

    FUNCTION dots_left(dots, add, target : NATURAL) RETURN NATURAL IS
    BEGIN
        RETURN dots - 3 * num_fa(dots, add, target) - 2 * num_ha(dots, add, target);
    END FUNCTION;
    --32 to 64 conversion
    FUNCTION float_32_to_64 (f : STD_LOGIC_VECTOR(31 DOWNTO 0))
        RETURN STD_LOGIC_VECTOR IS
        VARIABLE exp_old : INTEGER := to_integer(unsigned(f(30 DOWNTO 23)));
        VARIABLE exp : unsigned (10 DOWNTO 0) := (OTHERS => '0');
        VARIABLE m : unsigned (22 DOWNTO 0) := unsigned(f(22 DOWNTO 0));
        VARIABLE shift_count : NATURAL RANGE 0 TO 32 := 0;
    BEGIN
        IF (exp_old > 0 AND exp_old < 255) THEN
            exp := to_unsigned((exp_old + 896), 11);
        ELSIF (exp_old > 254) THEN
            exp := (OTHERS => '1');
        ELSE
            exp := (OTHERS => '0');
            m := (OTHERS => '0');
        END IF;
        RETURN f(31) & STD_LOGIC_VECTOR(exp) & STD_LOGIC_VECTOR(m) & STD_LOGIC_VECTOR(to_unsigned(0, 29));
    END FUNCTION;

    FUNCTION float_64_to_32 (f : STD_LOGIC_VECTOR(63 DOWNTO 0))
        RETURN STD_LOGIC_VECTOR IS
        VARIABLE v : INTEGER := 16777215;
        VARIABLE exp : unsigned(10 DOWNTO 0) := unsigned(f(62 DOWNTO 52));
        VARIABLE mantissa : unsigned (24 DOWNTO 0) := '0' & unsigned(f(51 DOWNTO 28)) + 1;
    BEGIN
        IF exp = "11111111111" THEN
            IF mantissa /= 0 THEN
                -- NaN
                mantissa := (OTHERS => '1'); -- or preserve upper mantissa bits
            ELSE
                -- Infinity
                mantissa := (OTHERS => '0');
            END IF;
        ELSIF (to_integer(exp) < 873) THEN
            exp := (OTHERS => '0');
            mantissa := (OTHERS => '0');
        ELSIF (to_integer(exp) > 872 AND to_integer(exp) < 897) THEN
            REPORT INTEGER'image(to_integer(mantissa));
            mantissa := mantissa + to_unsigned(16777215, 25);
            REPORT INTEGER'image(to_integer(mantissa));
            mantissa := shift_right(mantissa, (897 - to_integer(exp))) + 1;
            REPORT INTEGER'image(to_integer(mantissa));
            mantissa := shift_right(mantissa, 1);
            REPORT INTEGER'image(to_integer(mantissa));
            exp := (OTHERS => '0');
        ELSIF (to_integer(exp) > 896 AND to_integer(exp) <= 1150) THEN
            exp := exp - 896;
            mantissa := shift_right(mantissa, 1);
        ELSIF (to_integer(exp) > 1150) THEN
            exp := (OTHERS => '1');
        ELSE
            exp := (OTHERS => '0');
            mantissa := (OTHERS => '0');
        END IF;

        RETURN f(63) & STD_LOGIC_VECTOR(exp(7 DOWNTO 0)) & STD_LOGIC_VECTOR(mantissa(22 DOWNTO 0));
    END FUNCTION;
    --float to half
    FUNCTION float_to_half (f : STD_LOGIC_VECTOR(31 DOWNTO 0))
        RETURN STD_LOGIC_VECTOR IS
        VARIABLE v : INTEGER := 1023;
        VARIABLE exp : unsigned(7 DOWNTO 0) := unsigned(f(30 DOWNTO 23));
        VARIABLE mantissa : unsigned (11 DOWNTO 0) := '0' & unsigned(f(22 DOWNTO 12)) + 1;
    BEGIN
        IF exp = "11111111" THEN
            IF mantissa /= 0 THEN
                -- NaN
                mantissa := (OTHERS => '1'); -- or preserve upper mantissa bits
            ELSE
                -- Infinity
                mantissa := (OTHERS => '0');
            END IF;
        ELSIF (to_integer(exp) < 102) THEN
            exp := (OTHERS => '0');
            mantissa := (OTHERS => '0');
        ELSIF (to_integer(exp) > 101 AND to_integer(exp) < 113) THEN
            REPORT INTEGER'image(to_integer(mantissa));
            mantissa := mantissa + to_unsigned(v, 10);
            REPORT INTEGER'image(to_integer(mantissa));
            mantissa := shift_right(mantissa, (125 - to_integer(exp))) + 1;
            REPORT INTEGER'image(to_integer(mantissa));
            mantissa := shift_right(mantissa, 1);
            REPORT INTEGER'image(to_integer(mantissa));
            exp := (OTHERS => '0');
        ELSIF (to_integer(exp) > 112 AND to_integer(exp) < 143) THEN
            exp := exp - 112;
            mantissa := shift_right(mantissa, 1);
        ELSIF (to_integer(exp) >= 143) THEN
            exp := (OTHERS => '1');
        ELSE
            exp := (OTHERS => '0');
            mantissa := (OTHERS => '0');
        END IF;

        RETURN f(31) & STD_LOGIC_VECTOR(exp(4 DOWNTO 0)) & STD_LOGIC_VECTOR(mantissa(9 DOWNTO 0));
    END FUNCTION;
    FUNCTION choose_width(p, q : INTEGER) RETURN INTEGER IS
    BEGIN
        IF p >= q THEN
            RETURN 2 * p;
        ELSE
            RETURN p + q;
        END IF;
    END FUNCTION;
END PACKAGE BODY;