----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/02/2025 05:39:38 PM
-- Design Name: 
-- Module Name: modes_option2 - Behavioral
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

ENTITY modes_op2_pipe1 IS
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
        modes : OUT mode_array);
END modes_op2_pipe1;

ARCHITECTURE Behavioral OF modes_op2_pipe1 IS
    TYPE exp_array IS ARRAY (0 TO N - 1, 0 TO N - 1) OF unsigned(ex_width_in DOWNTO 0);
    TYPE max_array IS ARRAY (0 TO N - 1) OF unsigned(ex_width_in DOWNTO 0);
    TYPE mode_array IS ARRAY (0 TO N - 1) OF STD_LOGIC_VECTOR(2 * N - 1 DOWNTO 0);
    TYPE mode_Barray IS ARRAY (0 TO N - 1, 0 TO N - 1) OF STD_LOGIC_VECTOR(2 * N - 1 DOWNTO 0); -- squre buffer
    SIGNAL B_exp : exp_array;
    SIGNAL i : INTEGER RANGE 0 TO N := 0;
    SIGNAL mode_buffer : mode_array;
    --signal mode_Buffer2 : mode_Barray;

BEGIN
    RW_expB : PROCESS (clk)
    BEGIN
        IF rising_edge (clk) THEN
            IF n_rst = '0' THEN
                B_exp <= (OTHERS => (OTHERS => (OTHERS => '0')));
            ELSE

                IF enB = '1' THEN
                    IF rwb = '1' THEN
                        B_exp(row, col) <= expB_in;

                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;
    --determine the max exp for each all rows in b and 1 column in a
    --determine mode of multiplication for a column and all b rows
    mode : PROCESS (clk, en, i)
        VARIABLE AB_exp : unsigned(ex_width_in DOWNTO 0) := (OTHERS => '0');
        VARIABLE exp_max : max_array := (OTHERS => (OTHERS => '0'));
        VARIABLE dif : signed(ex_width_in DOWNTO 0) := (OTHERS => '0');
        VARIABLE mode : mode_array := (OTHERS => (OTHERS => '0'));
    BEGIN
        IF rising_edge(clk) AND i < N AND en = '1' THEN
           
            -- determine the maximum exponent in the ab vectors dot multiplication
            FOR j IN 0 TO N - 1 LOOP
                FOR k IN 0 TO N - 1 LOOP
                    AB_exp := A_exp(k) + B_exp(j, k) - 127;
                    IF exp_max(j) < AB_exp THEN
                        exp_max(j) := AB_exp;
                    END IF;
                END LOOP;
            END LOOP;

            -- compute the mode vector for every a culomn
            FOR j IN 0 TO N - 1 LOOP
                FOR k IN 0 TO N - 1 LOOP
                    AB_exp := A_exp(k) + B_exp(j, k) - 127;
                    dif := signed(exp_max(j)) - signed(AB_exp);
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
                END LOOP;
            END LOOP;
            mode_buffer <= mode;
            i <= i + 1;-- when i < N-1 else 0;

        END IF;
    END PROCESS mode;
    --shifting mode input square buffer buffers 

    --tringluar buffers
    buf : FOR i IN 0 TO N - 1 GENERATE
        SIGNAL mbuffer : STD_LOGIC_VECTOR(2 * N * (i + 1) - 1 DOWNTO 0);
    BEGIN
        modes(i) <= mbuffer(2 * N - 1 DOWNTO 0);

        PROCESS (clk, en)
        BEGIN
            IF rising_edge(clk)AND en = '1' THEN
                mbuffer <= STD_LOGIC_VECTOR(shift_right(unsigned(mbuffer), 2 * N));
                mbuffer(2 * N * (i + 1) - 1 DOWNTO 2 * N * i) <= mode_buffer(i);
            END IF;
        END PROCESS;

    END GENERATE;
END Behavioral;