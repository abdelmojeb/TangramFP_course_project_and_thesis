----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/02/2024 04:02:04 PM
-- Design Name: 
-- Module Name: MAC - Behavioral
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
use work.all;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity MAC is
    Port ( a : in  STD_LOGIC_VECTOR (31 downto 0);
           b : in  STD_LOGIC_VECTOR (31 downto 0);
           c : in STD_LOGIC_VECTOR (31 downto 0);
           clk, n_rst : in STD_LOGIC;
           sum : out STD_LOGIC_VECTOR (31 downto 0));
end MAC;

architecture Behavioral of MAC is
    component fp_mult
    generic (width : integer := 24; cut : integer := 11);
        Port ( a : in STD_LOGIC_VECTOR (31 downto 0);
               b : in STD_LOGIC_VECTOR (31 downto 0);
               mode : in std_logic_vector (1 downto 0);
               result : out STD_LOGIC_VECTOR (63 downto 0);
               clk : in STD_LOGIC;
               n_rst : in STD_LOGIC);
    end component;
    
    component add_fp is
      generic (precision : integer := 64; man_width : integer := 52);
      Port (a : in std_logic_vector(precision-1 downto 0);
            b : in std_logic_vector(precision-1 downto 0);
            result : out std_logic_vector(precision-1 downto 0));
    end component;
    
    constant precision : integer range 0 to 128:=32; 
     constant precision64 : integer range 0 to 128:=64;
     constant ex_width: integer range 0 to 32:=8;
     constant man_width: integer range 0 to 32:= 23;
     constant cut : integer range 0 to 32 := 11;
     constant offset : integer range 0 to 32 := 0;
    constant FULL : std_logic_vector(1 downto 0) := "00";
    constant SKIP_BD : std_logic_vector(1 downto 0) := "01";
    constant AC_ONLY: std_logic_vector(1 downto 0) := "10";
    constant SKIP : std_logic_vector(1 downto 0) := "11";
    constant thr1 : natural range 0 to 64 := cut + offset;
    constant thr2 : natural range 0 to 64:= man_width;
    
    signal sumout :  STD_LOGIC_VECTOR (31 downto 0);
    signal exp_a, exp_b, exp_c,exp_ab : integer;
    
--    signal exp_a_norm, exp_b_norm, exp_c_norm,exp_ab : signed(9 downto 0);
 
    signal diff : integer range -255 to 255;--signed(ex_width downto 0);
    signal mantissa_a, mantissa_b, mantissa_c: unsigned(22 downto 0);
    
    signal mode : std_logic_vector(1 downto 0);
    
    signal ab, ab_add_in : std_logic_vector(63 downto 0):= (others => '0');
    
    signal am,bm,cm : std_logic_vector(31 downto 0);
    
    signal a_mult_in : std_logic_vector(31 downto 0) := (others => '0');
    
    signal b_mult_in : std_logic_vector(31 downto 0) := (others => '0');
    
    signal sum_64_out,sum_64_in,c_to_adder : std_logic_vector(63 downto 0);
    
    signal z_mult, z_mult_d,nan_input,nan_op,z_sum : std_logic;
--    constant nan_value : std_logic_vector(31 downto 0) := (others => '1');
--    signal trigger : std_logic:='0';
    --32 to 64 conversion
        function float_32_to_64 (f : std_logic_vector(31 downto 0))
        return std_logic_vector is
        variable exp_old : integer := to_integer(unsigned(f(30 downto 23)));
        variable exp : unsigned (10 downto 0) := (others=>'0');
        variable m : unsigned (22 downto 0):= unsigned(f(22 downto 0));
        variable shift_count : natural range 0 to 32 := 0;
        begin
            
            if (exp_old = 0)then
                for i in 22 downto 0 loop
                if m(i) = '1' then 
                    shift_count := 23-i;
                    exit;  -- Found first '1' in subnormal
                end if;
                end loop;
                exp := to_unsigned(1023 - shift_count,11);  -- Convert position to biased exponent
                m := shift_left(m, 23-shift_count); 
           elsif (exp_old > 0 and exp_old < 255 ) then
                exp := to_unsigned((exp_old + 896), 11);
--            elsif(exp = 0) then
--            exp := (others => '0');
            elsif(exp_old > 254)then
                exp := (others => '1');
            else
                exp := (others => '0');
                m:= (others => '0');
            end if;
        return f(31)& std_logic_vector(exp)&std_logic_vector(m) & std_logic_vector(to_unsigned(0,29));
    end function;
    
    function float_64_to_32 (f : std_logic_vector(63 downto 0))
    return std_logic_vector is
        variable v : integer := 16777215;
        variable exp :unsigned(10 downto 0) := unsigned(f(62 downto 52));
        variable mantissa : unsigned (24 downto 0) :=  '0'& unsigned(f(51 downto 28)) +1;
        begin
            if (to_integer(exp) < 873)then 
                exp := (others=> '0');
                mantissa := (others => '0');
            
            elsif (to_integer(exp) > 872 and to_integer(exp) < 897)then
                report integer'image(to_integer(mantissa));
                mantissa := mantissa + to_unsigned(16777215,25);
                report integer'image(to_integer(mantissa));
                mantissa := shift_right(mantissa, (897 - to_integer(exp))) +1;
                report integer'image(to_integer(mantissa));
                mantissa := shift_right(mantissa, 1);
                report integer'image(to_integer(mantissa));
                exp := (others=> '0');
            elsif (to_integer(exp) > 896)then
                exp := exp - 896;
                mantissa := shift_right(mantissa, 1);
            elsif (to_integer(exp) > 1150) then
                exp := (others=> '1');
            else 
                exp := (others=> '0');
                mantissa := (others => '0');
            end if;
            
        return f(63)& std_logic_vector(exp(7 downto 0)) & std_logic_vector(mantissa(22 downto 0));
end function;
 


    --variable exp : std_logic_vector(10 downto 0):=
--             std_logic_vector(unsigned(f(precision-2 downto man_width))+896);
begin
fp_multiply : fp_mult 
    generic map (width  => man_width+1, cut => cut)
    Port map( a => a_mult_in,
           b => b_mult_in,
           mode => mode,
           result => ab,
           clk => clk,
           n_rst => n_rst);
fp_add : add_fp
generic map (precision => 64, man_width => 52)
  Port map (a  => sum_64_in,
        b  => ab_add_in,
        result  => sum_64_out);
 
-- exp_a <= unsigned(a(precision-2 downto man_width));       
-- exp_b <= unsigned(b(precision-2 downto man_width));  
-- exp_c <= unsigned(c(precision-2 downto man_width));
 mantissa_a <= unsigned(a(man_width-1 downto 0));
 mantissa_b <= unsigned(b(man_width-1 downto 0));
 mantissa_c <= unsigned(c(man_width-1 downto 0));

 exp_a <= to_integer(unsigned(a(precision-2 downto man_width)));       
 exp_b <= to_integer(unsigned(b(precision-2 downto man_width)));  
 exp_c <= 1 when unsigned(c(precision-2 downto man_width)) = 0 else to_integer(unsigned(c(precision-2 downto man_width)));    

 subnormal_a : process (a,exp_a,mantissa_a)
    begin
    if (exp_a = 0 and mantissa_a /= 0) then
        am <= std_logic_vector(a(precision-1)&to_unsigned(1, ex_width)&to_unsigned(0, man_width));
    else
        am <= a;
    end if;   
 end process;
 subnormal_b : process (b,exp_b,mantissa_b)
    begin
    if (exp_b = 0 and mantissa_b /= 0) then
        bm <= std_logic_vector(b(precision-1)&to_unsigned(1, ex_width)&to_unsigned(0, man_width));
    else
        bm <= b;
    end if;   
 end process;      
        
         
 zero_ab: process(am,bm,exp_ab)
    begin
    if (unsigned(am(precision-2 downto 0) )= 0 or unsigned(bm(precision-2 downto 0)) = 0 or exp_ab < 0) then
        z_mult <= '1';
    else
        z_mult <= '0';
    end if;
end process;

 

 nan_operation: process(exp_ab,exp_a,exp_b,exp_c)
    begin
    if (exp_a=255 or --to_unsigned(255,ex_width)
     exp_b= 255 or --to_unsigned(255,ex_width)
     exp_c = 255 or exp_ab > 254) then -- to_unsigned(255,ex_width)
       nan_input <= '1';
    else
       nan_input <= '0';
    end if;
end process;
--nan_ab_addition: process(ab)
--    begin
--        if (unsigned(ab(precision64-2 downto 52)) > 1150) then -- to_unsigned(1150,ex_width+3)) then
--           nan_add <= '1';
--        else
--           nan_add <= '0';
--        end if;
--    end process;
subnormal : process (c)--c,exp_c,mantissa_c
    begin
--    if clk'event and clk='0'then 
--        if n_rst = '0' then
            
--            cm <= (others => '0');
--        else
            nan_op <= nan_input;
            z_mult_d <= z_mult;
            if (exp_c = 0 and mantissa_c /= 0) then
                cm <= std_logic_vector(c(precision-1)&to_unsigned(1, ex_width)&to_unsigned(0, man_width));
                c_to_adder <= float_32_to_64(std_logic_vector(c(precision-1)&to_unsigned(1, ex_width)&to_unsigned(0, man_width)));
            else
                cm <= c;
                c_to_adder <= float_32_to_64(c);
            end if; 
            
--        end if;
--    end if;
    end process;
zero_sum: process(cm)
        begin
            if (unsigned(cm(precision-2 downto 0)) = 0) then
                z_sum <= '1';
            else
                z_sum <= '0';
            end if;
        end process; 
 --multiplication      
 exp_ab <= exp_a + exp_b - 127 when exp_a > 0 and exp_b > 0  else 0;
 diff <= exp_c - exp_ab when exp_c > 0 or exp_ab > 0 else 0 ;
 
 
 process(exp_a,exp_b,exp_ab,nan_input,z_mult, am,bm,diff,n_rst)--exp_a,exp_b,exp_ab,nan_input,z_mult, am,bm,diff,n_rst
 begin
--    if clk'event and clk='1'then 
        if n_rst = '0' then
            a_mult_in <= (others => '0');
            b_mult_in <= (others => '0');
            mode <= SKIP;
        else
--            trigger <= not trigger;
            if nan_input = '0' and z_mult = '0' then
                a_mult_in <= am;
                b_mult_in <= bm;
                if (diff = 0 or diff < 0) then
                    mode <= Full;
                elsif (diff > 0 and diff < thr1) then
                    mode <= SKIP_BD;
                elsif (diff >= thr1 and diff < thr2)then
                    mode <= AC_ONLY;
                elsif (diff >= thr2) then
                    mode <= SKIP;
                else
                    mode <= SKIP;
                end if;
           else
                a_mult_in <= (others => '0');
                b_mult_in <= (others => '0');
                mode <= SKIP;
      end if;
   end if;
--  end if;
  end process;
        
 -- Addition
 process (ab,c_to_adder,z_sum,nan_op,n_rst,z_mult_d)--ab,c_to_adder,z_sum,nan_op,n_rst,z_mult_d
 begin
--    if clk'event and clk='0' then 
        if n_rst = '0' then
             ab_add_in <= (others => '0');
             sum_64_in <= (others => '0');
         else
             if nan_op = '0' and z_sum = '0'and z_mult_d = '0' then        
                ab_add_in <= ab;
                sum_64_in <= c_to_adder;
             else
                ab_add_in <= (others => '0');
                sum_64_in <= (others => '0');
             end if; 
        end if;      
--   end if;
end process;
--transform result
process(sum_64_out,nan_input,z_mult_d,z_sum,cm,ab,nan_op)
    begin 
    if (nan_op = '1')then
                sumout <= (others => '1');--nan_value;
        else
           if (z_mult_d = '0' and z_sum = '0') then
               sumout <= float_64_to_32(sum_64_out);
           elsif(z_mult_d = '1' and z_sum = '0') then
               sumout <= cm;
           elsif( z_mult_d = '0' and z_sum = '1')then
                sumout <= float_64_to_32(ab);
           else
                sumout <= (others => '0');
           end if;
     end if;
end process;
output: process (clk)  --sum_64_out,nan_input,z_mult_d,z_sum,cm,ab,nan_op 
    begin
    if rising_edge(clk) then
        if n_rst = '0' then
            sum <= (others => '0');
        else
            sum <= sumout;
       end if;
    end if;
   end process;        
end Behavioral;