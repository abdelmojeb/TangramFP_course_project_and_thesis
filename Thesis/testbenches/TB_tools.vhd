----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/08/2025 07:35:29 PM
-- Design Name: 
-- Module Name: TB_tools - 
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
USE IEEE.NUMERIC_STD.ALL;
USE ieee.math_real.ALL;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

PACKAGE TB_tools IS
    FUNCTION float_32_to_64 (f : STD_LOGIC_VECTOR(31 DOWNTO 0))RETURN STD_LOGIC_VECTOR;
    FUNCTION float_64_to_32 (f : STD_LOGIC_VECTOR(63 DOWNTO 0)) RETURN STD_LOGIC_VECTOR;
    FUNCTION is_x(v : STD_LOGIC_VECTOR) RETURN BOOLEAN;
    PROCEDURE generate_aligned_random_vectors16(seed1, seed2 : INOUT POSITIVE;
    rout_a, rout_b, rout_c : OUT STD_LOGIC_VECTOR(15 DOWNTO 0));
    PROCEDURE generate_aligned_random_vectors32(seed1, seed2 : INOUT POSITIVE;
    rout_a, rout_b, rout_c : OUT STD_LOGIC_VECTOR(31 DOWNTO 0));
    FUNCTION float_to_half (f : STD_LOGIC_VECTOR(31 DOWNTO 0))RETURN STD_LOGIC_VECTOR;
    FUNCTION real_to_float(r : real) RETURN STD_LOGIC_VECTOR;
END TB_tools;
PACKAGE BODY TB_tools IS
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
        IF (to_integer(exp) < 873) THEN
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
    FUNCTION is_x(v : STD_LOGIC_VECTOR) RETURN BOOLEAN IS
    BEGIN
        FOR i IN v'RANGE LOOP
            IF v(i) = 'X' OR v(i) = 'U' THEN
                RETURN true;
            END IF;
        END LOOP;
        RETURN false;
    END FUNCTION;
    --generate random numbers in 16bit precision
    PROCEDURE generate_aligned_random_vectors16(seed1, seed2 : INOUT POSITIVE;
    rout_a, rout_b, rout_c : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)) IS
    VARIABLE r1, r2, r3, rm1, rm2, rm3 : real;
    VARIABLE exp_a, exp_b, exp_c : INTEGER;
    VARIABLE man1, man2, man3 : NATURAL;
    VARIABLE s1, s2, s3 : STD_LOGIC;
    CONSTANT max_exp : INTEGER := 15; -- Maximum exponent for float16
    CONSTANT min_exp : INTEGER := - 14; -- Minimum exponent for normalized float16
    CONSTANT alignment_shifts : INTEGER := 0;
    CONSTANT exp_width : INTEGER := 5;
    CONSTANT man_width : INTEGER := 10;
BEGIN
    -- Generate random numbers for a and b
    uniform(seed1, seed2, r1);
    r1 := (r1 * 2.0 - 1.0); -- Range [-1,1]
    uniform(seed1, seed2, r2);
    r2 := (r2 * 2.0 - 1.0); -- Range [-1,1]

    -- Generate random number for c
    uniform(seed1, seed2, r3);
    r3 := (r3 * 2.0 - 1.0); -- Range [-1,1]

    uniform(seed1, seed2, rm1);
    uniform(seed1, seed2, rm2);
    uniform(seed1, seed2, rm3);
    man1 := INTEGER(rm1 * 1023.0);
    man2 := man1 + INTEGER(rm2 * 2.0);--integer(rm2*8388607.0);
    man3 := man1 - INTEGER(rm3 * 2.0);--integer(rm3*8388607.0);

    -- Generate exponents for a and b
    uniform(seed1, seed2, r1);
    exp_a := INTEGER(r1 * (real(max_exp) - real(min_exp))) + min_exp; -- Range [-14,15]
    uniform(seed1, seed2, r2);
    exp_b := INTEGER(r2 * (real(max_exp) - real(min_exp))) + min_exp; -- Range [-14,15]

    -- Ensure the product of a and b does not exceed the max/min values of fp-16
    IF exp_a + exp_b + alignment_shifts > max_exp THEN
        IF (exp_a > exp_b) THEN
            exp_a := max_exp - exp_b - alignment_shifts;
        ELSE
            exp_b := max_exp - exp_a - alignment_shifts;
        END IF;
    ELSIF exp_a + exp_b < min_exp THEN
        IF exp_a < exp_b THEN
            exp_a := min_exp - exp_b;
        ELSE
            exp_b := min_exp - exp_a;
        END IF;
    END IF;

    -- Ensure the exponent of c is greater than the sum of exponents of a and b minus alignment shifts
    -- value of exp_c that results in a specific multiplication mode
    exp_c := exp_a + exp_b + alignment_shifts;--+ alignment_shifts + 1;
    IF exp_c > max_exp THEN
        exp_c := max_exp;
    ELSIF exp_c < min_exp THEN
        exp_c := min_exp;
    END IF;

    IF rm1 > 0.5 THEN
        s1 := '0';
    ELSE
        s1 := '1';
    END IF;
    IF rm2 > 0.5 THEN
        s2 := '0';
    ELSE
        s2 := '1';
    END IF;
    IF rm3 > 0.5 THEN
        s3 := '0';
    ELSE
        s3 := '1';
    END IF;
    rout_a := s1 & STD_LOGIC_VECTOR(to_unsigned(exp_a + max_exp, exp_width)) & STD_LOGIC_VECTOR(to_unsigned(man1, man_width));

    rout_b := s2 & STD_LOGIC_VECTOR(to_unsigned(exp_b + max_exp, exp_width)) & STD_LOGIC_VECTOR(to_unsigned(man2, man_width));

    rout_c := s3 & STD_LOGIC_VECTOR(to_unsigned(exp_c + max_exp, exp_width)) & STD_LOGIC_VECTOR(to_unsigned(man3, man_width));
END PROCEDURE;
--random 32bit std_vectors a,b,c
PROCEDURE generate_aligned_random_vectors32(seed1, seed2 : INOUT POSITIVE;
rout_a, rout_b, rout_c : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)) IS
VARIABLE r1, r2, r3, rm1, rm2, rm3 : real;
VARIABLE exp_a, exp_b, exp_c : INTEGER;
VARIABLE man1, man2, man3 : NATURAL;
VARIABLE s1, s2, s3 : STD_LOGIC;
CONSTANT max_exp : INTEGER := 127; -- Maximum exponent for float16
CONSTANT min_exp : INTEGER := - 126; -- Minimum exponent for normalized float16
CONSTANT alignment_shifts : INTEGER := 0;
CONSTANT exp_width : INTEGER := 8;
CONSTANT man_width : INTEGER := 23;
BEGIN
-- Generate random numbers for a and b
uniform(seed1, seed2, r1);
r1 := (r1 * 2.0 - 1.0); -- Range [-1,1]
uniform(seed1, seed2, r2);
r2 := (r2 * 2.0 - 1.0); -- Range [-1,1]

-- Generate random number for c
uniform(seed1, seed2, r3);
r3 := (r3 * 2.0 - 1.0); -- Range [-1,1]

uniform(seed1, seed2, rm1);
uniform(seed1, seed2, rm2);
uniform(seed1, seed2, rm3);
man1 := INTEGER(rm1 * 8388607.0);
man2 := man1 + INTEGER(rm2 * 2.0);--integer(rm2*8388607.0);
man3 := man1 - INTEGER(rm3 * 2.0);--integer(rm3*8388607.0);

-- Generate exponents for a and b
uniform(seed1, seed2, r1);
exp_a := INTEGER(r1 * (real(max_exp) - real(min_exp))) + min_exp; -- Range [-14,15]
uniform(seed1, seed2, r2);
exp_b := INTEGER(r2 * (real(max_exp) - real(min_exp))) + min_exp; -- Range [-14,15]

-- Ensure the product of a and b does not exceed the max/min values of fp-16
IF exp_a + exp_b + alignment_shifts > max_exp THEN
    IF (exp_a > exp_b) THEN
        exp_a := max_exp - exp_b - alignment_shifts;
    ELSE
        exp_b := max_exp - exp_a - alignment_shifts;
    END IF;
ELSIF exp_a + exp_b < min_exp THEN
    IF exp_a < exp_b THEN
        exp_a := min_exp - exp_b;
    ELSE
        exp_b := min_exp - exp_a;
    END IF;
END IF;

-- Ensure the exponent of c is greater than the sum of exponents of a and b minus alignment shifts
-- value of exp_c that results in a specific multiplication mode
exp_c := exp_a + exp_b + alignment_shifts;--+ alignment_shifts + 1;
IF exp_c > max_exp THEN
    exp_c := max_exp;
ELSIF exp_c < min_exp THEN
    exp_c := min_exp;
END IF;

IF rm1 > 0.5 THEN
    s1 := '0';
ELSE
    s1 := '1';
END IF;
IF rm2 > 0.5 THEN
    s2 := '0';
ELSE
    s2 := '1';
END IF;
IF rm3 > 0.5 THEN
    s3 := '0';
ELSE
    s3 := '1';
END IF;
rout_a := s1 & STD_LOGIC_VECTOR(to_unsigned(exp_a + max_exp, exp_width)) & STD_LOGIC_VECTOR(to_unsigned(man1, man_width));

rout_b := s2 & STD_LOGIC_VECTOR(to_unsigned(exp_b + max_exp, exp_width)) & STD_LOGIC_VECTOR(to_unsigned(man2, man_width));

rout_c := s3 & STD_LOGIC_VECTOR(to_unsigned(exp_c + max_exp, exp_width)) & STD_LOGIC_VECTOR(to_unsigned(man3, man_width));
END PROCEDURE;
--float to half
FUNCTION float_to_half (f : STD_LOGIC_VECTOR(31 DOWNTO 0))
    RETURN STD_LOGIC_VECTOR IS
    VARIABLE v : INTEGER := 1023;
    VARIABLE exp : unsigned(7 DOWNTO 0) := unsigned(f(30 DOWNTO 23));
    VARIABLE mantissa : unsigned (11 DOWNTO 0) := '0' & unsigned(f(22 DOWNTO 12)) + 1;
BEGIN
    IF (to_integer(exp) < 102) THEN
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
-- Function to convert real to IEEE-754
FUNCTION real_to_float(r : real) RETURN STD_LOGIC_VECTOR IS
    CONSTANT man_width32 : INTEGER := 23;
    CONSTANT exp_width32 : INTEGER := 8;
    CONSTANT precision32 : INTEGER := 32;
    VARIABLE exp : INTEGER := 0;
    VARIABLE mantissa : real := ABS(r);
    VARIABLE sign : STD_LOGIC := '0';
    VARIABLE mantissa_bits : STD_LOGIC_VECTOR(man_width32 - 1 DOWNTO 0) := (OTHERS => '0');
    VARIABLE exponent_bits : STD_LOGIC_VECTOR(exp_width32 - 1 DOWNTO 0) := (OTHERS => '0');
    VARIABLE result : STD_LOGIC_VECTOR(precision32 - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN
    -- Add conversion logic here
    IF r = 0.0 THEN
        RETURN result;
    ELSE
        IF (r < 0.0) THEN
            sign := '1';
        ELSE
            sign := '0';
        END IF;
        WHILE mantissa >= 2.0 LOOP
            mantissa := mantissa / 2.0;
            exp := exp + 1;
        END LOOP;
        WHILE mantissa < 1.0 LOOP
            mantissa := mantissa * 2.0;
            exp := exp - 1;
        END LOOP;

        -- Bias the exponent
        exp := exp + 127;

        -- Convert mantissa to binary
        mantissa_bits := STD_LOGIC_VECTOR(to_unsigned(INTEGER(mantissa * 2.0 ** 23), 23));
        exponent_bits := STD_LOGIC_VECTOR(to_unsigned(exp, 8));

        -- Combine to form FP32
        result := sign & exponent_bits & mantissa_bits;
        RETURN result;
    END IF;
END FUNCTION;
END PACKAGE BODY;