
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_signed.ALL;
USE ieee.numeric_std.ALL;
USE work.tools.ALL;

ENTITY kacy_mul_p_q IS
    GENERIC (
        width : INTEGER := 11; -- width here is mantissa +1
        cut : INTEGER := 5
    );
    PORT (
        u : IN STD_LOGIC_VECTOR(width - 1 DOWNTO 0);
        v : IN STD_LOGIC_VECTOR(width - 1 DOWNTO 0);
        --        mode : in std_logic_vector(1 downto 0);
        --        sign_ab : in std_logic;
        ac_e : IN STD_LOGIC;
        ad_e : IN STD_LOGIC;
        bc_e : IN STD_LOGIC;
        bd_e : IN STD_LOGIC;
        mantissa : OUT STD_LOGIC_VECTOR(2 * width - 1 DOWNTO 0)

    );
END kacy_mul_p_q;

ARCHITECTURE kacy_mul_arch OF kacy_mul_p_q IS

    COMPONENT DaddaMultiplier_p_q
        GENERIC (
            n : INTEGER := cut;
            m : INTEGER := width - cut - 1);--m =p and n = q
        PORT (
            enable : STD_LOGIC;
            a : IN STD_LOGIC_VECTOR(m - 1 DOWNTO 0); -- 5
            b : IN STD_LOGIC_VECTOR(n - 1 DOWNTO 0); -- 5
            -- is_signed : in std_logic;               
            orow1 : OUT STD_LOGIC_VECTOR(m + n - 1 DOWNTO 0); -- 10
            orow2 : OUT STD_LOGIC_VECTOR(m + n - 1 DOWNTO 0) -- 10
        );
    END COMPONENT;

    COMPONENT CSA4i
        GENERIC (n : INTEGER := 2 * cut); -- 10
        PORT (
            w : IN STD_LOGIC_VECTOR (n - 1 DOWNTO 0);
            x : IN STD_LOGIC_VECTOR (n - 1 DOWNTO 0); -- 10
            y : IN STD_LOGIC_VECTOR (n - 1 DOWNTO 0); -- 10
            z : IN STD_LOGIC_VECTOR (n - 1 DOWNTO 0); -- 10
            cout : OUT STD_LOGIC;
            s : OUT STD_LOGIC_VECTOR (n DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT CSA2iPQ
        GENERIC (
            n : INTEGER := 22;
            p : INTEGER RANGE 0 TO 16 := 5;
            cut : INTEGER RANGE 0 TO 16 := 5);
        PORT (
            x : IN STD_LOGIC_VECTOR (n - 1 DOWNTO 0); -- 17
            y : IN STD_LOGIC_VECTOR (p + 2 * cut + 1 DOWNTO cut); -- 17
            z : IN STD_LOGIC; -- 1
            s : OUT STD_LOGIC_VECTOR (n DOWNTO 0) -- 18
        );
    END COMPONENT;

    CONSTANT FULL_COMPUTE : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    CONSTANT SKIP_BD : STD_LOGIC_VECTOR(1 DOWNTO 0) := "01";
    CONSTANT AC_ONLY : STD_LOGIC_VECTOR(1 DOWNTO 0) := "10";
    CONSTANT FULL_SKIP : STD_LOGIC_VECTOR(1 DOWNTO 0) := "11";

    CONSTANT p : INTEGER := width - cut - 1;
    CONSTANT width_pq : INTEGER := choose_width(p, cut);

    SIGNAL x : STD_LOGIC; -- 1
    SIGNAL y : STD_LOGIC; -- 1
    SIGNAL pu : STD_LOGIC_VECTOR(width - 2 DOWNTO 0); -- 10 ititially width -2
    SIGNAL pv : STD_LOGIC_VECTOR(width - 2 DOWNTO 0); -- 10 ititially width -2

    SIGNAL a : STD_LOGIC_VECTOR(p - 1 DOWNTO 0); -- 5
    SIGNAL b : STD_LOGIC_VECTOR(cut - 1 DOWNTO 0); -- 5
    SIGNAL c : STD_LOGIC_VECTOR(p - 1 DOWNTO 0); -- 5
    SIGNAL d : STD_LOGIC_VECTOR(cut - 1 DOWNTO 0); -- 5

    SIGNAL Lac_a : STD_LOGIC_VECTOR(p - 1 DOWNTO 0); -- 5
    SIGNAL Lac_c : STD_LOGIC_VECTOR(p - 1 DOWNTO 0); -- 5
    SIGNAL Lad_a : STD_LOGIC_VECTOR(p - 1 DOWNTO 0); -- 5
    SIGNAL Lad_d : STD_LOGIC_VECTOR(cut - 1 DOWNTO 0); -- 5
    SIGNAL Lbc_b : STD_LOGIC_VECTOR(cut - 1 DOWNTO 0); -- 5
    SIGNAL Lbc_c : STD_LOGIC_VECTOR(p - 1 DOWNTO 0); -- 5
    SIGNAL Lbd_b : STD_LOGIC_VECTOR(cut - 1 DOWNTO 0); -- 5
    SIGNAL Lbd_d : STD_LOGIC_VECTOR(cut - 1 DOWNTO 0); -- 5

    SIGNAL bd : STD_LOGIC_VECTOR(2 * cut - 1 DOWNTO 0); -- 10
    SIGNAL bd_row1 : STD_LOGIC_VECTOR(2 * cut - 1 DOWNTO 0); -- 10
    SIGNAL bd_row2 : STD_LOGIC_VECTOR(2 * cut - 1 DOWNTO 0); -- 10
    SIGNAL ad_row1 : STD_LOGIC_VECTOR(p + cut - 1 DOWNTO 0); -- 10
    SIGNAL ad_row2 : STD_LOGIC_VECTOR(p + cut - 1 DOWNTO 0); -- 10
    SIGNAL bc_row1 : STD_LOGIC_VECTOR(p + cut - 1 DOWNTO 0); -- 10
    SIGNAL bc_row2 : STD_LOGIC_VECTOR(p + cut - 1 DOWNTO 0); -- 10
    SIGNAL ac_row1 : STD_LOGIC_VECTOR(2 * p - 1 DOWNTO 0); -- 10
    SIGNAL ac_row2 : STD_LOGIC_VECTOR(2 * p - 1 DOWNTO 0); -- 10

    SIGNAL csa_bc_ad_c : STD_LOGIC; -- 1
    SIGNAL csa_bc_ad_s : STD_LOGIC_VECTOR(p + cut DOWNTO 0); -- 11

    SIGNAL csa_ac_puv_c : STD_LOGIC; -- 1
    SIGNAL csa_ac_puv_s : STD_LOGIC_VECTOR(width_pq DOWNTO 0); -- 11

    SIGNAL cout : STD_LOGIC;
    SIGNAL res : STD_LOGIC_VECTOR(2 * width DOWNTO 0);

    SIGNAL final_csa_x : STD_LOGIC_VECTOR(2 * width - 1 DOWNTO 0);
    SIGNAL final_csa_y : STD_LOGIC_VECTOR(p + 2 * cut + 1 DOWNTO cut);
    SIGNAL final_csa_z : STD_LOGIC;

BEGIN

    x <= u(width - 1); -- 1
    y <= v(width - 1); -- 1
    ASSERT p >= cut SEVERITY error;
    pu <= u(width - 2 DOWNTO 0);
    pv <= v(width - 2 DOWNTO 0);

    a <= u(width - 2 DOWNTO cut); -- [9:5] --2*cut-1
    b <= u(cut - 1 DOWNTO 0); -- [4:0]
    c <= v(width - 2 DOWNTO cut); -- [9:5]--2*cut-1
    d <= v(cut - 1 DOWNTO 0); -- [4:0]

    MUL_bd : DaddaMultiplier_p_q GENERIC MAP(
        n => cut, m => cut) PORT MAP (
        enable => bd_e,
        a => Lbd_b, b => Lbd_d, --is_signed => is_signed, 
        orow1 => bd_row1, orow2 => bd_row2
    );
    -- generate the multipliers that fit for the p,q values a > b 
    MUL_adbcqp : IF p < cut GENERATE

        MUL_ad_qp : DaddaMultiplier_p_q GENERIC MAP(
            n => p, m => cut) PORT MAP (
            enable => ad_e,
            a => Lad_d, b => Lad_a, --is_signed => is_signed, 
            orow1 => ad_row1, orow2 => ad_row2
        );
        MUL_bc_qp : DaddaMultiplier_p_q GENERIC MAP(
            n => p, m => cut) PORT MAP (
            enable => bc_e,
            a => Lbc_b, b => Lbc_c, -- is_signed => is_signed, 
            orow1 => bc_row1, orow2 => bc_row2
        );

    ELSE
        GENERATE
            MUL_ad_pq : DaddaMultiplier_p_q GENERIC MAP(
                n => cut, m => p) PORT MAP (
                enable => ad_e,
                a => Lad_a, b => Lad_d, --is_signed => is_signed, 
                orow1 => ad_row1, orow2 => ad_row2
            );
            MUL_bc_pq : DaddaMultiplier_p_q GENERIC MAP(
                n => cut, m => p) PORT MAP (
                enable => bc_e,
                a => Lbc_c, b => Lbc_b, -- is_signed => is_signed, 
                orow1 => bc_row1, orow2 => bc_row2
            );
        END GENERATE;
        MUL_ac : DaddaMultiplier_p_q GENERIC MAP(
            n => p) PORT MAP (
            enable => ac_e,
            a => Lac_a, b => Lac_c, --is_signed => is_signed, 
            orow1 => ac_row1, orow2 => ac_row2
        );
        latch_proc_ac : PROCESS (ac_e, a, c)
        BEGIN
            IF (ac_e = '1') THEN
                Lac_a <= a;
                Lac_c <= c;
            END IF;
        END PROCESS;

        latch_proc_bc : PROCESS (bc_e, b, c)
        BEGIN
            IF (bc_e = '1') THEN
                Lbc_b <= b;
                Lbc_c <= c;
            END IF;
        END PROCESS;

        latch_proc_ad : PROCESS (ad_e, a, d)
        BEGIN
            IF (ad_e = '1') THEN
                Lad_a <= a;
                Lad_d <= d;
            END IF;
        END PROCESS;

        latch_proc_bd : PROCESS (bd_e, b, d)
        BEGIN
            IF (bd_e = '1') THEN
                Lbd_b <= b;
                Lbd_d <= d;
            END IF;
        END PROCESS;
        csa_bc_ad : CSA4i
        GENERIC MAP(n => p + cut)
        PORT MAP(
            w => bc_row1,
            x => bc_row2,
            y => ad_row1,
            z => ad_row2,
            cout => csa_bc_ad_c,
            s => csa_bc_ad_s
        );

        -- when p<q AC becomes short and BD long and uv are same length AC takes the remaining length from BD
        -- when p>q AC is longer BD is 2q the uv then padded with 0s to reach AC 
        csa4 : IF p > cut GENERATE
            SIGNAL pui : STD_LOGIC_VECTOR(2 * p - 1 DOWNTO 0);
            SIGNAL pvi : STD_LOGIC_VECTOR(2 * p - 1 DOWNTO 0);
        BEGIN
            pui <= pu & STD_LOGIC_VECTOR(to_unsigned(0, p - cut));
            pvi <= pv & STD_LOGIC_VECTOR(to_unsigned(0, p - cut));
            final_csa_x <= csa_ac_puv_c & csa_ac_puv_s & bd;
            csa_ac_ab_cdpq : CSA4i
            GENERIC MAP(n => width_pq)--width_pq = 2*p
            PORT MAP(
                w => ac_row1,
                x => ac_row2,
                y => pui,
                z => pvi,
                cout => csa_ac_puv_c,
                s => csa_ac_puv_s
            );
        ELSE
            GENERATE
                SIGNAL ac_row1i : STD_LOGIC_VECTOR(width_pq - 1 DOWNTO 0);
                SIGNAL ac_row2i : STD_LOGIC_VECTOR(width_pq - 1 DOWNTO 0);
            BEGIN
                ac_row1i <= ac_row1 & bd(2 * cut - 1 DOWNTO cut + p);
                ac_row2i <= ac_row2 & STD_LOGIC_VECTOR(to_unsigned(0, cut - p));
                final_csa_x <= csa_ac_puv_c & csa_ac_puv_s & bd(cut + p - 1 DOWNTO 0);
                csa_ac_ab_cdqp : CSA4i
                GENERIC MAP(n => width_pq)
                PORT MAP(
                    w => ac_row1i,
                    x => ac_row2i,
                    y => pu,
                    z => pv,
                    cout => csa_ac_puv_c,
                    s => csa_ac_puv_s
                );
            END GENERATE;
            bd <= bd_row1 + bd_row2 WHEN bd_e = '1'ELSE
                (OTHERS => '0');

            csa_final : CSA2iPQ GENERIC MAP(n => 2 * width, P => P, cut => cut)
            PORT MAP(
                x => final_csa_x,
                y => final_csa_y,
                z => final_csa_z,
                s => res
            );

            --    final_csa_x <= csa_ac_puv_c & csa_ac_puv_s & bd; -- 1+11+10
            final_csa_y <= csa_bc_ad_c & csa_bc_ad_s WHEN bc_e = '1' AND ad_e = '1' ELSE
                (OTHERS => '0');
            final_csa_z <= (x AND y);

            mantissa <= res(2 * width - 1 DOWNTO 0);
        END kacy_mul_arch;