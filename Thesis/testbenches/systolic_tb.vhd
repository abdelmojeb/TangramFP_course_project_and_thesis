----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/05/2025 03:18:30 PM
-- Design Name: 
-- Module Name: systolic_tb - Behavioral
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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.TB_tools.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
use ieee.numeric_std.all;

entity systolic_tb is
generic(N : integer range 0 to 128 := 4; -- Matrix size
        Pre_in : integer range 0 to 32 := 16;
        Pre_out : integer range 0 to 64 := 32);
end entity;

architecture test of systolic_tb is
    signal clk : std_logic := '0';
    signal A, B : std_logic_vector(4*4*Pre_in-1 downto 0);
    signal C : std_logic_vector(4*4*Pre_out-1 downto 0);
    signal n_rst : std_logic:='0';
    signal en : std_logic:='0';
    signal done : std_logic;
    -- Function to convert integer to 8-bit std_logic_vector
    function int_to_slv(val : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(val, Pre_in));
    end function;

begin
clk <= not clk after 5 ns;
    UUT: entity work.systolic_array
        --generic map (N => 4,Pre_in=>Pre_in,Pre_out=>Pre_out)
        port map (
            clk => clk,
            n_rst => n_rst,
            A => A,
            B => B,
            C => C,
            done => done,
            en => en
        );

    process
    begin
     wait for 10 ns;
           n_rst <= '1';
           
        for i in 0 to N-1 loop
            for j in 0 to N-1 loop
        -- Matrix A initialization (values 1 to 4)
                A((i*N + j)*Pre_in + Pre_in-1 downto (i*N + j)*Pre_in)  <= float_to_half(real_to_float(real(j mod 4)+1.0));--int_to_slv((j mod 4)+1);   -- A[0,0]
                -- Matrix B initialization (values 1 to 4)
                B((i*N + j)*Pre_in + Pre_in-1 downto (i*N + j)*Pre_in)  <= float_to_half(real_to_float(real(j mod 4)+1.0));--int_to_slv((j mod 4)+1);   -- B[0,0]
                report to_string(j) & "element j: " & to_string((j mod 4)+1);
            end loop;
        end loop;
       wait until rising_edge(clk);
       en <='1';
       wait until rising_edge(clk);
--       if done ='1' then en <='0'; end if; 
       wait until done = '1';
       en <='0';
        -- Wait to observe results
        wait for 50 ns;

        -- Additional test cases can be added here
        
        assert false report "Simulation finished" severity note;
        wait;
    end process;
end architecture;
