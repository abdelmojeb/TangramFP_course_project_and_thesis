----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/08/2025 07:35:29 PM
-- Design Name: 
-- Module Name: TB_tools - 
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
use ieee.math_real.all;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

package TB_tools is
    function float_32_to_64 (f : std_logic_vector(31 downto 0))return std_logic_vector;
    function float_64_to_32 (f : std_logic_vector(63 downto 0)) return std_logic_vector;
    function is_x(v: std_logic_vector) return boolean;
    procedure generate_aligned_random_vectors16(seed1, seed2: inout positive; 
    rout_a,rout_b,rout_c: out std_logic_vector(15 downto 0));
    procedure generate_aligned_random_vectors32(seed1, seed2: inout positive; 
        rout_a,rout_b,rout_c: out std_logic_vector(31 downto 0));
    function float_to_half (f : std_logic_vector(31 downto 0))return std_logic_vector;
    function real_to_float(r : real) return std_logic_vector;
end TB_tools;
package body TB_tools is
     --32 to 64 conversion
    function float_32_to_64 (f : std_logic_vector(31 downto 0))
       return std_logic_vector is
       variable exp_old : integer := to_integer(unsigned(f(30 downto 23)));
       variable exp : unsigned (10 downto 0) := (others=>'0');
       variable m : unsigned (22 downto 0):= unsigned(f(22 downto 0));
       variable shift_count : natural range 0 to 32 := 0;
       begin
           
--            if (exp_old = 0)then
--                for i in 22 downto 0 loop
--                if m(i) = '1' then 
--                    shift_count := 23-i;
--                    exit;  -- Found first '1' in subnormal
--                end if;
--                end loop;
--                exp := to_unsigned(1023 - shift_count,11);  -- Convert position to biased exponent
--                m := shift_left(m, 23-shift_count); 
          if (exp_old > 0 and exp_old < 255 ) then
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




 function is_x(v: std_logic_vector) return boolean is
   begin
       for i in v'range loop
           if v(i) = 'X' or v(i) = 'U' then
               return true;
           end if;
       end loop;
       return false;
   end function;
--generate random numbers in 16bit precision
procedure generate_aligned_random_vectors16(seed1, seed2: inout positive;
            rout_a,rout_b,rout_c: out std_logic_vector(15 downto 0)) is
        variable r1, r2, r3, rm1,rm2,rm3: real;
        variable exp_a, exp_b, exp_c: integer;
        variable man1,man2,man3: natural;
        variable s1,s2,s3 : std_logic;
        constant max_exp: integer := 15;  -- Maximum exponent for float16
        constant min_exp: integer := -14; -- Minimum exponent for normalized float16
        constant alignment_shifts: integer := 0;
        constant exp_width : integer := 5;
        constant man_width : integer := 10;
    begin
        -- Generate random numbers for a and b
        uniform(seed1, seed2, r1);
        r1 := (r1 * 2.0 - 1.0);  -- Range [-1,1]
        uniform(seed1, seed2, r2);
        r2 := (r2 * 2.0 - 1.0);  -- Range [-1,1]
        
        -- Generate random number for c
        uniform(seed1, seed2, r3);
        r3 := (r3 * 2.0 - 1.0);  -- Range [-1,1]
        
        uniform(seed1, seed2, rm1);
        uniform(seed1, seed2, rm2);
        uniform(seed1, seed2, rm3);
        man1 := integer(rm1*1023.0);
        man2 := man1 + integer(rm2*2.0);--integer(rm2*8388607.0);
        man3 := man1 - integer(rm3*2.0);--integer(rm3*8388607.0);
        
        -- Generate exponents for a and b
        uniform(seed1, seed2, r1);
        exp_a := integer(r1 * ( real(max_exp)-real(min_exp))) + min_exp;  -- Range [-14,15]
        uniform(seed1, seed2, r2);
        exp_b := integer(r2 * ( real(max_exp)-real(min_exp))) + min_exp;  -- Range [-14,15]

        -- Ensure the product of a and b does not exceed the max/min values of fp-16
        if exp_a + exp_b + alignment_shifts > max_exp then
            if (exp_a>exp_b) then
                exp_a := max_exp - exp_b - alignment_shifts;
            else
                exp_b := max_exp - exp_a- alignment_shifts;
            end if;
        elsif exp_a + exp_b < min_exp then
            if exp_a < exp_b then
                exp_a := min_exp - exp_b;
            else 
                exp_b := min_exp - exp_a;
            end if;
        end if;

        -- Ensure the exponent of c is greater than the sum of exponents of a and b minus alignment shifts
        -- value of exp_c that results in a specific multiplication mode
        exp_c := exp_a + exp_b + alignment_shifts;--+ alignment_shifts + 1;
        if exp_c > max_exp then
            exp_c := max_exp;
        elsif exp_c < min_exp then
            exp_c := min_exp;
        end if;

        if rm1 > 0.5 then
            s1 := '0';
        else
            s1 := '1';
        end if;
        if rm2  > 0.5 then
            s2 := '0';
        else
            s2 := '1';
        end if;
        if rm3  > 0.5 then
            s3 := '0';
        else
            s3 := '1';
        end if;
            rout_a := s1 & std_logic_vector(to_unsigned(exp_a+max_exp, exp_width)) & std_logic_vector(to_unsigned(man1, man_width));
        
            rout_b := s2 & std_logic_vector(to_unsigned(exp_b+max_exp, exp_width)) & std_logic_vector(to_unsigned(man2, man_width));
        
            rout_c := s3 & std_logic_vector(to_unsigned(exp_c+max_exp, exp_width)) & std_logic_vector(to_unsigned(man3, man_width));
    end procedure;
    --random 32bit std_vectors a,b,c
    procedure generate_aligned_random_vectors32(seed1, seed2: inout positive;
                rout_a,rout_b,rout_c: out std_logic_vector(31 downto 0)) is
            variable r1, r2, r3, rm1,rm2,rm3: real;
            variable exp_a, exp_b, exp_c: integer;
            variable man1,man2,man3: natural;
            variable s1,s2,s3 : std_logic;
            constant max_exp: integer := 127;  -- Maximum exponent for float16
            constant min_exp: integer := -126; -- Minimum exponent for normalized float16
            constant alignment_shifts: integer := 0;
            constant exp_width : integer := 8;
            constant man_width : integer := 23;
        begin
            -- Generate random numbers for a and b
            uniform(seed1, seed2, r1);
            r1 := (r1 * 2.0 - 1.0);  -- Range [-1,1]
            uniform(seed1, seed2, r2);
            r2 := (r2 * 2.0 - 1.0);  -- Range [-1,1]
            
            -- Generate random number for c
            uniform(seed1, seed2, r3);
            r3 := (r3 * 2.0 - 1.0);  -- Range [-1,1]
            
            uniform(seed1, seed2, rm1);
            uniform(seed1, seed2, rm2);
            uniform(seed1, seed2, rm3);
            man1 := integer(rm1*8388607.0);
            man2 := man1 + integer(rm2*2.0);--integer(rm2*8388607.0);
            man3 := man1 - integer(rm3*2.0);--integer(rm3*8388607.0);
            
            -- Generate exponents for a and b
            uniform(seed1, seed2, r1);
            exp_a := integer(r1 * ( real(max_exp)-real(min_exp))) + min_exp;  -- Range [-14,15]
            uniform(seed1, seed2, r2);
            exp_b := integer(r2 * ( real(max_exp)-real(min_exp))) + min_exp;  -- Range [-14,15]
    
            -- Ensure the product of a and b does not exceed the max/min values of fp-16
            if exp_a + exp_b + alignment_shifts > max_exp then
                if (exp_a>exp_b) then
                    exp_a := max_exp - exp_b - alignment_shifts;
                else
                    exp_b := max_exp - exp_a- alignment_shifts;
                end if;
            elsif exp_a + exp_b < min_exp then
                if exp_a < exp_b then
                    exp_a := min_exp - exp_b;
                else 
                    exp_b := min_exp - exp_a;
                end if;
            end if;
    
            -- Ensure the exponent of c is greater than the sum of exponents of a and b minus alignment shifts
            -- value of exp_c that results in a specific multiplication mode
            exp_c := exp_a + exp_b + alignment_shifts;--+ alignment_shifts + 1;
            if exp_c > max_exp then
                exp_c := max_exp;
            elsif exp_c < min_exp then
                exp_c := min_exp;
            end if;
    
            if rm1 > 0.5 then
                s1 := '0';
            else
                s1 := '1';
            end if;
            if rm2  > 0.5 then
                s2 := '0';
            else
                s2 := '1';
            end if;
            if rm3  > 0.5 then
                s3 := '0';
            else
                s3 := '1';
            end if;
                rout_a := s1 & std_logic_vector(to_unsigned(exp_a+max_exp, exp_width)) & std_logic_vector(to_unsigned(man1, man_width));
            
                rout_b := s2 & std_logic_vector(to_unsigned(exp_b+max_exp, exp_width)) & std_logic_vector(to_unsigned(man2, man_width));
            
                rout_c := s3 & std_logic_vector(to_unsigned(exp_c+max_exp, exp_width)) & std_logic_vector(to_unsigned(man3, man_width));
        end procedure;
    --float to half
    function float_to_half (f : std_logic_vector(31 downto 0))
        return std_logic_vector is
            variable v : integer := 1023;
            variable exp :unsigned(7 downto 0) := unsigned(f(30 downto 23));
            variable mantissa : unsigned (11 downto 0) :=  '0'& unsigned(f(22 downto 12)) +1;
            begin
                if (to_integer(exp) < 102)then 
                    exp := (others=> '0');
                    mantissa := (others => '0');
                
                elsif (to_integer(exp) > 101 and to_integer(exp) < 113)then
                    report integer'image(to_integer(mantissa));
                    mantissa := mantissa + to_unsigned(v,10);
                    report integer'image(to_integer(mantissa));
                    mantissa := shift_right(mantissa, (125 - to_integer(exp))) +1;
                    report integer'image(to_integer(mantissa));
                    mantissa := shift_right(mantissa, 1);
                    report integer'image(to_integer(mantissa));
                    exp := (others=> '0');
                elsif (to_integer(exp) > 112)then
                    exp := exp - 112;
                    mantissa := shift_right(mantissa, 1);
                elsif (to_integer(exp) > 143) then
                    exp := (others=> '1');
                else 
                    exp := (others=> '0');
                    mantissa := (others => '0');
                end if;
                
            return f(31)& std_logic_vector(exp(4 downto 0)) & std_logic_vector(mantissa(9 downto 0));
    end function;
    -- Function to convert real to IEEE-754
    function real_to_float(r : real) return std_logic_vector is
        constant man_width32 : integer := 23;
        constant exp_width32 : integer := 8;
        constant precision32 : integer := 32;
        variable exp : integer := 0;
        variable mantissa : real:= abs(r);
        variable sign : std_logic:='0';
        variable mantissa_bits : std_logic_vector(man_width32-1 downto 0):= (others => '0');
        variable exponent_bits : std_logic_vector(exp_width32-1 downto 0):= (others => '0');
        variable result : std_logic_vector(precision32-1 downto 0):= (others => '0');
    begin
        -- Add conversion logic here
     if r=0.0 then
        return result;
     else
        if (r < 0.0)then
            sign := '1';
        else 
            sign := '0';
        end if;
        while mantissa >= 2.0 loop
            mantissa := mantissa / 2.0;
            exp := exp + 1;
        end loop;
        while mantissa < 1.0  loop
            mantissa := mantissa * 2.0;
            exp := exp - 1;
        end loop;

        -- Bias the exponent
        exp := exp + 127;

        -- Convert mantissa to binary
        mantissa_bits := std_logic_vector(to_unsigned(integer(mantissa * 2.0**23), 23));
        exponent_bits := std_logic_vector(to_unsigned(exp, 8));

        -- Combine to form FP32
        result := sign & exponent_bits & mantissa_bits;
        return result;
        end if;
    end function;
end package body;
