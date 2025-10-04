----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/04/2025 02:50:32 PM
-- Design Name: 
-- Module Name: modes_option2_tb - Behavioral
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



-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library IEEE;
library work;
use IEEE.STD_LOGIC_1164.ALL;
use work.TB_tools.all;
use work.my_types.all;
use ieee.numeric_std.all;

entity modes_option2_tb is
generic(N : integer range 0 to 128 := 4; -- Matrix size
        Pre_in : integer range 0 to 32 := Pre_in;
        Pre_out : integer range 0 to 64 := Pre_out);
end modes_option2_tb;

architecture test of modes_option2_tb is
    signal clk : std_logic := '0';
    signal A: max_array := (to_unsigned(30, ex_width_in+1),to_unsigned(0, ex_width_in+1),to_unsigned(15, ex_width_in+1),to_unsigned(15, ex_width_in+1));
    signal B :exp_array := (
        (to_unsigned(30, ex_width_in+1), to_unsigned(0, ex_width_in+1), to_unsigned(16, ex_width_in+1), to_unsigned(0, ex_width_in+1)),
        (to_unsigned(17, ex_width_in+1), to_unsigned(17, ex_width_in+1), to_unsigned(17, ex_width_in+1), to_unsigned(18, ex_width_in+1)),
        (to_unsigned(18, ex_width_in+1), to_unsigned(18, ex_width_in+1), to_unsigned(18, ex_width_in+1), to_unsigned(18, ex_width_in+1)),
        (to_unsigned(18, ex_width_in+1), to_unsigned(18, ex_width_in+1), to_unsigned(18, ex_width_in+1), to_unsigned(19, ex_width_in+1))
    );
    signal A_EXP: max_array;
    signal expB_in: unsigned (ex_width_in downto 0);
    signal modes,modes1:  mode_array;
    signal n_rst : std_logic:='0';
    signal en : std_logic:='0';
    signal done : std_logic;
    signal col,row : integer;
    signal enB,rwB : std_logic;
    constant period : time := 5 ns;
    -- Function to convert integer to 8-bit std_logic_vector
    function int_to_slv(val : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(val, Pre_in));
    end function;

begin
clk <= not clk after period ;
    UUT1: entity work.modes_op2_pipe2
        port map (
            clk => clk,
            n_rst => n_rst,
            en => en,
            A_exp => A_EXP,
            expB_in => expB_in,
            col => col,
            row => row,
            enB => enB,
            rwB => rwB,
            modes=> modes
        );
--    UUT2: entity work.modes_op2_pipe2
--            port map (
--                clk => clk,
--                n_rst => n_rst,
--                en => en,
--                A_exp => A_EXP,
--                expB_in => expB_in,
--                col => col,
--                row => row,
--                enB => enB,
--                rwB => rwB,
--                modes=> modes1
--            );
    process
    begin
     wait for 10 ns;
           n_rst <= '1'; 
           


        -- Wait to observe results
        
        enB <= '1';
        rwB <= '1';
        
        for i in 0 to N-1 loop
           for j in 0 to N-1 loop
                expB_in <= B(i,j);
                col <= j;
                row <= i;
                wait for period*2;
           end loop;
        end loop;
        wait for period;
        en <= '1';
        A_EXP <= A;
        wait for 50 ns;
        en <='0';

        -- Additional test cases can be added here
        
        assert false report "Simulation finished" severity note;
        wait;
    end process;
 
end architecture;
