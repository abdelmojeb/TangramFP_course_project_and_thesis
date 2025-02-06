-- Code your design here
library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_STD.all;

entity convert is
generic (man_width : integer := 23; precision : integer:= 32);
port (a : in std_logic_vector(31 downto 0); 
		b: out std_logic_vector(63 downto 0);
        y : out std_logic_vector(31 downto 0); 
        x: in std_logic_vector(63 downto 0));
end entity;
architecture b of convert is
        function float_32_to_64 (f : std_logic_vector(31 downto 0))
            return std_logic_vector is
            variable exp : unsigned(10 downto 0):= "000" & unsigned(f(30 downto 23));
            begin
                if (exp /= 0) then
                    exp := exp + to_unsigned(896, 11);
                elsif(exp = 0) then
                    exp := (others => '0');
                else
                    exp := (others => '1');
                end if;
            return f(31)& std_logic_vector(exp)&f(22 downto 0) & std_logic_vector(to_unsigned(0,29));
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
                else
                    exp := (others=> '1');
                end if;
                
            return f(63)& std_logic_vector(exp(7 downto 0)) & std_logic_vector(mantissa(22 downto 0));
    end function;
            signal m :unsigned(63 downto 0);
            signal exp :unsigned(10 downto 0);-- := unsigned(x(62 downto 52));
            signal mantissa1,mantissa2,mantissa3,mantissa4,mantissa5,mantissa : unsigned (24 downto 0);-- :=  unsigned(x(51 downto 28)) +1;
--            signal ys : std_logic_vector(31 downto 0);
    begin 
--           exp <= m(62 downto 52);
--           mantissa1 <= '0'& unsigned(x(51 downto 28)) +1;
--           mantissa2 <= mantissa1 + to_unsigned(16777215,24);
--           mantissa3 <= shift_right(mantissa2, (897 - to_integer(exp))) +1;
--           mantissa4 <= shift_right(mantissa3, 1);
--           mantissa5 <= shift_right(mantissa1, 1);

--            process(m)
--             begin
--                        m <= unsigned(x);
--                if (to_integer(exp) < 873)then 
--                      y <= (others => '0');
--                elsif (to_integer(exp) > 872 and to_integer(exp) < 897)then
--                    y<= x(63)& "00000000" & std_logic_vector(mantissa4(22 downto 0));        
--                elsif (to_integer(exp) > 896 and to_integer(exp) < 1151)then
--                    y<= x(63)& std_logic_vector(exp - 896) & std_logic_vector(mantissa5(22 downto 0));
    
--                else
--                    y<= x(63)& "11111111" & std_logic_vector(mantissa5(22 downto 0));        
--                end if;
--  end process;
--            y<= x(63)& std_logic_vector(exp(7 downto 0)) & std_logic_vector(mantissa(22 downto 0));
    b <= float_32_to_64(a);
    y <= float_64_to_32(x);

end b;