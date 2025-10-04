----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01/20/2025 07:01:17 PM
-- Design Name: 
-- Module Name: LZC - Behavioral
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
-- [1]. Nebojša Z. Milenković and Vladimir V. Stanković and Miljana Lj. Milić, "MODULAR DESIGN OF FAST LEADING ZEROS COUNTING CIRCUIT", Journal of ELECTRICAL ENGINEERING, VOL. 66, NO. 6, 2015, 329-333
ARCHITECTURE rtl25 OF lzc_54 IS
    COMPONENT lzc_6bit IS
        PORT (
            x : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
            z : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
            v : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT priority_encoder_6 IS
        PORT (
            v : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
            z : OUT STD_LOGIC_VECTOR(2 DOWNTO 0)
        );
    END COMPONENT;

    -- Signals for the first level (9 groups of 6 bits)
    --    type v_array is array (8 downto 0) of std_logic;
    TYPE z_array IS ARRAY (4 DOWNTO 0) OF STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL first_level_v : STD_LOGIC_VECTOR(4 DOWNTO 0);--v_array;
    SIGNAL first_level_z : z_array;

    SIGNAL first_valid_block : unsigned(2 DOWNTO 0); -- Encoding of which block
    SIGNAL base_count : unsigned(5 DOWNTO 0);

BEGIN
    -- First level: Generate 9 6-bit LZC blocks
    gen_first_level : FOR i IN 0 TO 4 GENERATE
        -- Handle the last incomplete block
        last_block : IF i = 4 GENERATE
            first_level_z(4) <= "00" & NOT mantissa(24);
            first_level_v(4) <= NOT mantissa(24);
        END GENERATE last_block;

        -- Regular blocks
        regular_block : IF i < 4 GENERATE
            lzc_block : lzc_6bit
            PORT MAP(
                x => mantissa((i * 6 + 5) DOWNTO (i * 6)),
                z => first_level_z(i),
                v => first_level_v(i)
            );
        END GENERATE regular_block;
    END GENERATE gen_first_level;
    PROCESS (first_level_v, first_level_z, enable)
    BEGIN
        IF enable = '1' THEN
            --               
            IF first_level_v(4) = '0' THEN
                first_valid_block <= unsigned(first_level_z(4));
                base_count <= to_unsigned(0, 6);
            ELSIF first_level_v(3) = '0' THEN
                first_valid_block <= unsigned(first_level_z(3));
                base_count <= to_unsigned(1, 6);
            ELSIF first_level_v(2) = '0' THEN
                first_valid_block <= unsigned(first_level_z(2));
                base_count <= to_unsigned(7, 6);
            ELSIF first_level_v(1) = '0' THEN
                first_valid_block <= unsigned(first_level_z(1));
                base_count <= to_unsigned(13, 6);
            ELSIF first_level_v(0) = '0' THEN
                first_valid_block <= unsigned(first_level_z(0));
                base_count <= to_unsigned(19, 6);
            ELSE
                first_valid_block <= to_unsigned(0, 3);
                base_count <= to_unsigned(0, 6);
            END IF;
        END IF;
    END PROCESS;
    shift_count <= STD_LOGIC_VECTOR(base_count + first_valid_block);
END rtl25;