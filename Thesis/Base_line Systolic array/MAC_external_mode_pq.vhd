----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/15/2025 05:42:33 PM
-- Design Name: 
-- Module Name: MAC_external_mode_pq - Behavioral
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


entity MAC_external_mode_pq is
generic( precision_in : integer range 0 to 32;--:=16; 
     precision_out : integer range 0 to 64;--:=32;
     ex_width_in: integer range 0 to 16;--:=5;
     man_width_in: integer range 0 to 64;--:= 10;
     ex_width_out: integer range 0 to 16;--:=8;
     man_width_out: integer range 0 to 64;--:= 23;
     cut : integer range 0 to 32;-- := 5;
     offset : integer range 0 to 32-- := 0
     );
    Port ( a : in  STD_LOGIC_VECTOR (precision_in-1 downto 0);
           b : in  STD_LOGIC_VECTOR (precision_in-1 downto 0);
           c : in STD_LOGIC_VECTOR (precision_out-1 downto 0);
           modein: in std_logic_vector(1 downto 0); --systolic array input
           clk, n_rst : in STD_LOGIC;
           sumout : out STD_LOGIC_VECTOR (precision_out-1 downto 0));end MAC_external_mode_pq;

architecture Behavioral of MAC_external_mode_pq is

    component kacy_mul_p_q generic(width : integer ; cut : integer);
        port (
                u : in std_logic_vector(width-1 downto 0);
                v : in std_logic_vector(width-1 downto 0);
                mode : in std_logic_vector(1 downto 0);
                mantissa : out std_logic_vector(2*width-1 downto 0)
            );
    end component;
    
    component add_fp is
      generic (precision : integer := precision_out; man_width : integer := man_width_out;
      exp_width: integer range 0 to 31:= ex_width_out);
      Port (exp_ain,exp_bin : in unsigned(ex_width_out-1 downto 0);
              man_ain, man_bin : in std_logic_vector(man_width_out downto 0);
              sign_a,sign_b : in std_logic;
              z_sum : std_logic;
              result : out std_logic_vector(precision-1 downto 0));
    end component;
    --exponent comparison constants 
    constant bias_out : unsigned(ex_width_out-1 downto 0) :=  to_unsigned(2**(ex_width_out-1)-1,ex_width_out);
    constant bias_in  : unsigned(ex_width_out-1 downto 0) :=  to_unsigned(2**(ex_width_in-1)-1,ex_width_out);
      

    constant FULL : std_logic_vector(1 downto 0) := "00";
    constant SKIP_BD : std_logic_vector(1 downto 0) := "01";
    constant AC_ONLY: std_logic_vector(1 downto 0) := "10";
    constant SKIP : std_logic_vector(1 downto 0) := "11";
    constant thr1 : signed(ex_width_out-1 downto 0) := to_signed((cut + offset),ex_width_out);
    constant thr2 : signed(ex_width_out-1 downto 0) := to_signed(man_width_in,ex_width_out);
    
   
    signal exp_an: unsigned(ex_width_out-1 downto 0):= (others => '0');
    signal exp_bn: unsigned(ex_width_out-1 downto 0):= (others => '0');
    signal exp_cn: unsigned(ex_width_out-1 downto 0):= (others => '0');
    
    signal exp_ab: unsigned(ex_width_out-1 downto 0):= (others => '0');
    signal exp_a  : unsigned(ex_width_out-1 downto 0):= (others => '0');
    signal exp_b  : unsigned(ex_width_out-1 downto 0):= (others => '0');
    signal exp_c  : unsigned(ex_width_out-1 downto 0):= (others => '0');
    signal ex_cn_cmp, ex_ab_cmp :signed(ex_width_out downto 0);
    
    signal mantissa_a, mantissa_b: unsigned(man_width_in-1 downto 0);
    signal mantissa_c: unsigned(man_width_out-1 downto 0);
    signal mantissa_a_norm,mantissa_b_norm,u,v : std_logic_vector (man_width_in downto 0);
    signal mantissa_c_norm : std_logic_vector (man_width_out downto 0) := (others => '0');
    
    signal mode : std_logic_vector(1 downto 0);
    signal ab : std_logic_vector(man_width_out downto 0):= (others => '0');    
  
    signal ab_result : std_logic_vector(precision_out-1 downto 0) := (others => '0');    
    signal sum_pre_out : std_logic_vector(precision_out-1 downto 0);
        -- input to adder
    signal sum_32_in, ab_add_in : std_logic_vector(man_width_out downto 0);   
    signal sign_ab , sign_c,sign_ab_ad,sign_c_ad: std_logic:='0';
    signal exp_cn_addin,exp_ab_addin : unsigned(ex_width_out-1 downto 0);


    -- falgs
    signal a_zero,b_zero : std_logic;
    signal z_mult,nan_input,z_sum  : std_logic;
    signal mode_trigger : std_logic := '0';
    
    
    
 

-----------------------------------------------------------------------------------------------------------------------------------
    
attribute keep : string;
attribute keep of  exp_an : signal   is "true";
attribute keep of  exp_cn : signal   is "true";
attribute keep of  exp_bn : signal   is "true";
attribute keep of  mantissa_c_norm : signal   is "true";
attribute keep of  mantissa_c : signal   is "true";
attribute keep of  mantissa_a : signal   is "true";
attribute keep of  mantissa_b : signal   is "true";
attribute keep of sign_c_ad : signal is "true";

begin


--input sanitizing
sanitize : process (a,b,c)
begin
 mantissa_a <=  unsigned(a(man_width_in-1 downto 0));
 mantissa_b <=  unsigned(b(man_width_in-1 downto 0));
 mantissa_c <=  unsigned(c(man_width_out-1 downto 0));

 exp_a <= resize(unsigned(a(precision_in-2 downto man_width_in)),ex_width_out);       
 exp_b <= resize(unsigned(b(precision_in-2 downto man_width_in)),ex_width_out);  
 exp_c <= resize(unsigned(c(precision_out-2 downto man_width_out)),ex_width_out);-- + to_unsigned(112,ex_width_out);  --here  
end process;

 subnormal_a : process (a,exp_a,mantissa_a)
    begin
    if (exp_a /= 0 ) then--and mantissa_a /= 0
        mantissa_a_norm <= '1' & std_logic_vector (mantissa_a);
        exp_an <= exp_a;
        a_zero <= '0';
    elsif (exp_a = 0 and mantissa_a /= 0) then    
        mantissa_a_norm <= (others => '0');
        exp_an <= to_unsigned(1, ex_width_out);
        a_zero <= '0';
    else
        mantissa_a_norm <= (others => '0');
        exp_an <= to_unsigned(0, ex_width_out);
        a_zero <= '1';
    end if;   
 end process;
 subnormal_b : process (b,exp_b,mantissa_b)
    begin
    if (exp_b /= 0 ) then--and mantissa_b /= 0
        mantissa_b_norm <= '1' & std_logic_vector(mantissa_b);
        exp_bn <= exp_b;
        b_zero <= '0';
    elsif (exp_b = 0 and mantissa_b /= 0) then
        mantissa_b_norm <= (others => '0');
        exp_bn <= to_unsigned(1, ex_width_out);
        b_zero <= '0';
    else 
        mantissa_b_norm <= (others => '0');
        exp_bn <= to_unsigned(0, ex_width_out);
        b_zero <= '1';
 
    end if;   
 end process;      
        
         
 zero_ab: process(a_zero, b_zero)
    begin
    if (a_zero = '1' or b_zero='1') then
        z_mult <= '1';
    else
        z_mult <= '0';
    end if;
end process;

 

 nan_operation: process(exp_ab,exp_a,exp_b,exp_c)
    begin
    if (exp_a > bias_in*2 or 
     exp_b > bias_in*2 or 
     exp_c > (bias_in+bias_out) or exp_ab > (bias_in+bias_out)) then 
       nan_input <= '1';
    else
       nan_input <= '0';
    end if;
end process;

input_c : process (c,exp_c,mantissa_c,a(precision_in-1),b(precision_in-1),c(precision_in-1))
    begin
             sign_ab_ad <= a(precision_in-1) xor b(precision_in-1);
            if (exp_c > (bias_out-bias_in)  ) then--and mantissa_c > 0
                    mantissa_c_norm <=  std_logic_vector('1' & mantissa_c);
                    exp_cn <= exp_c;
                    sign_c_ad <= c(precision_in-1);
                    z_sum <= '0';
            elsif (exp_c = (bias_out-bias_in) and mantissa_c > 0) then
                    mantissa_c_norm <= (others => '0');
                    exp_cn <= to_unsigned(1, ex_width_out);
                    sign_c_ad <= c(precision_in-1);
                    z_sum <= '0';
            else  
                    mantissa_c_norm <= (others => '0');
                    exp_cn <= to_unsigned(0, ex_width_out);
                    sign_c_ad <= '0';
                    z_sum <= '1';
        
            end if; 
    end process;



 --multiplication 
 ab_exp : process(exp_an,exp_bn)   
 begin  
    exp_ab <= exp_an + exp_bn + (bias_out-bias_in-bias_in);

end process;



kacy_input: process(mode, mantissa_a_norm, mantissa_b_norm)--mode, mantissa_a_norm, mantissa_b_norm
begin
    if (mode /= "11" and n_rst ='1') then --add more conditions
        u <= mantissa_a_norm;
        v <= mantissa_b_norm;
    end if;
end process;

    
kacy : kacy_mul_p_q 
            generic map (
                 width => man_width_in+1,
                 cut  => cut)
            port map (
                  u=>u, v=>v,
                  mode=>modein,--modein comes from systolic array
                  mantissa=>ab(man_width_out downto (man_width_out+1)-(man_width_in+1)*2));
------------------------------------------------------------------------------------------------------------        
 -- Addition
 fp_add : add_fp 
 generic map (precision => precision_out, man_width => man_width_out)
   Port map (
         exp_ain => exp_cn_addin,
         exp_bin => exp_ab_addin,
         man_ain => sum_32_in,
         man_bin=> ab_add_in,
         sign_a => sign_c,
         sign_b => sign_ab,
         z_sum => z_sum,
         result => sum_pre_out);
                 
 adder_inputs :process (ab,exp_cn,sign_ab_ad,mantissa_c_norm,exp_ab,sign_c_ad,z_sum,nan_input, a_zero , b_zero)
 begin

             if nan_input = '0' and mode /= "11" and a_zero = '0' and  b_zero = '0' then        
                ab_add_in <= ab;
                sum_32_in <= mantissa_c_norm ;
                exp_cn_addin <= exp_cn;
                exp_ab_addin <= exp_ab;
                sign_c <= sign_c_ad;
                sign_ab <= sign_ab_ad;
             else
                ab_add_in <= (others => '0');
                sum_32_in <= (others => '0') ;
                exp_cn_addin <= (others => '0');
                exp_ab_addin <= (others => '0');
                sign_c <= '0';
                sign_ab <= '0';
             end if; 
--        end if;      
end process;



--prepare output to 32 bit
scaledown: process(clk)
    begin
    
    if rising_edge(clk) then
        if n_rst = '0' then 
            sumout <= (others => '0');
        else
           if (nan_input = '1')then
                sumout <= (others => '1');--nan_value;
           else
               if( mode = "11" or(z_mult = '1' and z_sum = '0') ) then
                   sumout <= sign_c_ad & std_logic_vector (exp_cn) & mantissa_c_norm(man_width_out-1 downto 0);
               elsif (z_mult = '0' ) then
                   sumout <= sum_pre_out;
               else
                    sumout <= (others => '0');
               end if;
           end if;
        end if;    
     end if;
   end process; 
   
  
            
end Behavioral;