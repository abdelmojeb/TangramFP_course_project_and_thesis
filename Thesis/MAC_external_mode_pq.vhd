----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/15/2025 05:42:33 PM
-- Design Name: 
-- Module Name: MAC_external_mode_pq - Behavioral
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
USE work.ALL;
USE IEEE.NUMERIC_STD.ALL;
ENTITY MAC_external_mode_pq IS
    GENERIC (
        precision_in : INTEGER RANGE 0 TO 32;--:=16; 
        precision_out : INTEGER RANGE 0 TO 64;--:=32;
        ex_width_in : INTEGER RANGE 0 TO 16;--:=5;
        man_width_in : INTEGER RANGE 0 TO 64;--:= 10;
        ex_width_out : INTEGER RANGE 0 TO 16;--:=8;
        man_width_out : INTEGER RANGE 0 TO 64;--:= 23;
        cut : INTEGER RANGE 0 TO 32;-- := 5;
        offset : INTEGER RANGE 0 TO 32-- := 0
    );
    PORT (
        a : IN STD_LOGIC_VECTOR (precision_in - 1 DOWNTO 0);
        b : IN STD_LOGIC_VECTOR (precision_in - 1 DOWNTO 0);
        c : IN STD_LOGIC_VECTOR (precision_out - 1 DOWNTO 0);
        modein : IN STD_LOGIC_VECTOR(1 DOWNTO 0); --systolic array input
        clk, n_rst : IN STD_LOGIC;
        sumout : OUT STD_LOGIC_VECTOR (precision_out - 1 DOWNTO 0));
    --   attribute dont_touch : string;
    --   attribute dont_touch of MAC_external_mode_pq : entity is "true";         
END MAC_external_mode_pq;

ARCHITECTURE Behavioral OF MAC_external_mode_pq IS

    COMPONENT kacy_mul_p_q GENERIC (width : INTEGER;
        cut : INTEGER);
        PORT (
            u : IN STD_LOGIC_VECTOR(width - 1 DOWNTO 0);
            v : IN STD_LOGIC_VECTOR(width - 1 DOWNTO 0);
            mode : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            mantissa : OUT STD_LOGIC_VECTOR(2 * width - 1 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT add_fp IS
        GENERIC (
            precision : INTEGER := precision_out;
            man_width : INTEGER := man_width_out;
            exp_width : INTEGER RANGE 0 TO 31 := ex_width_out);
        PORT (
            exp_ain, exp_bin : IN unsigned(ex_width_out - 1 DOWNTO 0);
            man_ain, man_bin : IN STD_LOGIC_VECTOR(man_width_out DOWNTO 0);
            sign_a, sign_b : IN STD_LOGIC;
            z_sum : STD_LOGIC;
            result : OUT STD_LOGIC_VECTOR(precision - 1 DOWNTO 0));
    END COMPONENT;
    --exponent comparison constants 
    CONSTANT bias_out : unsigned(ex_width_out - 1 DOWNTO 0) := to_unsigned(2 ** (ex_width_out - 1) - 1, ex_width_out);
    CONSTANT bias_in : unsigned(ex_width_out - 1 DOWNTO 0) := to_unsigned(2 ** (ex_width_in - 1) - 1, ex_width_out);
    CONSTANT FULL : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    CONSTANT SKIP_BD : STD_LOGIC_VECTOR(1 DOWNTO 0) := "01";
    CONSTANT AC_ONLY : STD_LOGIC_VECTOR(1 DOWNTO 0) := "10";
    CONSTANT SKIP : STD_LOGIC_VECTOR(1 DOWNTO 0) := "11";
    CONSTANT thr1 : signed(ex_width_out - 1 DOWNTO 0) := to_signed((cut + offset), ex_width_out);
    CONSTANT thr2 : signed(ex_width_out - 1 DOWNTO 0) := to_signed(man_width_in, ex_width_out);
    SIGNAL exp_an : unsigned(ex_width_out - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL exp_bn : unsigned(ex_width_out - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL exp_cn : unsigned(ex_width_out - 1 DOWNTO 0) := (OTHERS => '0');

    SIGNAL exp_ab : unsigned(ex_width_out - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL exp_a : unsigned(ex_width_out - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL exp_b : unsigned(ex_width_out - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL exp_c : unsigned(ex_width_out - 1 DOWNTO 0) := (OTHERS => '0');
    --    signal ex_cn_cmp, ex_ab_cmp :signed(ex_width_out downto 0);

    SIGNAL mantissa_a, mantissa_b : unsigned(man_width_in - 1 DOWNTO 0);
    SIGNAL mantissa_c : unsigned(man_width_out - 1 DOWNTO 0);
    SIGNAL mantissa_a_norm, mantissa_b_norm, u, v : STD_LOGIC_VECTOR (man_width_in DOWNTO 0);
    SIGNAL mantissa_c_norm : STD_LOGIC_VECTOR (man_width_out DOWNTO 0) := (OTHERS => '0');

    SIGNAL mode : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL ab : STD_LOGIC_VECTOR(man_width_out DOWNTO 0) := (OTHERS => '0');

    --    signal ab_result : std_logic_vector(precision_out-1 downto 0) := (others => '0');    
    SIGNAL sum_pre_out : STD_LOGIC_VECTOR(precision_out - 1 DOWNTO 0);
    -- input to adder
    SIGNAL sum_32_in, ab_add_in : STD_LOGIC_VECTOR(man_width_out DOWNTO 0);
    SIGNAL sign_ab, sign_c, sign_ab_ad, sign_c_ad : STD_LOGIC := '0';
    SIGNAL exp_cn_addin, exp_ab_addin : unsigned(ex_width_out - 1 DOWNTO 0);
    -- falgs
    SIGNAL a_zero, b_zero : STD_LOGIC;
    SIGNAL z_mult, nan_input, z_sum : STD_LOGIC;
    SIGNAL is_skip : STD_LOGIC;
    --    signal mode_trigger : std_logic := '0';

    -----------------------------------------------------------------------------------------------------------------------------------

    ATTRIBUTE keep : STRING;
    --attribute keep of  exp_an : signal   is "true";
    --attribute keep of  exp_cn : signal   is "true";
    --attribute keep of  exp_bn : signal   is "true";
    --attribute keep of  mantissa_c_norm : signal   is "true";
    --attribute keep of  mantissa_c : signal   is "true";
    --attribute keep of  mantissa_a : signal   is "true";
    --attribute keep of  mantissa_b : signal   is "true";
    --attribute keep of sign_c_ad : signal is "true";
    ATTRIBUTE MAX_FANOUT : INTEGER;
    ATTRIBUTE MAX_FANOUT OF modein : SIGNAL IS 10;
BEGIN

    mode <= modein;
    is_skip <= '1' WHEN modein = "11" ELSE
        '0';
    --input sanitizing
    sanitize : PROCESS (a, b, c)
    BEGIN
        mantissa_a <= unsigned(a(man_width_in - 1 DOWNTO 0));
        mantissa_b <= unsigned(b(man_width_in - 1 DOWNTO 0));
        mantissa_c <= unsigned(c(man_width_out - 1 DOWNTO 0));

        exp_a <= resize(unsigned(a(precision_in - 2 DOWNTO man_width_in)), ex_width_out);
        exp_b <= resize(unsigned(b(precision_in - 2 DOWNTO man_width_in)), ex_width_out);
        exp_c <= resize(unsigned(c(precision_out - 2 DOWNTO man_width_out)), ex_width_out);-- + to_unsigned(112,ex_width_out);  --here  
    END PROCESS;

    subnormal_a : PROCESS (a, exp_a, mantissa_a)
    BEGIN
        IF (exp_a /= 0) THEN --and mantissa_a /= 0
            mantissa_a_norm <= '1' & STD_LOGIC_VECTOR (mantissa_a);
            exp_an <= exp_a;
            a_zero <= '0';
        ELSIF (exp_a = 0 AND mantissa_a /= 0) THEN
            mantissa_a_norm <= (OTHERS => '0');
            exp_an <= to_unsigned(1, ex_width_out);
            a_zero <= '0';
        ELSE
            mantissa_a_norm <= (OTHERS => '0');
            exp_an <= to_unsigned(0, ex_width_out);
            a_zero <= '1';
        END IF;
    END PROCESS;
    subnormal_b : PROCESS (b, exp_b, mantissa_b)
    BEGIN
        IF (exp_b /= 0) THEN--and mantissa_b /= 0
            mantissa_b_norm <= '1' & STD_LOGIC_VECTOR(mantissa_b);
            exp_bn <= exp_b;
            b_zero <= '0';
        ELSIF (exp_b = 0 AND mantissa_b /= 0) THEN
            mantissa_b_norm <= (OTHERS => '0');
            exp_bn <= to_unsigned(1, ex_width_out);
            b_zero <= '0';
        ELSE
            mantissa_b_norm <= (OTHERS => '0');
            exp_bn <= to_unsigned(0, ex_width_out);
            b_zero <= '1';

        END IF;
    END PROCESS;
    zero_ab : PROCESS (a_zero, b_zero)
    BEGIN
        IF (a_zero = '1' OR b_zero = '1') THEN
            z_mult <= '1';
        ELSE
            z_mult <= '0';
        END IF;
    END PROCESS;

    nan_operation : PROCESS (exp_ab, exp_a, exp_b, exp_c)
    BEGIN
        IF (exp_a > bias_in * 2 OR
            exp_b > bias_in * 2 OR
            exp_c > (bias_in + bias_out) OR exp_ab > (bias_in + bias_out)) THEN
            nan_input <= '1';
        ELSE
            nan_input <= '0';
        END IF;
    END PROCESS;

    input_c : PROCESS (c, exp_c, mantissa_c, a(precision_in - 1), b(precision_in - 1), c(precision_out - 1))
    BEGIN
        sign_ab_ad <= a(precision_in - 1) XOR b(precision_in - 1);
        IF (exp_c > (bias_out - bias_in)) THEN--and mantissa_c > 0
            mantissa_c_norm <= STD_LOGIC_VECTOR('1' & mantissa_c);
            exp_cn <= exp_c;
            sign_c_ad <= c(precision_out - 1);
            z_sum <= '0';
        ELSIF (exp_c = (bias_out - bias_in) AND mantissa_c > 0) THEN
            mantissa_c_norm <= (OTHERS => '0');
            exp_cn <= to_unsigned(1, ex_width_out);
            sign_c_ad <= c(precision_out - 1);
            z_sum <= '0';
        ELSE
            mantissa_c_norm <= (OTHERS => '0');
            exp_cn <= to_unsigned(0, ex_width_out);
            sign_c_ad <= '0';
            z_sum <= '1';

        END IF;
    END PROCESS;

    --multiplication 
    ab_exp : PROCESS (exp_an, exp_bn)
    BEGIN
        exp_ab <= exp_an + exp_bn + (bias_out - bias_in - bias_in);

    END PROCESS;
    kacy : kacy_mul_p_q
    GENERIC MAP(
        width => man_width_in + 1,
        cut => cut)
    PORT MAP(
        u => mantissa_a_norm, v => mantissa_b_norm,
        mode => modein, --modein comes from systolic array
        mantissa => ab(man_width_out DOWNTO (man_width_out + 1) - (man_width_in + 1) * 2));
    ------------------------------------------------------------------------------------------------------------        
    -- Addition
    fp_add : add_fp
    GENERIC MAP(precision => precision_out, man_width => man_width_out)
    PORT MAP(
        exp_ain => exp_cn,
        exp_bin => exp_ab,
        man_ain => mantissa_c_norm,
        man_bin => ab,
        sign_a => sign_c_ad,
        sign_b => sign_ab_ad,
        z_sum => z_sum,
        result => sum_pre_out);
    --prepare output to 32 bit
    scaledown : PROCESS (clk)
    BEGIN

        IF rising_edge(clk) THEN
            IF n_rst = '0' THEN
                sumout <= (OTHERS => '0');
            ELSE
                IF (nan_input = '1') THEN
                    sumout <= (OTHERS => '1');--nan_value;
                ELSE
                    IF (is_skip = '1' OR(z_mult = '1' AND z_sum = '0')) THEN
                        sumout <= sign_c_ad & STD_LOGIC_VECTOR (exp_cn) & mantissa_c_norm(man_width_out - 1 DOWNTO 0);
                    ELSIF (z_mult = '0') THEN
                        sumout <= sum_pre_out;
                    ELSE
                        sumout <= (OTHERS => '0');
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

END Behavioral;