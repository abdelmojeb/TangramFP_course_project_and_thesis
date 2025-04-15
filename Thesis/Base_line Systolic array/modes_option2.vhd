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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use work.my_types.all;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity modes_option2 is
  Port ( clk  : in std_logic;
        n_rst : in std_logic;
        en    : in std_logic;
        A, B  : in std_logic_vector(N*N*Pre_in-1 downto 0); -- Flattened input matrices
        modes : out  mode_array);
end modes_option2;

architecture Behavioral of modes_option2 is
type exp_array is array  (0 to N-1,0 to N-1) of unsigned(ex_width_in downto 0); 
type max_array is array (0 to N-1) of unsigned(ex_width_in downto 0);
type mode_array is array (0 to N-1) of std_logic_vector(2*N-1 downto 0);
type mode_Barray is array (0 to N-1,0 to N-1) of std_logic_vector(2*N-1 downto 0); -- squre buffer
signal A_exp, B_exp : exp_array;
signal i : integer := 0;
signal mode_buffer : mode_array;
signal mode_Buffer2 : mode_Barray;

begin
--put the exponents of A, B into N by N matrices.
exponent:process(A,B)
begin
            for i in 0 to N-1 loop
    for j in 0 to N-1 loop
        A_exp(i, j) <= unsigned('0' & A((i*N + j)*Pre_in + Pre_in-2 downto (i*N + j)*Pre_in+(pre_in - ex_width_in-1)));--pre_in-exp_width-1 =  man_width
        B_exp(i, j) <= unsigned('0' & B((i*N + j)*Pre_in + Pre_in-2 downto (i*N + j)*Pre_in+(pre_in - ex_width_in-1)));
    end loop;
end loop;
end process; 
--determine the max exp for each all rows in b and 1 column in a
--determine mode of multiplication for a column and all b rows
mode: process(clk)
variable AB_exp : unsigned(ex_width_in downto 0):=  (others => '0');
variable exp_max : max_array := (others => (others => '0'));
variable dif : signed(ex_width_in downto 0):= (others => '0');
variable mode :mode_array := (others => (others => '0'));
    begin
        if rising_edge(clk) and i < N and en = '1' then
--            if (n_rst = '0') then
--                mode_buffer <= (others => (others => '1'));
--            else
            -- determine the maximum exponent in the ab vectors dot multiplication
                for j in 0 to N-1 loop
                    for k in 0 to N-1 loop
                        AB_exp := A_exp(k,i) + B_exp(j,k) - 127;
                        if exp_max(j) < AB_exp then
                            exp_max(j) := AB_exp;
                        end if;
                    end loop;
                end loop;
                
           -- compute the mode vector for every a culomn
              for j in 0 to N-1 loop
                for k in 0 to N-1 loop       
                    AB_exp := A_exp(k,i) + B_exp(j,k) - 127;
                    dif := signed(exp_max(j)) - signed(AB_exp);
                     if (dif = 0 or dif < 0) then
                         mode(k)(j*2+1 downto j*2) := "00";--Full;
                     elsif (dif > 0 and dif < thr1) then
                         mode(k)(j*2+1 downto j*2) := "01";---SKIP_BD;
                     elsif (dif >= thr1 and dif < thr2)then
                         mode(k)(j*2+1 downto j*2) := "10";--AC_ONLY;
                     elsif (dif >= thr2) then
                         mode(k)(j*2+1 downto j*2) := "11";--SKIP;
                     else
                         mode(k)(j*2+1 downto j*2) := "11";--SKIP;
                     end if;
                end loop;
             end loop;
            mode_buffer <= mode;
            i <= i+1;-- when i < N-1 else 0;

       end if;  
   end process mode;
      --shifting mode input square buffer buffers 

        process (clk)
            begin
            if rising_edge(clk) and en = '1' then
                for m in 0 to N-1 loop
                    for n in 0 to N-1 loop
                        mode_Buffer2(m,n-1) <= mode_Buffer2(m,n) when n /=0;
                    end loop;
                    mode_Buffer2(m,m) <= mode_Buffer(m);
                end loop;
            end if;
        end process;
        
        --tringluar buffers
        buf : for i in 0 to N-1 generate 
            signal mbuffer : std_logic_vector(2*N*(i+1)-1 downto 0);
            begin
                modes(i) <= mbuffer(2*N-1 downto 0);
                
            process(clk)
                begin
                    if rising_edge(clk)and en = '1' then 
                        mbuffer <= std_logic_vector(shift_right(unsigned(mbuffer), 2*N));
                        mbuffer(2*N*(i+1)-1 downto 2*N*i) <= mode_buffer(i);
                    end if;
                end process;
                
        end generate;
end Behavioral;
