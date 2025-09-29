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
    generic( precision32 : integer range 0 to 64:=32; 
     precision64 : integer range 0 to 128:=64;
     ex_width32: integer range 0 to 16:=8;
     man_width32: integer range 0 to 32:= 23;
     ex_width64: integer range 0 to 16:=11;
     man_width64: integer range 0 to 64:= 52;
     cut : integer range 0 to 32 := 11;
     offset : integer range 0 to 32 := 0);
    Port ( a : in  STD_LOGIC_VECTOR (precision32-1 downto 0);
           b : in  STD_LOGIC_VECTOR (precision32-1 downto 0);
           c : in STD_LOGIC_VECTOR (precision32-1 downto 0);
           clk, n_rst : in STD_LOGIC;
           sumout : out STD_LOGIC_VECTOR (precision64-1 downto 0));
end MAC;

architecture Behavioral of MAC is
    component fp_mult
    generic (width : integer := man_width32+1; cut : integer := cut);
        Port (
               clk : in STD_LOGIC;
               n_rst : in STD_LOGIC;
               mantissa_a,mantissa_b : in STD_LOGIC_VECTOR (man_width32 downto 0);
               exp_ab_in : in unsigned (ex_width64-1 downto 0);
               mode : in std_logic_vector (1 downto 0);
               dnt_mult: in std_logic;
               exp_ab: out unsigned (ex_width64-1 downto 0);
               mantissa_ab_norm: out STD_LOGIC_VECTOR (man_width64-1 downto 0)
                                        );
    end component;
    
    component add_fp is
      generic (precision : integer := 64; man_width : integer := man_width64);
      Port (exp_ain,exp_bin : in unsigned(ex_width64-1 downto 0);
              man_ain, man_bin : in std_logic_vector(man_width64 downto 0);
              sign_a,sign_b : in std_logic;
              result : out std_logic_vector(precision-1 downto 0));
    end component;
    

    constant FULL : std_logic_vector(1 downto 0) := "00";
    constant SKIP_BD : std_logic_vector(1 downto 0) := "01";
    constant AC_ONLY: std_logic_vector(1 downto 0) := "10";
    constant SKIP : std_logic_vector(1 downto 0) := "11";
    constant thr1 : signed(ex_width64-1 downto 0) := to_signed((cut + offset),11);
    constant thr2 : signed(ex_width64-1 downto 0) := to_signed(man_width,11);
    
   
    signal exp_an: unsigned(ex_width64-1 downto 0):= (others => '0');
    signal exp_bn: unsigned(ex_width64-1 downto 0):= (others => '0');
    signal exp_cn: unsigned(ex_width64-1 downto 0):= (others => '0');
    signal exp_cnd: unsigned(ex_width64-1 downto 0):= (others => '0');
    
    signal exp_ab: unsigned(ex_width64-1 downto 0):= (others => '0');
    signal exp_ab_out : unsigned(ex_width64-1 downto 0):= (others => '0');
    signal exp_a  : unsigned(ex_width64-1 downto 0):= (others => '0');
    signal exp_b  : unsigned(ex_width64-1 downto 0):= (others => '0');
    signal exp_c  : unsigned(ex_width64-1 downto 0):= (others => '0');
    signal diff : signed(ex_width64-1 downto 0) := (others =>'0');
    signal mantissa_a, mantissa_b, mantissa_c: unsigned(22 downto 0);
    signal mantissa_a_norm,mantissa_b_norm : std_logic_vector (man_width32 downto 0);
    signal mantissa_c_norm : std_logic_vector (man_width64 downto 0) := (others => '0');
    signal mantissa_c_normd : std_logic_vector (man_width64 downto 0) := (others => '0');
    
    signal mode : std_logic_vector(1 downto 0);
    signal ab : std_logic_vector(man_width64-1 downto 0):= (others => '0');    
  
    signal ab_result : std_logic_vector(precision64-1 downto 0) := (others => '0');    
    signal sum_64_out : std_logic_vector(precision64-1 downto 0);
        -- input to adder
    signal sum_64_in, ab_add_in : std_logic_vector(man_width64 downto 0);   
    signal sign_ab , sign_c,sign_ab_add,sign_c_add,sign_ab_ad,sign_c_ad: std_logic:='0';
    signal exp_cn_addin,exp_ab_addin : unsigned(ex_width64-1 downto 0);


    -- falgs
    signal a_zero,b_zero : std_logic;
    signal z_mult, z_mult_d,nan_input,nan_op,z_sum,z_sumd  : std_logic;
    signal dnt_mult : std_logic := '1';
    
    function float_64_to_32 (f : std_logic_vector(precision64-1 downto 0))
    return std_logic_vector is
        variable v : integer := 16777215;
        variable exp :unsigned(ex_width64-1 downto 0) := unsigned(f(precision64-2 downto man_width64));
        variable mantissa : unsigned (man_width32+1 downto 0) :=  '0'& unsigned(f(man_width64-1 downto 28)) +1;
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
            
        return f(precision64-1)& std_logic_vector(exp(ex_width32-1 downto 0)) & std_logic_vector(mantissa(22 downto 0));
end function;
 

-----------------------------------------------------------------------------------------------------------------------------------
    
attribute keep : string;
attribute keep of  exp_a : signal   is "true";
attribute keep of  exp_c : signal   is "true";
attribute keep of  exp_b : signal   is "true";
attribute keep of  mantissa_c_norm : signal   is "true";
attribute keep of  mantissa_c : signal   is "true";
attribute keep of  mantissa_a : signal   is "true";
attribute keep of  mantissa_b : signal   is "true";
attribute keep of  mantissa_c_normd : signal   is "true";
attribute keep of sign_c_ad : signal is "true";
--attribute keep of diff : signal is "true";

begin


--input sanitizing
sanitize : process (a,b,c)
begin
 mantissa_a <=  unsigned(a(man_width-1 downto 0));
 mantissa_b <=  unsigned(b(man_width-1 downto 0));
 mantissa_c <=  unsigned(c(man_width-1 downto 0));

 exp_a <= resize(unsigned(a(precision-2 downto man_width)),ex_width64);       
 exp_b <= resize(unsigned(b(precision-2 downto man_width)),ex_width64);  
 exp_c <= resize(unsigned(c(precision-2 downto man_width)),ex_width64) + to_unsigned(896,ex_width64);    
end process;

 subnormal_a : process (a,exp_a,mantissa_a)
    begin
    if (exp_a /= 0 and mantissa_a /= 0) then
        mantissa_a_norm <= '1' & std_logic_vector (mantissa_a);
        exp_an <= exp_a;
        a_zero <= '0';
    elsif (exp_a = 0 and mantissa_a /= 0) then    
        mantissa_a_norm <= (others => '0');
        exp_an <= to_unsigned(1, ex_width64);
        a_zero <= '0';
    else
        mantissa_a_norm <= (others => '0');
        exp_an <= to_unsigned(0, ex_width64);
        a_zero <= '1';
    end if;   
 end process;
 subnormal_b : process (b,exp_b,mantissa_b)
    begin
    if (exp_b /= 0 and mantissa_b /= 0) then
        mantissa_b_norm <= '1' & std_logic_vector(mantissa_b);
        exp_bn <= exp_b;
        b_zero <= '0';
    elsif (exp_b = 0 and mantissa_b /= 0) then
        mantissa_b_norm <= (others => '0');
        exp_bn <= to_unsigned(1, ex_width64);
        b_zero <= '0';
    else 
        mantissa_b_norm <= (others => '0');
        exp_bn <= to_unsigned(0, ex_width64);
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
    if (exp_a > 254 or 
     exp_b > 255 or 
     exp_c > 1150 or exp_ab > 1150) then 
       nan_input <= '1';
    else
       nan_input <= '0';
    end if;
end process;
do_not_multiply: process(nan_input, z_mult)
begin
    if (z_mult = '1' or nan_input = '1') then
        dnt_mult <= '1';
    else 
        dnt_mult <= '0';
    end if;
end process;
input_c : process (c,exp_c,mantissa_c,a(precision32-1),b(precision32-1),c(precision32-1))
    begin
             mantissa_c_normd <= (others => '0');
             sign_ab_ad <= a(precision32-1) xor b(precision32-1);
            if (exp_c > 896 and mantissa_c > 0 ) then
                    mantissa_c_normd <=  std_logic_vector('1' & mantissa_c &  to_unsigned(0,29));
                    exp_cnd <= exp_c;
                    sign_c_ad <= c(precision32-1);
                    z_sumd <= '0';
            elsif (exp_c = 896 and mantissa_c > 0) then
                    mantissa_c_normd <= (others => '0');
                    exp_cnd <= to_unsigned(1, ex_width64);
                    sign_c_ad <= c(precision32-1);
                    z_sumd <= '0';
            else  
                    mantissa_c_normd <= (others => '0');
                    exp_cnd <= to_unsigned(0, ex_width64);
                    sign_c_ad <= '0';
                    z_sumd <= '1';
        
            end if; 
    end process;

clock_delay : process (clk)--c,exp_c,mantissa_c
        begin
        if rising_edge(clk)then 
            if n_rst = '0' then
                mantissa_c_norm <= (others => '0');
                exp_cn <= to_unsigned(0, ex_width64);
                z_sum <= '1';
                nan_op <= '0';
                z_mult_d <= '1';
                sign_c_add <= '0';
                sign_ab_add <= '0';
            else
                nan_op <= nan_input;
                z_mult_d <= z_mult;
                sign_c_add <= sign_c_ad;
                sign_ab_add <= sign_ab_ad;
               
                mantissa_c_norm <=  mantissa_c_normd;
                exp_cn <= exp_cnd;
                z_sum <= z_sumd; 
            end if;
        end if;
        end process;

 --multiplication 
 ab_exp : process(exp_an,exp_bn)   
 begin  
 exp_ab <= exp_an + exp_bn + to_unsigned(769,ex_width64) ;

end process;
 difference : process(exp_cnd, exp_ab)
 begin
 diff <= signed(exp_cnd) - signed(exp_ab);

 end process;
 
 mode_selection : process(nan_input, z_mult,diff,n_rst)
 begin

        if n_rst = '0' then

            mode <= "11";--SKIP;
        else
            if nan_input = '0' and z_mult = '0' then
                if (diff = 0 or diff < 0) then
                    mode <= "00";--Full;
                elsif (diff > 0 and diff < thr1) then
                    mode <= "01";---SKIP_BD;
                elsif (diff >= thr1 and diff < thr2)then
                    mode <= "10";--AC_ONLY;
                elsif (diff >= thr2) then
                    mode <= "11";--SKIP;
                else
                    mode <= "11";--SKIP;
                end if;
           else
                mode <= "11";--SKIP;
      end if;
   end if;
--  end if;
  end process;
  ---multiply 
  fp_multiply : fp_mult 
      generic map (width  => man_width+1, cut => cut)
      Port map( 
             clk => clk,
             n_rst => n_rst,
             mantissa_a => mantissa_a_norm,
             mantissa_b => mantissa_b_norm,
             mode => mode,
             exp_ab_in => exp_ab,
             exp_ab => exp_ab_out,
             mantissa_ab_norm => ab,
             dnt_mult => dnt_mult
  
             );
        ab_result <= sign_ab & std_logic_vector(exp_ab_out) & ab;
 -- Addition
 fp_add : add_fp
 generic map (precision => precision64, man_width => man_width64)
   Port map (
         exp_ain => exp_cn_addin,
         exp_bin => exp_ab_addin,
         man_ain => sum_64_in,
         man_bin=> ab_add_in,
         sign_a => sign_c,
         sign_b => sign_ab,
         result => sum_64_out);
                 
 adder_inputs :process (ab,exp_cn,sign_ab_add,mantissa_c_norm,exp_ab_out,sign_c_add,z_sum,nan_op,z_mult_d)
 begin

             if nan_op = '0' and z_sum = '0'and z_mult_d = '0' then        
                ab_add_in <= '1' & ab;
                sum_64_in <= mantissa_c_norm ;
                exp_cn_addin <= exp_cn;
                exp_ab_addin <= exp_ab_out;
                sign_c <= sign_c_add;
                sign_ab <= sign_ab_add;
             else
                ab_add_in <= (others => '0');
                sum_64_in <= (others => '0') ;
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
       if (nan_op = '1')then
            sumout <= (others => '1');--nan_value;
       else
           if (z_mult = '0' and z_sum = '0') then
               sumout <= sum_64_out;
           elsif(z_mult = '1' and z_sum = '0') then
               sumout <= sign_c & std_logic_vector (exp_cn) & mantissa_c_norm(man_width64-1 downto 0);
           elsif( z_mult = '0' and z_sum = '1')then
                sumout <= sign_ab & std_logic_vector (exp_ab_out) & ab;
           else
                sumout <= (others => '0');
           end if;
       end if;
     end if;
   end process; 
   
  
            
end Behavioral;