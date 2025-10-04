----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/05/2025 02:55:38 PM
-- Design Name: 
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
        en : STD_LOGIC
    );
END ENTITY;

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
            sumout : OUT STD_LOGIC_VECTOR (precision_out - 1 DOWNTO 0));
    END COMPONENT;
    --      attribute DONT_TOUCH of MAC_external_mode_pq : component is "TRUE";

    SIGNAL B_matrix : N_N_prein;
    SIGNAL C_matrix : N_N_preout; --C_matrix accumulation interconnection, Cout matrix output
    --    signal Cout : N_N_Prein;
    SIGNAL A_input, A_input1 : N_1_prein;
    SIGNAL A_pipe : A_pipeline; -- N_N_prein; -- A interconnection between PEs
    SIGNAL sum_output : N_1_prein;
    --signal sum_out_connect : N_1_preout;
    SIGNAL mode_buffer : N_1_mode;
    ATTRIBUTE DONT_TOUCH OF C_matrix : SIGNAL IS "TRUE";
    ATTRIBUTE DONT_TOUCH OF A_pipe : SIGNAL IS "TRUE";
    ATTRIBUTE DONT_TOUCH OF sum_output : SIGNAL IS "TRUE";
    --    attribute DONT_TOUCH of Cout : signal is "TRUE";
BEGIN
    RW_B : PROCESS (clk)
    BEGIN
        IF rising_edge (clk) THEN
            IF n_rst = '0' THEN
                B_matrix <= (OTHERS => (OTHERS => (OTHERS => '0')));
            ELSE

                IF enB = '1' THEN
                    IF rwb = '1' THEN
                        B_matrix(row, col) <= B_in;

                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- propagate the modes accross levels in the systolic array 
    -- the buffer has for each row a vector that contains modes will 
    --be used for each row in b, N*2 -2 [8,6,4,2] each time will be coppied to the right bits in the vector
    --propagate through pipe
    mode_prop : PROCESS (clk, en)
    BEGIN
        IF rising_edge(clk)AND en = '1' THEN
            IF n_rst = '0' THEN
                mode_buffer <= (OTHERS => (OTHERS => '1'));
            ELSE
                -- insert the first mode into the buffer
                FOR x IN 0 TO N - 1 LOOP
                    mode_buffer(x)(N * (N + 1) - 1 DOWNTO N * (N - 1)) <= mode(x);
                END LOOP;

                FOR y IN 0 TO N - 1 LOOP
                    FOR k IN 0 TO N - 2 LOOP
                        mode_buffer(y)((k + 1) * (k + 2) - 1 DOWNTO k * (k + 1)) <=
                        mode_buffer(y)((k + 2) * (k + 3) - 1 DOWNTO (k + 1) * (k + 2) + 2);
                    END LOOP;
                END LOOP;
            END IF;
        END IF;
    END PROCESS;
    -- Instantiate Processing Elements
    gen_rows : FOR i IN 0 TO N - 1 GENERATE
        gen_cols : FOR j IN 0 TO N - 1 GENERATE

            SIGNAL sum_in, sum_out : STD_LOGIC_VECTOR(Pre_out - 1 DOWNTO 0);
            SIGNAL A_in, B_in : STD_LOGIC_VECTOR(Pre_in - 1 DOWNTO 0);
            SIGNAL mode_in : STD_LOGIC_VECTOR(1 DOWNTO 0);
        BEGIN
            -- Define Inputs for First Row/Column
            A_in <= A_input(i) WHEN j = 0 ELSE
                A_pipe(i, j - 1);
            B_in <= B_matrix(j, i);
            sum_in <= (OTHERS => '0') WHEN (i = 0) ELSE
                C_matrix(i - 1, j);
            C_matrix(i, j) <= sum_out;
            half : IF Pre_in = 16 GENERATE
                sum_output(j) <= float_to_half(C_matrix(N - 1, j));
            END GENERATE;
            single : IF pre_in = 32 GENERATE
                sum_output(j) <= float_64_to_32(C_matrix(N - 1, j));
            END GENERATE;
            mode_in <= mode_buffer(i)((N - j) * (N - j - 1) + 1 DOWNTO (N - j) * (N - j - 1));

            pipe : IF j < N - 1 GENERATE
                PROCESS (clk) BEGIN
                    IF rising_edge(clk) THEN
                        IF n_rst = '0' THEN
                            A_pipe(i, j) <= (OTHERS => '0');
                        ELSE
                            A_pipe(i, j) <= A_in;
                        END IF;
                    END IF;
                END PROCESS;
            END GENERATE pipe;

            PE : MAC_external_mode_pq

            PORT MAP(
                clk => clk,
                n_rst => n_rst,
                a => A_in,
                b => B_in,
                c => sum_in,
                modein => mode_in,

                sumout => sum_out
            );

        END GENERATE;
    END GENERATE;

    --tringluar buffers for A input
    buf : FOR i IN 0 TO N - 1 GENERATE
        SIGNAL Abuffer : STD_LOGIC_VECTOR(pre_in * (i + 1) - 1 DOWNTO 0);
    BEGIN

        PROCESS (clk, en)
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