----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/02/2025 05:39:38 PM
-- Design Name: sytolic array
-- Module Name: mode unit option 2 - 1 row all columns at clock cycle
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
USE work.my_types.ALL;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY modes_op2_pipe2 IS
    PORT (
        clk : IN STD_LOGIC;
        n_rst : IN STD_LOGIC;
        en : IN STD_LOGIC;
        A_exp : IN max_array;
        expB_in : IN unsigned(ex_width_in DOWNTO 0);
        col : IN INTEGER RANGE 0 TO N;
        row : IN INTEGER RANGE 0 TO N;
        enB : IN STD_LOGIC;
        rwB : IN STD_LOGIC;
        B_zero : STD_LOGIC;
        B_NaN : STD_LOGIC;
        B_inf : STD_LOGIC;
        A_inf : STD_LOGIC;
        A_NaN : STD_LOGIC;
        A_zero_col : status_col;
        modes : OUT mode_array);
    --        attribute dont_touch : string;
    --        attribute dont_touch of modes_op2_pipe1 : entity is "true";
END modes_op2_pipe2;

ARCHITECTURE Behavioral OF modes_op2_pipe2 IS
    TYPE exp_array IS ARRAY (0 TO N - 1, 0 TO N - 1) OF signed(ex_width_in DOWNTO 0);
    TYPE max_array IS ARRAY (0 TO N - 1) OF signed(ex_width_in DOWNTO 0);
    TYPE mode_array IS ARRAY (0 TO N - 1) OF STD_LOGIC_VECTOR(2 * N - 1 DOWNTO 0);
    TYPE mode_Barray IS ARRAY (0 TO N - 1, 0 TO N - 1) OF STD_LOGIC_VECTOR(2 * N - 1 DOWNTO 0); -- squre buffer
    SIGNAL B_exp, AB_exp : exp_array;
    SIGNAL exp_max : max_array;
    SIGNAL i : INTEGER RANGE 0 TO N := 0;
    SIGNAL mode_buffer : mode_array;
    SIGNAL B_zero_matrix : status_matrix;
    SIGNAL B_nan_row : status_col;
    SIGNAL B_inf_row : status_col;
    CONSTANT bias : signed(ex_width_in DOWNTO 0) := to_signed(2 ** (ex_width_in - 1) - 1, ex_width_in + 1);
BEGIN
    RW_expB : PROCESS (clk)
    BEGIN
        IF rising_edge (clk) THEN
            IF n_rst = '0' THEN
                B_exp <= (OTHERS => (OTHERS => (OTHERS => '0')));
                B_zero_matrix <= (OTHERS => (OTHERS => '0'));
                B_nan_row <= (OTHERS => '0');
                B_inf_row <= (OTHERS => '0');
            ELSE

                IF enB = '1' THEN
                    IF rwb = '1' THEN
                        B_exp(row, col) <= signed(expB_in);
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

    exponent : PROCESS (A_exp, B_exp)
        VARIABLE AB : signed(ex_width_in + 1 DOWNTO 0);
        VARIABLE max : signed(ex_width_in DOWNTO 0);
        VARIABLE exp_local : max_array;
        VARIABLE AB_local : exp_array;
        VARIABLE Binf, Bnan : STD_LOGIC;
    BEGIN
        IF (A_nan OR A_inf) = '0' THEN
            FOR i IN 0 TO N - 1 LOOP
                max := (OTHERS => '0');
                Binf := B_inf_row(i);
                Bnan := B_nan_row(i);
                IF (Bnan OR Binf) = '0' THEN
                    FOR j IN 0 TO N - 1 LOOP
                        AB := signed('0' & A_exp(j)) + signed('0' & B_exp(i, j)) - bias;

                        AB_local(i, j) := AB(ex_width_in DOWNTO 0);
                        IF max < AB THEN
                            max := AB(ex_width_in DOWNTO 0);
                        END IF;
                    END LOOP;
                    exp_local(i) := max;
                END IF;
            END LOOP;
        END IF;
        -- Assign everything at once at the end
        exp_max <= exp_local;
        AB_exp <= AB_local;
    END PROCESS;
    --determine the max exp for each all rows in b and 1 column in a
    --determine mode of multiplication for a column and all b rows
    mode : PROCESS (clk)

        VARIABLE dif : signed(ex_width_in DOWNTO 0) := (OTHERS => '0');
        VARIABLE mode : mode_array := (OTHERS => (OTHERS => '0'));
        VARIABLE B_skip : STD_LOGIC := '0';
    BEGIN
        IF rising_edge(clk) AND en = '1' THEN --and i < N
            IF (A_nan OR A_inf) = '0' THEN
                -- compute the mode vector for every a culomn
                FOR j IN 0 TO N - 1 LOOP
                    B_skip := B_inf_row(j) OR B_nan_row(j);
                    FOR k IN 0 TO N - 1 LOOP
                        IF B_skip = '1' OR (A_zero_col(k) OR B_zero_matrix(j, k)) = '1' THEN
                            mode(k)(j * 2 + 1 DOWNTO j * 2) := "11";--SKIP;
                        ELSE
                            dif := signed(exp_max(j)) - signed(AB_exp(j, k));
                            IF (dif = 0 OR dif < 0) THEN
                                mode(k)(j * 2 + 1 DOWNTO j * 2) := "00";--Full;
                            ELSIF (dif > 0 AND dif < thr1) THEN
                                mode(k)(j * 2 + 1 DOWNTO j * 2) := "01";---SKIP_BD;
                            ELSIF (dif >= thr1 AND dif < thr2) THEN
                                mode(k)(j * 2 + 1 DOWNTO j * 2) := "10";--AC_ONLY;
                            ELSIF (dif >= thr2) THEN
                                mode(k)(j * 2 + 1 DOWNTO j * 2) := "11";--SKIP;
                            ELSE
                                mode(k)(j * 2 + 1 DOWNTO j * 2) := "11";--SKIP;
                            END IF;
                        END IF;
                    END LOOP;
                END LOOP;
            ELSE
                mode := (OTHERS => (OTHERS => '1')); -- all skip
            END IF;
            mode_buffer <= mode;

        END IF;
    END PROCESS mode;
    --shifting mode input square buffer buffers 

    --tringluar buffers
    buf : FOR i IN 0 TO N - 1 GENERATE
        SIGNAL mbuffer : STD_LOGIC_VECTOR(2 * N * (i + 1) - 1 DOWNTO 0);
    BEGIN
        modes(i) <= mbuffer(2 * N - 1 DOWNTO 0);

        PROCESS (clk)
        BEGIN
            IF rising_edge(clk)AND en = '1' THEN
                mbuffer <= STD_LOGIC_VECTOR(shift_right(unsigned(mbuffer), 2 * N));
                mbuffer(2 * N * (i + 1) - 1 DOWNTO 2 * N * i) <= mode_buffer(i);
            END IF;
        END PROCESS;

    END GENERATE;
END Behavioral;