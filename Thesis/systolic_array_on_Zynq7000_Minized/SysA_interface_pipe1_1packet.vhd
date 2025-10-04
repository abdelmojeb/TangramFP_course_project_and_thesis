----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/18/2025 08:17:36 AM
-- Design Name: 
-- Module Name: SysA_interface - Behavioral
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
USE std.textio.ALL;
USE work.my_types.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY SysA_interface_pipe1 IS
    GENERIC (
        N : INTEGER := N;
        Pre_in : INTEGER := Pre_in;
        ex_width_in : INTEGER := ex_width_in;
        cut : INTEGER := cut;
        offset : INTEGER RANGE 0 TO 32 := 0;
        Pre_out : INTEGER := Pre_out
    );
    PORT (-- Clock and Reset shared with the AXI-Lite Slave Port
        s00_axi_aclk : IN STD_LOGIC;
        s00_axi_aresetn : IN STD_LOGIC;

        -- AXI-Stream Slave
        s00_axis_tready : OUT STD_LOGIC;
        s00_axis_tdata : IN STD_LOGIC_VECTOR (pre_in - 1 DOWNTO 0);
        s00_axis_tlast : IN STD_LOGIC;
        s00_axis_tvalid : IN STD_LOGIC;

        -- AXI-Stream Master
        m00_axis_tvalid : OUT STD_LOGIC;
        m00_axis_tdata : OUT STD_LOGIC_VECTOR (pre_in - 1 DOWNTO 0);
        m00_axis_tlast : OUT STD_LOGIC;
        m00_axis_tready : IN STD_LOGIC;
        Transfer0, Store0 : OUT STD_LOGIC;
        -- control signal AXI-Lite Slave Port/GPIO 
        control_sel : IN STD_LOGIC_VECTOR (3 DOWNTO 0) -- loadW = 0011, loadA = 0010
    );
END SysA_interface_pipe1;

ARCHITECTURE pipe_1_buff OF SysA_interface_pipe1 IS
    ATTRIBUTE DONT_TOUCH : STRING;
    SIGNAL W_in : STD_LOGIC_VECTOR (pre_in - 1 DOWNTO 0);
    SIGNAL expB_in : unsigned(ex_width_in DOWNTO 0);
    SIGNAL A_col, sum : N_1_prein;
    SIGNAL A_exp_col : max_array;
    SIGNAL C_buffer, A_buffer : N_N_prein;
    SIGNAL enA, enB, rwA, rwB : STD_LOGIC;
    SIGNAL en, comp, feed_A : STD_LOGIC;
    TYPE states IS (idle, load_W, load_A);
    SIGNAL state : states;
    SIGNAL i, j, col, row, K, L, R : NATURAL RANGE 0 TO N;
    SIGNAL mode : mode_array;
    SIGNAL jobcount : NATURAL RANGE 0 TO N;
    SIGNAL busy, B_loaded : STD_LOGIC;
    SIGNAL en_count : STD_LOGIC;
    SIGNAL count1, count2 : NATURAL RANGE 0 TO 3 * N + 3 + 2;
    SIGNAL fAcount : NATURAL RANGE 0 TO N;
    SIGNAL store, transfer : STD_LOGIC;
    SIGNAL job1, job2 : STD_LOGIC;
    --attribute DONT_TOUCH of count1,count2,en, done, comp,feed_A,fAcount : signal is "TRUE";
    --    attribute DONT_TOUCH of C_buffer, A_buffer,mode : signal is "TRUE";
    --    attribute DONT_TOUCH of i,j, col,row, K, L,R,enA,enB, rwA,rwB,busy , B_loaded,store, transfer : signal is "TRUE";
    --    attribute DONT_TOUCH of W_in,expB_in, A_col, sum,A_exp_col,en_count,job1,job2 : signal is "TRUE";
BEGIN
    Transfer0 <= transfer;
    Store0 <= store;
    -- load input matrices
    PROCESS (s00_axi_aclk)

    BEGIN

        IF rising_edge(s00_axi_aclk) THEN
            IF (s00_axi_aresetn = '0') THEN
                state <= idle;
                comp <= '0';
                enA <= '0';
                rwA <= '0';
                enA <= '0';
                enB <= '0';
                rwB <= '0';
                i <= 0;
                j <= 0;
                B_loaded <= '0';
                jobcount <= 0;
            ELSE
                IF control_sel = "1100" THEN
                    jobcount <= 0;
                END IF;
                CASE state IS

                    WHEN idle =>
                        comp <= '0';
                        IF control_sel = "0011"
                            AND busy = '0' THEN
                            state <= load_W;
                        ELSIF control_sel = "0010" AND B_loaded = '1' THEN
                            state <= load_A;
                        ELSE
                            state <= idle;
                        END IF;

                    WHEN load_W =>
                        col <= j;
                        row <= i;
                        IF s00_axis_tvalid = '1' THEN
                            s00_axis_tready <= '1';
                            enB <= '1';
                            rwB <= '1';

                            j <= j + 1;
                            IF j = N - 1 THEN
                                i <= i + 1;
                                j <= 0;
                            END IF;
                            IF i = N THEN
                                state <= load_A;
                                s00_axis_tready <= '0';
                                i <= 0;
                                j <= 0;
                                enB <= '1';
                                rwB <= '0';
                                B_loaded <= '1';
                            END IF;
                        END IF;
                    WHEN load_A =>
                        col <= j;
                        row <= i;
                        IF s00_axis_tvalid = '1' THEN
                            s00_axis_tready <= '1';
                            enA <= '1';
                            rwA <= '1';

                            j <= j + 1;
                            IF j = N - 1 THEN
                                i <= i + 1;
                                j <= 0;
                            END IF;
                            IF i = N THEN
                                comp <= '1';
                                jobcount <= jobcount + 1;
                                state <= idle;
                                s00_axis_tready <= '0';
                                i <= 0;
                                j <= 0;
                                enA <= '1';
                                rwA <= '0';
                            END IF;
                        END IF;
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    enabling : PROCESS (s00_axi_aclk)
        VARIABLE encount1, encount2 : STD_LOGIC;
    BEGIN
        IF rising_edge(s00_axi_aclk) THEN
            IF s00_axi_aresetn = '0' THEN
                busy <= '0';
                en <= '0';
                count1 <= 0;
                count2 <= 0;
                en_count <= '0';
                encount1 := '0';
                encount2 := '0';
                job1 <= '0';
                job2 <= '0';
            ELSE
                IF comp = '1'THEN
                    busy <= '1';
                    en <= '1';
                    IF en_count = '0'THEN
                        encount1 := '1';
                        en_count <= '1';
                        job1 <= '1';
                    ELSE
                        encount2 := '1';
                        en_count <= '0';
                        job2 <= '1';
                    END IF;
                END IF;

                IF
                    (job1 = '0' AND job2 = '0' AND comp /= '1') THEN
                    en <= '0';
                    busy <= '0';
                END IF;
                IF encount1 = '1' THEN
                    count1 <= count1 + 1;
                    IF count1 > 3 * N + 2 + 2 THEN
                        count1 <= 0;
                        job1 <= '0';
                        encount1 := '0';

                    END IF;
                END IF;
                IF encount2 = '1' THEN
                    count2 <= count2 + 1;
                    IF count2 > 3 * N + 2 + 2 THEN
                        count2 <= 0;
                        job2 <= '0';

                        encount2 := '0';

                    END IF;
                END IF;
                IF (count2 >= 2 * N + 3 + 1 AND count2 <= 3 * N + 2 + 1) OR (count1 >= 2 * N + 3 + 1 AND count1 <= 3 * N + 2 + 1) THEN
                    store <= '1';
                ELSE
                    store <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    output : PROCESS (s00_axi_aclk)
        VARIABLE transcount : NATURAL RANGE 0 TO N;
        VARIABLE transfering : STD_LOGIC;
    BEGIN
        IF rising_edge(s00_axi_aclk) THEN
            IF (s00_axi_aresetn = '0') THEN
                m00_axis_tdata <= (OTHERS => '0');
                m00_axis_tlast <= '0';
                m00_axis_tvalid <= '0';
                transfer <= '0';
                K <= 0;
                L <= 0;
                R <= 0;
                transfering := '0';
                transcount := 0;
            ELSE
                -- case outstate is
                IF control_sel = "1100" THEN
                    transcount := 0;
                END IF;
                IF store = '1' THEN
                    FOR colmn IN 0 TO N - 1 LOOP
                        C_Buffer(colmn, R) <= sum(colmn);
                    END LOOP;
                    R <= R + 1;
                    transfer <= '1';
                    IF R = N - 1 THEN
                        R <= 0;
                    END IF;
                END IF;
                IF transfer = '1' THEN
                    IF transfering = '0' THEN
                        m00_axis_tvalid <= '1';
                        m00_axis_tdata <= C_Buffer(K, L);
                        L <= 1;
                        transfering := '1';
                    END IF;
                    IF m00_axis_tready = '1' THEN
                        IF K <= N - 1 THEN
                            m00_axis_tdata <= C_Buffer(K, L);
                            L <= L + 1;
                            IF L = N - 1 THEN
                                L <= 0;
                                K <= K + 1;
                            END IF;
                            IF K = N - 1 AND L = N - 1 THEN
                                transcount := transcount + 1;
                                IF transcount = jobcount THEN
                                    m00_axis_tlast <= '1';
                                END IF;
                            END IF;
                        ELSE
                            K <= 0;
                            L <= 0;
                            transfer <= '0';
                            m00_axis_tlast <= '0';
                            m00_axis_tvalid <= '0';
                            transfering := '0';
                        END IF;
                    END IF;
                END IF;
                -- end case;
            END IF;
        END IF;
    END PROCESS;
    --loading A and W
    RW_A : PROCESS (s00_axi_aclk)
    BEGIN
        IF rising_edge (s00_axi_aclk) THEN
            IF s00_axi_aresetn = '0' THEN
                A_buffer <= (OTHERS => (OTHERS => (OTHERS => '0')));
            ELSE
                IF enA = '1' AND rwa = '1' THEN
                    A_buffer(row, col) <= s00_axis_tdata;

                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- feeding A and Aexp columns to systolic array and mode unit         
    pass_Acol : PROCESS (s00_axi_aclk, feed_A)
        VARIABLE feed : STD_LOGIC;
    BEGIN
        IF rising_edge(s00_axi_aclk) THEN
            IF s00_axi_aresetn = '0' THEN
                A_col <= (OTHERS => (OTHERS => '0'));
                fAcount <= 0;
                feed := '0';
            ELSE
                IF comp = '1' THEN
                    feed := '1';
                END IF;
                IF fAcount < N AND feed = '1'THEN
                    FOR i IN 0 TO N - 1 LOOP
                        A_col(i) <= A_buffer(i, fAcount);
                        A_exp_col(i) <= unsigned('0' & A_buffer(i, fAcount)(Pre_in - 2 DOWNTO man_width_in));
                    END LOOP;
                    fAcount <= fAcount + 1;
                ELSE
                    fAcount <= 0;
                    feed := '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;
    --forwarding B to systolic array and mode unit           
    passing_B : PROCESS (enB, rwB, s00_axis_tdata)
    BEGIN
        IF enB = '1' AND rwB = '1' THEN
            expB_in <= unsigned('0' & s00_axis_tdata(Pre_in - 2 DOWNTO man_width_in));
            W_in <= s00_axis_tdata;
        ELSE
            expB_in <= (OTHERS => '0');
            W_in <= (OTHERS => '0');
        END IF;
    END PROCESS;
    systolic : ENTITY work.systolic_array_pipe1
        PORT MAP(
            clk => s00_axi_aclk,
            n_rst => s00_axi_aresetn,
            A_colmn => A_col,
            B_in => W_in,
            col => col,
            row => row,
            enB => enB,
            rwB => rwB,
            sum => sum,
            mode => mode,
            en => en
        );

    --instantiate mode selection module
    mode_select : ENTITY work.modes_op2_pipe1
        PORT MAP(
            clk => s00_axi_aclk,
            n_rst => s00_axi_aresetn,
            en => en,
            A_exp => A_exp_col, -- A ,
            expB_in => expB_in,
            col => col,
            row => row,
            enB => enB,
            rwB => rwB,
            modes => mode);