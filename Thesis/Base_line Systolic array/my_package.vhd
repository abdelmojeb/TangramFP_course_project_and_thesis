library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
package my_types is

    constant N : integer := 4;
    constant Pre_in: integer :=32;
    constant ex_width_in : integer := 8;
    constant cut : integer := 11;
    constant offset : integer range 0 to 32 := 0;
    
    constant Pre_out : integer := Pre_in*2;
    constant ex_width_out: integer range 0 to 16:=ex_width_in+3;
    constant man_width_in: integer range 0 to 32:= Pre_in-ex_width_in -1;
    constant man_width_out: integer range 0 to 64:= Pre_out-ex_width_out -1;
    constant thr1: integer := cut;
    constant thr2 : integer := man_width_in;
    
    type mode_array is array (0 to N-1)  of std_logic_vector(2*N-1 downto 0);
end package;