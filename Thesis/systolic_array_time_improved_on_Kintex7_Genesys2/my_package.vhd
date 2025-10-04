LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
PACKAGE my_types IS
    CONSTANT N : INTEGER := 4;
    CONSTANT Pre_in : INTEGER := 32;
    CONSTANT ex_width_in : INTEGER := 8;
    CONSTANT cut : INTEGER := 11;
    CONSTANT offset : INTEGER RANGE 0 TO 32 := 0;

    CONSTANT Pre_out : INTEGER := Pre_in * 2;
    CONSTANT ex_width_out : INTEGER RANGE 0 TO 16 := ex_width_in + 3;
    CONSTANT man_width_in : INTEGER RANGE 0 TO 32 := Pre_in - ex_width_in - 1;
    CONSTANT man_width_out : INTEGER RANGE 0 TO 64 := Pre_out - ex_width_out - 1;
    CONSTANT thr1 : INTEGER := cut;
    CONSTANT thr2 : INTEGER := man_width_in;

    TYPE mode_array IS ARRAY (0 TO N - 1) OF STD_LOGIC_VECTOR(2 * N - 1 DOWNTO 0);
    TYPE N_N_prein IS ARRAY (0 TO N - 1, 0 TO N - 1) OF STD_LOGIC_VECTOR(Pre_in - 1 DOWNTO 0);
    TYPE N_N_preout IS ARRAY (0 TO N - 1, 0 TO N - 1) OF STD_LOGIC_VECTOR(Pre_out - 1 DOWNTO 0);
    TYPE N_1_prein IS ARRAY (0 TO N - 1) OF STD_LOGIC_VECTOR(Pre_in - 1 DOWNTO 0);
    TYPE N_1_preout IS ARRAY (0 TO N - 1) OF STD_LOGIC_VECTOR(Pre_out - 1 DOWNTO 0);
    TYPE A_pipeline IS ARRAY (0 TO N - 1, 0 TO N - 2) OF STD_LOGIC_VECTOR(Pre_in - 1 DOWNTO 0);
    TYPE max_array IS ARRAY (0 TO N - 1) OF unsigned(ex_width_in DOWNTO 0);
    TYPE exp_array IS ARRAY (0 TO N - 1, 0 TO N - 1) OF unsigned(ex_width_in DOWNTO 0);
    --    type pipe is array(0 to N-1, 0 to N-2) of std_logic_vector(Pre_in-1 downto 0);
    TYPE N_1_mode IS ARRAY (0 TO N - 1) OF STD_LOGIC_VECTOR(N * (N + 1) - 1 DOWNTO 0);
    TYPE status_matrix IS ARRAY (0 TO N - 1, 0 TO N - 1) OF STD_LOGIC;
    TYPE status_col IS ARRAY (0 TO N - 1) OF STD_LOGIC;
    TYPE A_flag_pipe IS ARRAY (0 TO N - 1, 0 TO N - 2) OF STD_LOGIC;
END PACKAGE;