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

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Basic 6-bit LZC to maximize single LUT usage
ENTITY lzc_6bit IS
    PORT (
        x : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
        z : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        v : OUT STD_LOGIC
    );
END lzc_6bit;

ARCHITECTURE rtl OF lzc_6bit IS
    -- This will map to a single 6-LUT
BEGIN
    PROCESS (x)
    BEGIN
        IF x(5) = '1' THEN
            z <= "000";
            v <= '0';
        ELSIF x(4) = '1' THEN
            z <= "001";
            v <= '0';
        ELSIF x(3) = '1' THEN
            z <= "010";
            v <= '0';
        ELSIF x(2) = '1' THEN
            z <= "011";
            v <= '0';
        ELSIF x(1) = '1' THEN
            z <= "100";
            v <= '0';
        ELSIF x(0) = '1' THEN
            z <= "101";
            v <= '0';
        ELSE
            z <= "110";
            v <= '1';
        END IF;
    END PROCESS;
END rtl;
-- Main 54-bit LZC optimized for Kintex-7
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
ENTITY lzc_54 IS
    GENERIC (
        N : INTEGER -- Mantissa width
    );
    PORT (
        mantissa : IN STD_LOGIC_VECTOR(N DOWNTO 0);
        enable : IN STD_LOGIC;
        shift_count : OUT STD_LOGIC_VECTOR(5 DOWNTO 0)
    );
END lzc_54;

ARCHITECTURE rtl54 OF lzc_54 IS
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
    TYPE v_array IS ARRAY (8 DOWNTO 0) OF STD_LOGIC;
    TYPE z_array IS ARRAY (8 DOWNTO 0) OF STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL first_level_v : STD_LOGIC_VECTOR(8 DOWNTO 0);--v_array;
    SIGNAL first_level_z : z_array;

    SIGNAL first_valid_block : unsigned(2 DOWNTO 0); -- Encoding of which block
    SIGNAL base_count : unsigned(5 DOWNTO 0);

BEGIN
    -- First level: Generate 9 6-bit LZC blocks
    gen_first_level : FOR i IN 0 TO 8 GENERATE
        -- Handle the last incomplete block
        last_block : IF i = 8 GENERATE
            lzc_block : lzc_6bit
            PORT MAP(
                x => mantissa(53 DOWNTO 48),
                z => first_level_z(i),
                v => first_level_v(i)
            );
        END GENERATE last_block;

        -- Regular blocks
        regular_block : IF i < 8 GENERATE
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
        IF enable = '0' THEN
            first_valid_block <= (OTHERS => '0');
            base_count <= (OTHERS => '0');
        ELSIF first_level_v(8) = '0' THEN
            first_valid_block <= unsigned(first_level_z(8));
            base_count <= "000000";
        ELSIF first_level_v(7) = '0' THEN
            first_valid_block <= unsigned(first_level_z(7));
            base_count <= to_unsigned(6, 6);
        ELSIF first_level_v(6) = '0' THEN
            first_valid_block <= unsigned(first_level_z(6));
            base_count <= to_unsigned(12, 6);
        ELSIF first_level_v(5) = '0' THEN
            first_valid_block <= unsigned(first_level_z(5));
            base_count <= to_unsigned(18, 6);
        ELSIF first_level_v(4) = '0' THEN
            first_valid_block <= unsigned(first_level_z(4));
            base_count <= to_unsigned(24, 6);
        ELSIF first_level_v(3) = '0' THEN
            first_valid_block <= unsigned(first_level_z(3));
            base_count <= to_unsigned(30, 6);
        ELSIF first_level_v(2) = '0' THEN
            first_valid_block <= unsigned(first_level_z(2));
            base_count <= to_unsigned(36, 6);
        ELSIF first_level_v(1) = '0' THEN
            first_valid_block <= unsigned(first_level_z(1));
            base_count <= to_unsigned(42, 6);
        ELSIF first_level_v(0) = '0' THEN
            first_valid_block <= unsigned(first_level_z(0));
            base_count <= to_unsigned(48, 6);
        ELSE
            first_valid_block <= to_unsigned(6, 3);
            base_count <= to_unsigned(48, 6);
        END IF;
    END PROCESS;
    shift_count <= STD_LOGIC_VECTOR(base_count + first_valid_block);
END rtl54;