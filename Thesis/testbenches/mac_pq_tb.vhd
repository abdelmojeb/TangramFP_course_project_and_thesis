----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/23/2025 08:07:33 PM
-- Design Name: 
-- Module Name: mac_pq_tb - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity mac_pq_tb is
--  Port ( );
end mac_pq_tb;

architecture Behavioral of mac_pq_tb is
signal clk : std_logic := '0';
        signal n_rst : std_logic := '0';
        signal a, b : std_logic_vector(32-1 downto 0);
        signal result,c: std_logic_vector(63 downto 0);
        signal mode : std_logic_vector(1 downto 0);
        signal reset : std_logic;
begin
clk <= not clk after 5 ns;
uut : entity work.MAC_external_mode_pq 
generic map ( precision_in => 32,--:=16; 
     precision_out => 64,--:=32;
     ex_width_in=> 8,--:=5;
     man_width_in=> 23 ,--:= 10;
     ex_width_out=>11,--:=8;
     man_width_out => 52,--:= 23;
     cut => 11,-- := 5;
     offset => 0
     )
    Port map ( a => a,
           b => b,
           c =>c,
           modein => mode, --systolic array input
           clk => clk, n_rst  => reset,
           sumout  => result
           );
process
begin
reset <= '0' ;
wait for 10 ns;
reset <= '1' ;

--      a       b    c
--/* 1	3.5   2.25	0.0	    z_sum (C=0) ? pass P straight through	7.875
--  2	3.5   2.25	256.0	ADD, exp_C (8) > exp_P (2) ? shift P right, then add	263.875 (=256 + 7.875)
--  3	3.5	  2.25	1.0	    ADD, exp_P (2) > exp_C (0) ? shift C right, then add	8.875 (=1 + 7.875)
--  4	1.5	  3.0	4.0	    ADD, exp_C = exp_P (=2) ? no shifts	8.5 (=4.0 + 4.5)
--  5	2.0	  3.0	-7.0	SUB, exp_C = exp_P (=2),	C
--  6	2.0	  3.5	-6.0	SUB, exp_C = exp_P (=2),	P
--  7	2.0	  3.0	-6.0	SUB, exp_C = exp_P,	C
--  8	1.0	  1.0	-4.0	SUB, exp_C (2) > exp_P (0) ? shift P, C's exp larger	-5.0 (=-4.0 - 1.0)
--  9	4.0	  4.0	-3.0	SUB, exp_P (4) > exp_C (1) ? shift C, P's exp larger	+13.0 (=16.0 - 3.0)
--*/
wait for 20 ns;
a <= real_to_float(real(-2));
c <= float_32_to_64(real_to_float(real(2)));
b <= real_to_float(real(1));
mode <= "00";
wait for 20 ns;
a <= real_to_float(real(2));
c <= float_32_to_64(real_to_float(real(2)));
b <= real_to_float(real(1));
mode <= "00";
wait for 20 ns;
a <= real_to_float(real(2));
c <= float_32_to_64(real_to_float(real(-2)));
b <= real_to_float(real(-1));
mode <= "00";
wait for 20 ns;
a <= real_to_float(real(0));
c <= float_32_to_64(real_to_float(real(-2)));
b <= real_to_float(real(-1));
mode <= "00";
wait for 20 ns;
a <= real_to_float(real(2));
c <= float_32_to_64(real_to_float(real(0)));
b <= real_to_float(real(-1));
mode <= "00";
wait for 20 ns;
a <= real_to_float(real(-2));
c <= float_32_to_64(real_to_float(real(-2)));
b <= real_to_float(real(4));
mode <= "11";
wait for 20 ns;
a <= float_to_half(real_to_float(real(65519)));
c <= real_to_float(real(1));
b <= float_to_half(real_to_float(real(4)));
mode <= "00";
wait;
end process;

end Behavioral;
