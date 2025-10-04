----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/15/2025 05:42:33 PM
-- Design Name: systolic array
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
-- Optimized MAC_external_mode_pq for Timing Closure
-- Key optimizations:
-- 1. Reduced combinational logic depth
-- 2. Pre-computed constants and flags
-- 3. Simplified conditional chains
-- 4. Fast path selection
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY MAC_external_mode_pq IS
    GENERIC (
        precision_in : INTEGER RANGE 0 TO 32;
        precision_out : INTEGER RANGE 0 TO 64;
        ex_width_in : INTEGER RANGE 0 TO 16;
        man_width_in : INTEGER RANGE 0 TO 64;
        ex_width_out : INTEGER RANGE 0 TO 16;
        man_width_out : INTEGER RANGE 0 TO 64;
        cut : INTEGER RANGE 0 TO 32;
        offset : INTEGER RANGE 0 TO 32
    );
    PORT (
        a : IN STD_LOGIC_VECTOR (precision_in - 1 DOWNTO 0);
        b : IN STD_LOGIC_VECTOR (precision_in - 1 DOWNTO 0);
        c : IN STD_LOGIC_VECTOR (precision_out - 1 DOWNTO 0);
        modein : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        clk, n_rst : IN STD_LOGIC;
        sumout : OUT STD_LOGIC_VECTOR (precision_out - 1 DOWNTO 0);
        A_zero_in, A_NaN_in, A_inf_in : IN STD_LOGIC;
        B_zero_in, BNaN_in, Binf_in : IN STD_LOGIC

    );
    ATTRIBUTE CLOCK_BUFFER_TYPE : STRING;
    ATTRIBUTE CLOCK_BUFFER_TYPE OF modein : SIGNAL IS "NONE";
END MAC_external_mode_pq;

ARCHITECTURE Behavioral OF MAC_external_mode_pq IS

    -- Component declarations (same as original)
    COMPONENT kacy_mul_p_q
        GENERIC (
            width : INTEGER;
            cut : INTEGER);
        PORT (
            u : IN STD_LOGIC_VECTOR(width - 1 DOWNTO 0);
            v : IN STD_LOGIC_VECTOR(width - 1 DOWNTO 0);
            is_skip : STD_LOGIC;
            is_full : STD_LOGIC; -- ""
            is_skip_bd : STD_LOGIC;
            is_ac_only : STD_LOGIC;
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

    -- Pre-computed constants
    CONSTANT bias_out : unsigned(ex_width_out - 1 DOWNTO 0) := to_unsigned(2 ** (ex_width_out - 1) - 1, ex_width_out);
    CONSTANT bias_in : unsigned(ex_width_out - 1 DOWNTO 0) := to_unsigned(2 ** (ex_width_in - 1) - 1, ex_width_out);
    CONSTANT exp_bias_diff : unsigned(ex_width_out - 1 DOWNTO 0) := bias_out - bias_in;
    CONSTANT exp_bias_sum : unsigned(ex_width_out - 1 DOWNTO 0) := bias_out + bias_in;
    CONSTANT exp_ab_bias_adj : unsigned(ex_width_out - 1 DOWNTO 0) := bias_out - bias_in - bias_in;
    CONSTANT C_inf_bound : unsigned(ex_width_out - 1 DOWNTO 0) := to_unsigned(2 ** (ex_width_out) - 1, ex_width_out);

    -- Mode decoding (reduce combinational logic)
    SIGNAL is_skip, is_full, is_skip_bd, is_ac_only : STD_LOGIC;

    -- Input parsing (simplified)
    SIGNAL exp_a_raw, exp_b_raw, exp_c_raw : unsigned(ex_width_out - 1 DOWNTO 0);
    SIGNAL man_a_raw, man_b_raw : unsigned(man_width_in - 1 DOWNTO 0);
    SIGNAL man_c_raw : unsigned(man_width_out - 1 DOWNTO 0);
    SIGNAL sign_a, sign_b, sign_c : STD_LOGIC;

    -- Fast zero detection
    SIGNAL a_is_zero, b_is_zero, c_is_zero : STD_LOGIC;
    SIGNAL ab_is_zero : STD_LOGIC;
    SIGNAL is_nan, is_inf : STD_LOGIC;
    SIGNAL C_is_inf, C_is_NaN : STD_LOGIC;

    -- Normalized values with reduced logic
    SIGNAL exp_a_norm, exp_b_norm, exp_c_norm : unsigned(ex_width_out - 1 DOWNTO 0);
    SIGNAL man_a_norm, man_b_norm : STD_LOGIC_VECTOR(man_width_in DOWNTO 0);
    SIGNAL man_c_norm : STD_LOGIC_VECTOR(man_width_out DOWNTO 0);

    -- Multiplier signals
    SIGNAL exp_ab : unsigned(ex_width_out - 1 DOWNTO 0);
    SIGNAL ab_mantissa : STD_LOGIC_VECTOR((man_width_in + 1) * 2 - 1 DOWNTO 0);
    SIGNAL sign_ab : STD_LOGIC;
    SIGNAL ac_e : STD_LOGIC;
    SIGNAL ad_e : STD_LOGIC;
    SIGNAL bc_e : STD_LOGIC;
    SIGNAL bd_e : STD_LOGIC;

    -- Adder control signals (pre-computed)
    SIGNAL use_mult_result, use_c_only, output_zero : STD_LOGIC;
    SIGNAL z_sum : STD_LOGIC;
    SIGNAL abadd_mantissa : STD_LOGIC_VECTOR(man_width_out DOWNTO 0);

    -- Final result
    SIGNAL NaN_inf_result : STD_LOGIC_VECTOR(precision_out - 1 DOWNTO 0);
    SIGNAL sum_result : STD_LOGIC_VECTOR(precision_out - 1 DOWNTO 0);

    -- Optimization attributes
    ATTRIBUTE KEEP : STRING;
    ATTRIBUTE MAX_FANOUT : INTEGER;
    --    attribute MAX_FANOUT of modein : signal is 18;
    ATTRIBUTE CLOCK_BUFFER_TYPE OF sumout : SIGNAL IS "NONE";
    --    attribute MAX_FANOUT         of sumout : signal is 32;

BEGIN

    -- OPTIMIZATION 1: Fast mode decoding (single level logic)
    mode_decode : PROCESS (modein)
    BEGIN
        is_skip <= modein(1) AND modein(0); -- "11"
        is_full <= NOT modein(1) AND NOT modein(0); -- "00"
        is_skip_bd <= NOT modein(1) AND modein(0); -- "01"  
        is_ac_only <= modein(1) AND NOT modein(0); -- "10"
    END PROCESS;
    if_proc : PROCESS (modein)
    BEGIN
        IF modein = "00" THEN -- full compute
            ac_e <= '1';
            ad_e <= '1';
            bc_e <= '1';
            bd_e <= '1';
        ELSIF modein = "01" THEN -- skip bd
            ac_e <= '1';
            ad_e <= '1';
            bc_e <= '1';
            bd_e <= '0';
        ELSIF modein = "10" THEN -- ac only
            ac_e <= '1';
            ad_e <= '0';
            bc_e <= '0';
            bd_e <= '0';
        ELSE -- full skip
            ac_e <= '0';
            ad_e <= '0';
            bc_e <= '0';
            bd_e <= '0';
        END IF;
    END PROCESS;
    -- OPTIMIZATION 2: Simplified input parsing (parallel, not sequential)

    exp_a_norm <= resize(unsigned(a(precision_in - 2 DOWNTO man_width_in)), ex_width_out);
    exp_b_norm <= resize(unsigned(b(precision_in - 2 DOWNTO man_width_in)), ex_width_out);
    exp_c_raw <= unsigned(c(precision_out - 2 DOWNTO man_width_out));

    man_a_raw <= unsigned(a(man_width_in - 1 DOWNTO 0));
    man_b_raw <= unsigned(b(man_width_in - 1 DOWNTO 0));
    man_a_norm <= ('1' & STD_LOGIC_VECTOR(man_a_raw));
    man_b_norm <= ('1' & STD_LOGIC_VECTOR(man_b_raw));
    man_c_raw <= unsigned(c(man_width_out - 1 DOWNTO 0));

    sign_a <= a(precision_in - 1);
    sign_b <= b(precision_in - 1);
    sign_c <= c(precision_out - 1);

    a_is_zero <= A_zero_in;
    b_is_zero <= B_zero_in;
    c_is_zero <= '1' WHEN (exp_c_raw <= exp_bias_diff AND man_c_raw = 0) ELSE
        '0';
    ab_is_zero <= a_is_zero OR b_is_zero;

    C_NaN_INF : PROCESS (exp_c_raw, man_c_raw)
    BEGIN
        IF exp_c_raw = C_inf_bound THEN
            IF man_c_raw = 0 THEN
                C_is_NaN <= '0';
                C_is_inf <= '1';
            ELSE
                C_is_NaN <= '1';
                C_is_inf <= '0';
            END IF;
        ELSE
            C_is_NaN <= '0';
            C_is_inf <= '0';
        END IF;
    END PROCESS;
    -- OPTIMIZATION 4: Simplified normalization (reduced conditional depth)
    normalize_inputs : PROCESS (exp_c_raw, man_c_raw, c_is_zero)
    BEGIN
        -- C normalization (parallel to A,B)
        IF c_is_zero = '1' THEN
            exp_c_norm <= (OTHERS => '0');
            man_c_norm <= (OTHERS => '0');
        ELSE
            exp_c_norm <= exp_c_raw;
            man_c_norm <= ('1' & STD_LOGIC_VECTOR(man_c_raw));
        END IF;
    END PROCESS;

    -- OPTIMIZATION 5: Pre-compute exponent result (reduce adder critical path)
    exp_compute : PROCESS (exp_a_norm, exp_b_norm)
    BEGIN
        exp_ab <= exp_a_norm + exp_b_norm + exp_ab_bias_adj;
    END PROCESS;

    -- Sign computation (simple XOR)
    sign_ab <= sign_a XOR sign_b;
    is_inf <= A_inf_in OR Binf_in OR C_is_inf;
    is_NaN <= A_NaN_in OR BNaN_in OR C_is_NaN OR (a_is_zero AND b_is_zero);
    -- OPTIMIZATION 6: Fast control signal generation

    -- Pre-compute control signals to reduce logic in final stage
    use_mult_result <= NOT is_skip;
    use_c_only <= is_skip AND NOT(c_is_zero OR is_inf OR is_NaN);
    output_zero <= ab_is_zero AND c_is_zero;
    z_sum <= c_is_zero;

    -- Multiplier instantiation (same as original but with optimized inputs)
    kacy : ENTITY work.kacy_mul_p_q
        GENERIC MAP(
            width => man_width_in + 1,
            cut => cut
        )
        PORT MAP(
            u => man_a_norm,
            v => man_b_norm,
            --            mode => modein,
            ac_e => ac_e,
            ad_e => ad_e,
            bc_e => bc_e,
            bd_e => bd_e,
            mantissa => ab_mantissa--(man_width_out downto (man_width_out+1)-(man_width_in+1)*2)
        );

    -- OPTIMIZATION 7: Simplified adder input selection
    adder_input_mux : PROCESS (use_mult_result, ab_mantissa, man_c_norm, exp_ab, exp_c_norm, sign_ab, sign_c, z_sum)
    BEGIN
        IF use_mult_result = '1' THEN
            -- Normal MAC operation
            abadd_mantissa <= ab_mantissa & STD_LOGIC_VECTOR(to_unsigned(0, (man_width_out + 1) - (man_width_in + 1) * 2));
        ELSE
            -- Simplified paths for edge cases
            abadd_mantissa <= (OTHERS => '0');
        END IF;
    END PROCESS;

    -- Floating point adder (optimized internally)
    fp_add : add_fp
    GENERIC MAP(precision => precision_out, man_width => man_width_out)
    PORT MAP(
        exp_ain => exp_c_norm,
        exp_bin => exp_ab,
        man_ain => man_c_norm,
        man_bin => abadd_mantissa,
        sign_a => sign_c,
        sign_b => sign_ab,
        z_sum => z_sum,
        result => sum_result
    );
    NAN_INF : PROCESS (is_NaN, is_inf, sign_ab)
        VARIABLE exp : STD_LOGIC_VECTOR(ex_width_out - 1 DOWNTO 0);
        VARIABLE man : STD_LOGIC_VECTOR(man_width_out - 1 DOWNTO 0);
    BEGIN
        IF is_NaN = '1' THEN
            exp := (OTHERS => '1');
            man := (OTHERS => '1');
        ELSIF is_inf = '1' THEN
            exp := (OTHERS => '1');
            man := (OTHERS => '0');
        ELSE
            exp := (OTHERS => '0');
            man := (OTHERS => '0');
        END IF;
        NaN_inf_result <= sign_ab & exp & man;
    END PROCESS;
    -- OPTIMIZATION 8: Fast output selection (reduced multiplexing)
    output_reg : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF n_rst = '0' THEN
                sumout <= (OTHERS => '0');
            ELSE
                -- Simplified output selection based on pre-computed control signals
                IF is_nan = '1' OR is_inf = '1' THEN
                    sumout <= NaN_inf_result;
                ELSIF output_zero = '1' THEN
                    sumout <= (OTHERS => '0');
                ELSIF use_c_only = '1' THEN
                    sumout <= sign_c & STD_LOGIC_VECTOR(exp_c_norm) & man_c_norm(man_width_out - 1 DOWNTO 0);
                ELSE
                    sumout <= sum_result;
                END IF;
            END IF;
        END IF;
    END PROCESS;

END Behavioral;