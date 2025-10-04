----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/05/2025 02:55:38 PM
-- Design Name: Systolic array
-- Module Name: sysA - Behavioral
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
--perform B*A multiplication B is fixed A rows are fed each clock cycles

USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;
USE work.my_types.ALL;
USE work.tools.ALL;
ENTITY systolic_array_pipe1 IS

    PORT (
        clk : IN STD_LOGIC;
        n_rst : IN STD_LOGIC;
        A_colmn : IN N_1_prein;
        B_in : IN STD_LOGIC_VECTOR(Pre_in - 1 DOWNTO 0);
        col : IN INTEGER RANGE 0 TO N;
        row : IN INTEGER RANGE 0 TO N;
        enB : IN STD_LOGIC;
        rwB : IN STD_LOGIC;
        sum : OUT N_1_Prein;
        mode : IN mode_array;
        B_zero : STD_LOGIC;

        B_NaN : STD_LOGIC;
        B_inf : STD_LOGIC;
        A_inf : STD_LOGIC;
        A_NaN : STD_LOGIC;

        A_zero_col : status_col;
        en : STD_LOGIC
    );
    --    attribute dont_touch : string;
    --    attribute dont_touch of systolic_array_pipe1 : entity is "true";
END systolic_array_pipe1;

ARCHITECTURE rtl OF systolic_array_pipe1 IS
    ATTRIBUTE DONT_TOUCH : STRING;
    --mac ip
    COMPONENT MAC_external_mode_pq IS
        GENERIC (
            precision_in : INTEGER RANGE 0 TO 32 := Pre_in;
            precision_out : INTEGER RANGE 0 TO 64 := Pre_out;
            ex_width_in : INTEGER RANGE 0 TO 16 := ex_width_in;
            man_width_in : INTEGER RANGE 0 TO 32 := man_width_in;
            ex_width_out : INTEGER RANGE 0 TO 16 := ex_width_out;
            man_width_out : INTEGER RANGE 0 TO 64 := man_width_out;
            cut : INTEGER RANGE 0 TO 32 := cut;
            offset : INTEGER RANGE 0 TO 32 := offset);
        PORT (
            a : IN STD_LOGIC_VECTOR (precision_in - 1 DOWNTO 0);
            b : IN STD_LOGIC_VECTOR (precision_in - 1 DOWNTO 0);
            c : IN STD_LOGIC_VECTOR (precision_out - 1 DOWNTO 0);
            modein : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
            clk, n_rst : IN STD_LOGIC;
            sumout : OUT STD_LOGIC_VECTOR (precision_out - 1 DOWNTO 0);
            A_zero_in, A_NaN_in, A_inf_in : IN STD_LOGIC;
            B_zero_in, BNaN_in, Binf_in : IN STD_LOGIC);
    END COMPONENT;
    --      attribute DONT_TOUCH of MAC_external_mode_pq : component is "TRUE";

    SIGNAL B_matrix : N_N_prein;
    SIGNAL C_matrix : N_N_preout; --C_matrix accumulation interconnection, Cout matrix output
    --    signal Cout : N_N_Prein;
    SIGNAL A_input, A_input1 : N_1_prein;
    SIGNAL A_pipe : A_pipeline; -- N_N_prein; -- A interconnection between PEs
    SIGNAL sum_output : N_1_prein;
    --signal sum_out_connect : N_1_preout;
    --    signal mode_buffer : N_1_mode;
    ATTRIBUTE DONT_TOUCH OF C_matrix : SIGNAL IS "TRUE";
    ATTRIBUTE DONT_TOUCH OF A_pipe : SIGNAL IS "TRUE";
    ATTRIBUTE DONT_TOUCH OF sum_output : SIGNAL IS "TRUE";
    --    attribute DONT_TOUCH of Cout : signal is "TRUE";

    -- flags of NaN,zeros and infinities
    SIGNAL B_zero_matrix : status_matrix;
    SIGNAL B_nan_row : status_col;
    SIGNAL B_inf_row : status_col;
    SIGNAL A_pipe_z, A_pipe_N, A_pipe_inf : A_flag_pipe;
    SIGNAL A_z_col, A_N_col, A_inf_col, A_z_col1, A_N_col1, A_inf_col1 : status_col;
    ATTRIBUTE CLOCK_BUFFER_TYPE : STRING;
    ATTRIBUTE MAX_FANOUT : INTEGER;
BEGIN
    RW_B : PROCESS (clk)
    BEGIN
        IF rising_edge (clk) THEN
            IF n_rst = '0' THEN
                B_matrix <= (OTHERS => (OTHERS => (OTHERS => '0')));
                B_nan_row <= (OTHERS => '0');
                B_inf_row <= (OTHERS => '0');
                B_zero_matrix <= (OTHERS => (OTHERS => '0'));
            ELSE

                IF enB = '1' THEN
                    IF rwb = '1' THEN
                        B_matrix(row, col) <= B_in;
                        B_zero_matrix (row, col) <= B_zero;
                        IF col = 0 THEN
                            B_nan_row(row) <= B_NaN;
                            B_inf_row(row) <= B_inf;
                        ELSE
                            B_nan_row(row) <= B_nan_row(row) OR B_NaN;
                            B_inf_row(row) <= B_inf_row(row) OR B_inf;

                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- propagate the modes accross levels in the systolic array 
    -- the buffer has for each row a vector that contains modes will 
    --be used for each row in b, N*2 -2 [8,6,4,2] each time will be coppied to the right bits in the vector

    -- Instantiate Processing Elements
    gen_rows : FOR i IN 0 TO N - 1 GENERATE
        SIGNAL mode_buffer_row : STD_LOGIC_VECTOR(N * (N + 1) - 1 DOWNTO 0);
        ATTRIBUTE CLOCK_BUFFER_TYPE OF mode_buffer_row : SIGNAL IS "NONE";
        --    attribute MAX_FANOUT         of mode_buffer_row : signal is 24;

    BEGIN

        --        -- propagate modes for this row
        mode_prop_row : PROCESS (clk, en)
        BEGIN
            mode_buffer_row(N * (N + 1) - 1 DOWNTO N * (N - 1)) <= mode(i);
            IF rising_edge(clk) AND en = '1' THEN
                IF n_rst = '0' THEN
                    mode_buffer_row <= (OTHERS => '1');
                ELSE
                    --                    -- insert the mode for this row

                    -- propagate the modes accross levels in the systolic array 
                    -- the buffer has for each row a vector that contains modes will 
                    --be used for each row in b, N*2 -2 [8,6,4,2] each time will be coppied to the right bits in the vector

                    -- shrinking shift
                    FOR k IN 0 TO N - 2 LOOP
                        mode_buffer_row((k + 1) * (k + 2) - 1 DOWNTO k * (k + 1)) <=
                        mode_buffer_row((k + 2) * (k + 3) - 1 DOWNTO (k + 1) * (k + 2) + 2);
                    END LOOP;
                END IF;
            END IF;
        END PROCESS;

        gen_cols : FOR j IN 0 TO N - 1 GENERATE

            SIGNAL sum_in, sum_out : STD_LOGIC_VECTOR(Pre_out - 1 DOWNTO 0);
            SIGNAL A_in, B_in : STD_LOGIC_VECTOR(Pre_in - 1 DOWNTO 0);
            SIGNAL mode_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
            SIGNAL A_zero_in, A_NaN_in, A_inf_in : STD_LOGIC;
            SIGNAL B_zero_in, BNaN_in, Binf_in : STD_LOGIC;
            ATTRIBUTE HU_SET : STRING;
            ATTRIBUTE HU_SET OF mode_in : SIGNAL IS "my_group";
            ATTRIBUTE HU_SET OF sum_out : SIGNAL IS "my_group";
            ATTRIBUTE CLOCK_BUFFER_TYPE : STRING;
            ATTRIBUTE CLOCK_BUFFER_TYPE OF mode_in : SIGNAL IS "NONE";
            ATTRIBUTE MAX_FANOUT : INTEGER;
            --            attribute MAX_FANOUT of mode_in : signal is 32;
            --            attribute MAX_FANOUT of sum_out : signal is 32;
        BEGIN
            -- Define Inputs for First Row/Column

            B_in <= B_matrix(j, i);
            Binf_in <= B_inf_row(i);
            BNaN_in <= B_NaN_row(i);
            B_zero_in <= B_zero_matrix(j, i);

            C_matrix(i, j) <= sum_out;
            half : IF Pre_in = 16 GENERATE
                PROCESS (C_matrix(N - 1, j)) BEGIN
                    sum_output(j) <= float_to_half(C_matrix(N - 1, j));
                END PROCESS;
            END GENERATE;
            single : IF pre_in = 32 GENERATE
                PROCESS (C_matrix(N - 1, j)) BEGIN
                    sum_output(j) <= float_64_to_32(C_matrix(N - 1, j));
                END PROCESS;
            END GENERATE;

            modein : PROCESS (clk)
            BEGIN
                IF rising_edge(clk) AND en = '1' THEN
                    IF n_rst = '0' THEN
                        mode_in <= (OTHERS => '1');
                    ELSE
                        mode_in <= mode_buffer_row((N - j) * (N - j - 1) + 1 DOWNTO (N - j) * (N - j - 1));
                    END IF;
                END IF;
            END PROCESS;

            in_sum : IF i = 0 GENERATE
                sum_in <= (OTHERS => '0');
            ELSE
                GENERATE
                    sum_in <= C_matrix(i - 1, j);
                END GENERATE;

                in_A : IF j = 0 GENERATE
                    A_in <= A_input(i);

                    A_zero_in <= A_z_col(i);
                    A_NaN_in <= A_N_col(i);
                    A_inf_in <= A_inf_col(i);
                ELSE
                    GENERATE
                        A_in <= A_pipe(i, j - 1);

                        A_zero_in <= A_pipe_z(i, j - 1);
                        A_NaN_in <= A_pipe_N(i, j - 1);
                        A_inf_in <= A_pipe_inf(i, j - 1);
                    END GENERATE;

                    pipe_A : IF j < N - 1 GENERATE
                        PROCESS (clk) BEGIN
                            IF rising_edge(clk) THEN
                                IF n_rst = '0' THEN
                                    A_pipe(i, j) <= (OTHERS => '0');

                                    A_pipe_z(i, j) <= '0';
                                    A_pipe_N(i, j) <= '0';
                                    A_pipe_inf(i, j) <= '0';
                                ELSE
                                    A_pipe(i, j) <= A_in;

                                    A_pipe_z(i, j) <= A_zero_in;
                                    A_pipe_N(i, j) <= A_NaN_in;
                                    A_pipe_inf(i, j) <= A_inf_in;
                                END IF;
                                IF i = N - 1 THEN
                                    --                        report "sumout "& "("&to_string(j)&")" & to_string(sum_out);
                                END IF;
                            END IF;
                        END PROCESS;
                    END GENERATE pipe_A;

                    PE : MAC_external_mode_pq
                    PORT MAP(
                        clk => clk,
                        n_rst => n_rst,
                        a => A_in,
                        b => B_in,
                        c => sum_in,
                        modein => mode_in,
                        sumout => sum_out,

                        A_zero_in => A_zero_in,
                        A_NaN_in => A_NaN_in,
                        A_inf_in => A_inf_in,
                        B_zero_in => B_zero_in,
                        BNaN_in => BNaN_in,
                        Binf_in => Binf_in
                    );

                END GENERATE;
            END GENERATE;

            --tringluar buffers for A input
            buf : FOR i IN 0 TO N - 1 GENERATE
                SIGNAL Abuffer : STD_LOGIC_VECTOR(pre_in * (i + 1) - 1 DOWNTO 0);

            BEGIN
                --                        

                PROCESS (clk)
                BEGIN
                    IF rising_edge(clk) AND en = '1' THEN
                        IF n_rst = '0' THEN
                            Abuffer <= (OTHERS => '0');
                        ELSE
                            A_input1(i) <= Abuffer(pre_in - 1 DOWNTO 0);
                            Abuffer <= STD_LOGIC_VECTOR(shift_right(unsigned(Abuffer), pre_in));
                            Abuffer(pre_in * (i + 1) - 1 DOWNTO pre_in * i) <= A_colmn(i);
                            A_input <= A_input1; -- delay  one register and the other on the clock assignment
                        END IF;
                    END IF;
                END PROCESS;

            END GENERATE;

            --tringluar buffers for A flags
            flag_buf : FOR i IN 0 TO N - 1 GENERATE
                SIGNAL Az_buff : STD_LOGIC_VECTOR(i DOWNTO 0);
                SIGNAL AN_buff : STD_LOGIC_VECTOR(i DOWNTO 0);
                SIGNAL Ainf_buff : STD_LOGIC_VECTOR(i DOWNTO 0);
            BEGIN
                PROCESS (clk)
                BEGIN
                    IF rising_edge(clk) AND en = '1' THEN
                        IF n_rst = '0' THEN
                            Az_buff <= (OTHERS => '0');
                            AN_buff <= (OTHERS => '0');
                            Ainf_buff <= (OTHERS => '0');
                        ELSE
                            A_z_col1(i) <= Az_buff(0);
                            Az_buff <= STD_LOGIC_VECTOR(shift_right(unsigned(Az_buff), 1));
                            Az_buff(i) <= A_zero_col(i);
                            A_z_col <= A_z_col1; -- delay  one register and the other on the clock assignment

                            A_N_col1(i) <= AN_buff(0);
                            AN_buff <= STD_LOGIC_VECTOR(shift_right(unsigned(AN_buff), 1));
                            AN_buff(i) <= A_NaN;
                            A_N_col <= A_N_col1; -- delay  one register and the other on the clock assignment

                            A_inf_col1(i) <= Ainf_buff(0);
                            Ainf_buff <= STD_LOGIC_VECTOR(shift_right(unsigned(Ainf_buff), 1));
                            Ainf_buff(i) <= A_inf;
                            A_inf_col <= A_inf_col1; -- delay  one register and the other on the clock assignment

                        END IF;
                    END IF;
                END PROCESS;

            END GENERATE;
            --tringluar buffers for sum input

            -- another way to buffer out output continously and let the end side to construct its Matrix
            -- the out is taken from sum_output and put into stair buffer (trainglar delays) the each clock the last row is sent out
            C_buf : FOR i IN 0 TO N - 1 GENERATE
                SIGNAL Cbuffer : STD_LOGIC_VECTOR(pre_in * ((N - i)) - 1 DOWNTO 0);
            BEGIN
                PROCESS (clk)
                BEGIN
                    IF rising_edge(clk) THEN
                        sum(i) <= Cbuffer(pre_in - 1 DOWNTO 0);
                        Cbuffer <= STD_LOGIC_VECTOR(shift_right(unsigned(Cbuffer), pre_in));
                        Cbuffer(pre_in * ((N - i)) - 1 DOWNTO pre_in * (N - i - 1)) <= sum_output(i);
                    END IF;
                END PROCESS;

            END GENERATE C_buf;
            --pass matrix output 
        END ARCHITECTURE;