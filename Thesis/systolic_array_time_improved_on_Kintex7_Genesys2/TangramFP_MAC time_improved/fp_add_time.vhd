----------------------------------------------------------------------------------
-- Fixed and Optimized fp_add.vhd for Better Timing
-- Key fixes:
-- 1. Fixed missing exp_a initialization
-- 2. Corrected zero_sub logic
-- 3. Optimized variable flag usage
-- 4. Reduced combinational depth
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.tools.ALL;

ENTITY add_fp IS
    GENERIC (
        precision : INTEGER RANGE 0 TO 64;
        man_width : INTEGER RANGE 0 TO 64;
        exp_width : INTEGER RANGE 0 TO 31
    );
    PORT (
        exp_ain, exp_bin : IN unsigned(exp_width - 1 DOWNTO 0);
        man_ain, man_bin : IN STD_LOGIC_VECTOR(man_width DOWNTO 0);
        sign_a, sign_b : IN STD_LOGIC;
        z_sum : STD_LOGIC;
        result : OUT STD_LOGIC_VECTOR(precision - 1 DOWNTO 0)
    );
END add_fp;

ARCHITECTURE Behavioral OF add_fp IS

    CONSTANT add : STD_LOGIC := '0';
    CONSTANT sub : STD_LOGIC := '1';
    -- No MAX_SHIFT needed - mantissa width is the natural limit

    SIGNAL operation : STD_LOGIC := '0';
    SIGNAL exp_ab, exp_ab_r : unsigned(exp_width - 1 DOWNTO 0);
    SIGNAL man_ab : unsigned(man_width + 1 DOWNTO 0);
    SIGNAL man_result : unsigned(man_width - 1 DOWNTO 0);
    SIGNAL sign_ab : STD_LOGIC;
    SIGNAL temp_result : unsigned(man_width + 1 DOWNTO 0);
    SIGNAL shift_count : NATURAL RANGE 0 TO 54 := 0;
    SIGNAL shift_vec : STD_LOGIC_VECTOR (5 DOWNTO 0);
    SIGNAL enable_lzc : STD_LOGIC;
    SIGNAL zero_sub : STD_LOGIC;
    SIGNAL overflow_var : STD_LOGIC;
    SIGNAL underflow_var : STD_LOGIC;
    SIGNAL manabz : STD_LOGIC;
    SIGNAL exp_a, exp_b : unsigned(exp_width - 1 DOWNTO 0);
    SIGNAL man_a, man_b, man_a_aligned, man_b_aligned : unsigned(man_width + 1 DOWNTO 0);
BEGIN

    operation <= sign_a XOR sign_b;
    exp_a <= exp_ain;
    exp_b <= exp_bin + 1 WHEN man_bin(man_width) = '1' ELSE
        exp_bin;
    man_a <= unsigned('0' & man_ain);
    man_b <= unsigned(man_bin & '0') WHEN man_bin(man_width) = '0' AND man_bin(man_width - 1) = '1' ELSE
        unsigned('0' & man_bin);

    PROCESS (exp_a, exp_b, man_a, man_b, sign_a, sign_b, z_sum, operation)
    BEGIN
        zero_sub <= '0';
        exp_ab <= exp_a;
        sign_ab <= '0';
        man_a_aligned <= man_a;
        man_b_aligned <= man_b;
        IF z_sum = '0' THEN
            IF (exp_a = exp_b) AND operation = sub THEN
                IF (man_a > man_b) THEN
                    man_a_aligned <= man_a;
                    man_b_aligned <= man_b;
                    exp_ab <= exp_a;
                    sign_ab <= sign_a;
                ELSIF (man_a < man_b) THEN
                    man_a_aligned <= man_b;
                    man_b_aligned <= man_a;
                    exp_ab <= exp_b;
                    sign_ab <= sign_b;
                ELSIF (man_a = man_b) THEN
                    zero_sub <= '1';
                    sign_ab <= '0';
                END IF;

            ELSIF (exp_a > exp_b) THEN
                man_b_aligned <= shift_right(man_b, to_integer(exp_a - exp_b));
                man_a_aligned <= man_a;
                exp_ab <= exp_a;
                sign_ab <= sign_a;
            ELSE
                man_b_aligned <= shift_right(man_a, to_integer(exp_b - exp_a));
                man_a_aligned <= man_b;
                exp_ab <= exp_b;
                sign_ab <= sign_b;
            END IF;
        ELSE
            sign_ab <= sign_b;
            exp_ab <= exp_b;
        END IF;
    END PROCESS;
    -- perform  addition or subtraction
    PROCESS (operation, man_a_aligned, man_b_aligned, z_sum, man_b)
    BEGIN
        man_ab <= (OTHERS => '0');
        IF z_sum = '1' THEN
            man_ab <= man_b;
        ELSE
            IF (operation = add) THEN
                man_ab <= man_a_aligned + man_b_aligned;
            ELSIF zero_sub = '0' THEN
                man_ab <= man_a_aligned - man_b_aligned;
            END IF;
        END IF;
    END PROCESS;
    -- Leading Zero Counter (unchanged)
    LZC64 : IF precision = 64 GENERATE
        LZC54 : ENTITY work.lzc_54(rtl54)
            GENERIC MAP(N => man_width + 1)
            PORT MAP(
                mantissa => STD_LOGIC_VECTOR(man_ab),
                enable => enable_lzc,
                shift_count => shift_vec
            );
    END GENERATE;

    LZC32 : IF precision = 32 GENERATE
        LZC54 : ENTITY work.lzc_54(rtl25)
            GENERIC MAP(N => man_width + 1)
            PORT MAP(
                mantissa => STD_LOGIC_VECTOR(man_ab),
                enable => enable_lzc,
                shift_count => shift_vec
            );
    END GENERATE;

    -- LZC control (optimized)
    lzc_zeros : PROCESS (operation, zero_sub, z_sum)
    BEGIN
        enable_lzc <= (operation AND NOT zero_sub) OR z_sum;
    END PROCESS;

    shift_count <= to_integer(unsigned(shift_vec));

    -- Normalization (optimized with variables)
    normalize : PROCESS (man_ab, operation, shift_count, z_sum, exp_ab, zero_sub)

        VARIABLE temp_resulten : unsigned(man_width + 1 DOWNTO 0);
    BEGIN
        IF operation = add THEN
            IF overflow_var = '1' THEN
                temp_resulten := man_ab + 1; -- rounding
            ELSE
                temp_resulten := man_ab;
            END IF;
        ELSIF (operation = sub AND zero_sub = '0') OR z_sum = '1' THEN
            IF underflow_var = '1' THEN
                temp_resulten := shift_left(man_ab, to_integer(exp_ab));
            ELSIF manabz = '1' THEN
                temp_resulten := (OTHERS => '0');
            ELSE
                temp_resulten := shift_left(man_ab, shift_count);
            END IF;
        ELSE
            temp_resulten := (OTHERS => '0');
        END IF;
        temp_result <= temp_resulten;
    END PROCESS;

    -- Final result formatting (optimized)
    final_format : PROCESS (temp_result, exp_ab, man_ab, operation, shift_count, zero_sub)

        VARIABLE exp_ab_ren : unsigned(exp_width - 1 DOWNTO 0);
        VARIABLE man_resulten : unsigned(man_width - 1 DOWNTO 0);
    BEGIN
        IF operation = add THEN
            IF overflow_var = '1' THEN
                man_resulten := temp_result(man_width DOWNTO 1);
                exp_ab_ren := exp_ab + 1;
            ELSE
                man_resulten := temp_result(man_width - 1 DOWNTO 0);
                exp_ab_ren := exp_ab;
            END IF;
        ELSIF operation = sub AND zero_sub = '0' THEN
            IF underflow_var = '1' THEN
                exp_ab_ren := (OTHERS => '0');
                man_resulten := temp_result(man_width DOWNTO 1);
            ELSIF manabz = '1' THEN
                man_resulten := (OTHERS => '0');
                exp_ab_ren := exp_ab;
            ELSE
                man_resulten := temp_result(man_width DOWNTO 1);
                exp_ab_ren := exp_ab - (shift_count - 1);
            END IF;
        ELSE
            man_resulten := (OTHERS => '0');
            exp_ab_ren := (OTHERS => '0');
        END IF;
        man_result <= man_resulten;
        exp_ab_r <= exp_ab_ren;
    END PROCESS;

    over_underflow : PROCESS (man_ab, exp_ab, shift_count)
    BEGIN
        overflow_var <= man_ab(man_width + 1);
        underflow_var <= '1' WHEN exp_ab < shift_count ELSE
            '0';
    END PROCESS;

    result <= STD_LOGIC_VECTOR(sign_ab & exp_ab_r & man_result);

END Behavioral;