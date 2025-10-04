----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/18/2025 08:17:36 AM
-- Design Name: systolic array 
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
    PORT (
        -- Clock and Reset shared with the AXI-Lite Slave Port
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
        --debug signals
        --    Transfer0, Store0: out std_logic;
        --    current_state: out std_logic_vector(1 downto 0);
        --    Acol, Arow : out std_logic_vector(N-1 downto 0);
        --    job_count : out std_logic_vector(N-1 downto 0);
        --    Abusy : out std_logic;
        -- Matrix-select and Start signals coming from the AXI-Lite Slave Port
        control_sel : IN STD_LOGIC_VECTOR (3 DOWNTO 0) -- loadW = 0011, loadA = 0010
        --    led_out : out  std_logic_vector (1 downto 0) 
    );
END SysA_interface_pipe1;

ARCHITECTURE pipe_1_buff OF SysA_interface_pipe1 IS
    ATTRIBUTE DONT_TOUCH : STRING;
    -- signals
    SIGNAL W_in : STD_LOGIC_VECTOR (pre_in - 1 DOWNTO 0);
    SIGNAL expB_in : unsigned(ex_width_in DOWNTO 0);
    SIGNAL A_col, sum : N_1_prein;
    SIGNAL A_exp_col : max_array;

    SIGNAL C_buffer, A_buffer : N_N_prein;
    SIGNAL enA, enB, rwA, rwB : STD_LOGIC;
    SIGNAL en, comp : STD_LOGIC;
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
    SIGNAL control_sel1 : STD_LOGIC_VECTOR (3 DOWNTO 0);
    --status
    SIGNAL is_NaN, is_zero, is_inf : STD_LOGIC;
    SIGNAL T_data : STD_LOGIC_VECTOR(pre_in - 1 DOWNTO 0);
    SIGNAL A_zero_matrix : status_matrix;
    SIGNAL A_zero_col, A_nan_col, A_inf_col : status_col;
    SIGNAL B_zero, B_nan, B_inf, A_nan, A_inf : STD_LOGIC;
    CONSTANT inf_exponent : unsigned(ex_width_in - 1 DOWNTO 0) := to_unsigned(2 ** ex_width_in - 1, ex_width_in);

BEGIN
    --debug signals
    --Transfer0 <= transfer;
    --Store0 <= store;
    --with state select
    --current_state <= "01" when idle,
    --               "10" when load_W,
    --               "11" when load_A,
    --               "00" when others;
    --job_count <= std_logic_vector(to_unsigned(jobcount,N));
    --Acol <= std_logic_vector(to_unsigned(col,N));
    --Arow <= std_logic_vector(to_unsigned(row,N));
    --Abusy <= busy;

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
                control_sel1 <= (OTHERS => '0');
            ELSE
                control_sel1 <= control_sel;

                CASE state IS

                    WHEN idle =>
                        comp <= '0';
                        IF control_sel = "0011" AND s00_axis_tvalid = '1'
                            AND busy = '0' THEN
                            jobcount <= 0;
                            state <= load_W;
                        ELSIF control_sel = "0010" AND B_loaded = '1' AND s00_axis_tvalid = '1' THEN
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

                IF (job1 = '0' AND job2 = '0' AND comp /= '1') THEN
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
                --      when transfer_r =>
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

            END IF;
        END IF;
    END PROCESS;
    --loading A 
    RW_A : PROCESS (s00_axi_aclk)
    BEGIN
        IF rising_edge (s00_axi_aclk) THEN
            IF s00_axi_aresetn = '0' THEN
                A_buffer <= (OTHERS => (OTHERS => (OTHERS => '0')));
            ELSE
                IF enA = '1' AND rwa = '1' THEN
                    A_buffer(row, col) <= T_data;

                END IF;
            END IF;
        END IF;
    END PROCESS;

    --flagging zeros--NanNs--infinties in A columns
    flags : PROCESS (s00_axi_aclk)

    BEGIN
        IF rising_edge (s00_axi_aclk) THEN
            IF s00_axi_aresetn = '0' THEN
                A_zero_matrix <= (OTHERS => (OTHERS => '0'));
                A_NaN_col <= (OTHERS => '0');
                A_inf_col <= (OTHERS => '0');
            ELSE
                IF enA = '1' AND rwa = '1' THEN
                    A_zero_matrix (row, col) <= is_zero;
                    IF row > 0 THEN
                        A_NaN_col(col) <= A_NaN_col(col) OR is_NaN;
                        A_inf_col(col) <= A_inf_col(col) OR is_inf;
                    ELSE
                        A_NaN_col(col) <= is_NaN;
                        A_inf_col(col) <= is_inf;
                    END IF;
                END IF;
            END IF;

        END IF;
    END PROCESS;

    -- feeding A and Aexp columns to systolic array and mode unit         
    pass_Acol : PROCESS (s00_axi_aclk)
        VARIABLE feed : STD_LOGIC;
    BEGIN
        IF rising_edge(s00_axi_aclk) THEN
            IF s00_axi_aresetn = '0' THEN
                A_col <= (OTHERS => (OTHERS => '0'));
                A_exp_col <= (OTHERS => (OTHERS => '0'));
                A_zero_col <= (OTHERS => '0');
                A_inf <= '0';
                A_NaN <= '0';
                fAcount <= 0;
                feed := '0';
            ELSE
                IF comp = '1' THEN
                    feed := '1';
                END IF;
                IF fAcount < N AND feed = '1'THEN
                    FOR i IN 0 TO N - 1 LOOP
                        A_col(i) <= A_buffer(i, fAcount);
                        --                            A_exp_col(i) <= A_exp(i,fAcount);
                        A_exp_col(i) <= unsigned('0' & A_buffer(i, fAcount)(Pre_in - 2 DOWNTO man_width_in));
                        A_zero_col(i) <= A_zero_matrix(i, fAcount);
                    END LOOP;
                    A_inf <= A_inf_col(fAcount);
                    A_NaN <= A_NaN_col(fAcount);
                    fAcount <= fAcount + 1;
                ELSE
                    fAcount <= 0;
                    feed := '0';

                END IF;
            END IF;
        END IF;
    END PROCESS;

    --forwarding B to systolic array and mode unit           
    passing_B : PROCESS (enB, rwB, T_data)
    BEGIN
        IF enB = '1' AND rwB = '1' THEN
            expB_in <= unsigned('0' & T_data(Pre_in - 2 DOWNTO man_width_in));
            W_in <= T_data;
            B_zero <= is_zero;
            B_inf <= is_inf;
            B_NaN <= is_NaN;
        ELSE
            expB_in <= (OTHERS => '0');
            W_in <= (OTHERS => '0');
            B_zero <= '0';
            B_inf <= '0';
            B_NaN <= '0';
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

            B_zero => B_zero,
            B_NaN => B_NaN,
            B_inf => B_inf,
            A_inf => A_inf,
            A_NaN => A_NaN,
            A_zero_col => A_zero_col,

            mode => mode,
            en => en
        );

    --instantiate mode selection module
    mode_select : ENTITY work.modes_op2_pipe2
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

            B_zero => B_zero,
            B_NaN => B_NaN,
            B_inf => B_inf,
            A_inf => A_inf,
            A_NaN => A_NaN,
            A_zero_col => A_zero_col,
            modes => mode);
    modes => mode);

    --check received data for Infinity, NaN or Subnormal
    subnormal : PROCESS (s00_axis_tdata)
        VARIABLE Tdata : STD_LOGIC_VECTOR(Pre_in - 1 DOWNTO 0);
        VARIABLE exponent : unsigned(ex_width_in - 1 DOWNTO 0);
        VARIABLE mantissa : unsigned(man_width_in - 1 DOWNTO 0);
        VARIABLE ex_zero, ex_inf, man_zero, man_nz : STD_LOGIC;
    VARIABLE zero, inf, NaN : STD_LOGIC;
        BEGIN
        exponent := unsigned(s00_axis_tdata(pre_in - 2 DOWNTO man_width_in));
        mantissa := unsigned(s00_axis_tdata(man_width_in - 1 DOWNTO 0));
        IF exponent = 0 THEN
        ex_zero := '1';
            ELSE
        ex_zero := '0';
            END IF;
        IF exponent = inf_exponent THEN
        ex_inf := '1';
            ELSE
        ex_inf := '0';
            END IF;

        IF mantissa = 0 THEN
        man_zero := '1';
            ELSE
        man_zero := '0';
            END IF;
        IF mantissa > 0 THEN
        man_nz := '1';
            ELSE
        man_nz := '0';
            END IF;
        --if subnormal : normalize to lowest
        IF ex_zero = '1' AND man_nz = '1' THEN
        Tdata := s00_axis_tdata(pre_in - 1) & STD_LOGIC_VECTOR(to_unsigned(1, ex_width_in)) & STD_LOGIC_VECTOR(to_unsigned(0, man_width_in));
            ELSE
        Tdata := s00_axis_tdata;
            END IF;
        -- check if number is zero
        IF ex_zero = '1' AND man_zero = '1' THEN
        zero := '1';
            ELSE
        zero := '0';
            END IF;
        -- check if number is NaN or infinity
        IF ex_inf = '1' THEN
            IF man_zero = '1' THEN
                inf := '1';
            NaN := '0';
                ELSE
                NaN := '1';
            inf := '0';
            END IF;
            ELSE
            NaN := '0';
        inf := '0';
            END IF;
        T_data <= Tdata;
        is_NaN <= NaN;
        is_inf <= inf;
    is_zero <= zero;
        END PROCESS;