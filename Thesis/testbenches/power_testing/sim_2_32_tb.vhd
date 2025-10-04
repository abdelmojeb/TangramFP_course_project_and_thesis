
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
use work.TB_tools.all ; 
use work.my_types.all;
use ieee.numeric_std.all;
use std.env.finish;

entity sim_2_32_tb is
generic(N : integer range 0 to 128 := 2; -- Matrix size
        Pre_in : integer range 0 to 32 := 32
        );
end sim_2_32_tb;

architecture test of sim_2_32_tb is
    signal clk : std_logic := '0';
    signal clkp : std_logic := '1';
    signal clkn : std_logic := '0';
    signal UUTclk : std_logic ;
--    signal A, B : std_logic_vector(4*4*Pre_in-1 downto 0);
    type M_array is array ( 0 to N*N*4-1) of std_logic_vector(Pre_in-1 downto 0);
    signal B, A_vec : N_N_prein;
    signal A : M_array;
    signal C : N_N_Prein;
    type A_rray_real is array ( natural range <>,natural range <>) of real ;
    type A_rray_r is array ( natural range <>) of real ;
    signal Areal : A_rray_r(0 to N*N*4-1) :=           (1.0, 2.0, 1.0, 2.0,  1.0, 2.0, 1.0, 2.0, 1.0, 2.0, 1.0, 2.0,   1.0, 2.0, 1.0, 2.0
                                                        );
                                                        
    signal A_calc : A_rray_real(0 to N-1, 0 to N-1) := ((160.0,-15.0),(14.0,0.13));
                                                       
    signal Breal : A_rray_real(0 to N-1, 0 to N-1) := ((1.0,1.0), (1.0, 1.0));

--    signal modes:  mode_array;
    signal n_rst : std_logic:='0';
    -- Function to convert integer to 8-bit std_logic_vector
    function int_to_slv(val : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(val, Pre_in));
    end function;
    --AXI signals
    signal s_tready : std_logic;
    signal s_tdata  : std_logic_vector(Pre_in-1 downto 0);
    signal s_tlast  : std_logic;
    signal s_tvalid : std_logic;
    signal m_tready : std_logic;
    signal m_tdata  : std_logic_vector(Pre_in-1 downto 0);
    signal m_tlast  : std_logic;
    signal m_tvalid : std_logic;
    signal control_sel : std_logic_vector(3 downto 0);
    constant period : time := 7 ns;--33.33 ns;--20 ns;
begin
clk <= not clk after period;
clkn <= not clkn after 5ns;
clkp <= not clkp after 5ns;
UUTclk <= clk after 3.568 ns;


    UUT: entity work.design_1_wrapper --SysA_interface_pipe1
        --generic map (N => 4,Pre_in=>Pre_in,Pre_out=>Pre_out)
        port map (
            clk_30MHz        => clk,

            reset     => n_rst,
            -- AXI-Stream Slave
            s00_axis_0_tready     => s_tready,
            s00_axis_0_tdata      => s_tdata,
            --in wire ((DATA_WIDTH/8)-1 : 0) s00_axis_tstrb;
            s00_axis_0_tlast      => s_tlast,
            s00_axis_0_tvalid     => s_tvalid,
        
            -- AXI-Stream Master
            m00_axis_0_tvalid     => m_tvalid,
            m00_axis_0_tdata      => m_tdata,
            --out wire ((DATA_WIDTH/8)-1 : 0) m00_axis_tstrb;
            m00_axis_0_tlast      => m_tlast,
            m00_axis_0_tready     => m_tready,
            
            control_sel         => control_sel -- loadW = 0011, loadA = 0010
            
        );
    process

    variable  full,skip_BD,AC_only, skip:  natural;
    begin
     wait for period;
           n_rst <= '1'; 

           report "matrix A: ---------------------------------------------";
        		for i in 0 to N*N*4-1 loop
           -- Matrix A initialization (values 1 to 4)
                   if Pre_in = 16 then
                   A(i) <= float_to_half(real_to_float(Areal(i)));
--                   A(i,j)  <= float_to_half(real_to_float(real((i*10 mod N*2)+j+1)));
                   else 
--                       A(i)  <= real_to_float(real(j mod N*2)+1.0);
                         A(i) <= real_to_float(Areal(i));
                   end if;
                   --report to_string(j) & " element j: " & to_string((i*10 mod N*2)+j);
           end loop;
           report "matrix B: ---------------------------------------------";
             for i in 0 to N-1 loop
               for j in 0 to N-1 loop
           -- Matrix A initialization (values 1 to 4)
                   if Pre_in = 16 then
                       B(i,j)  <= float_to_half(real_to_float(Breal(i,j)));
--                       B(i,j)  <= float_to_half(real_to_float(real((j*1 mod N)+i*N+1)));
                   else 
--                       B(i,j)  <= real_to_float(real(j mod N)+1.0);
                       B(i,j)  <= real_to_float(Breal(i,j));
                   end if;
--                   report to_string(j) & " element j: " & to_string((j*10 mod N)+i*N+1);
               end loop;
           end loop;


  for repeat in 0 to 63 loop

       wait until rising_edge(UUTclk);
       --send B
       s_tvalid <= '1';
       control_sel <= "0011";

       
           for i in 0 to N-1 loop
            for j in 0 to N-1 loop

                    s_tdata <= B(i,j);
                    if i = N-1 and j = N-1 then 
                        s_tlast <= '1';
                     end if;
                
                    wait until rising_edge(UUTclk);
                    while s_tready /= '1' loop
                        wait until rising_edge(UUTclk);
                    end loop;
            end loop;
           end loop;
       
      
       s_tvalid <= '0';s_tlast <= '0';
       wait for 10*period;
       wait until rising_edge(UUTclk);
           -- send A
           s_tvalid <= '1';
            control_sel <= "0010";
             m_tready <= '1';
              for i in 0 to N*N*4-1 loop

                       s_tdata <= A(i);

                   
                   wait until rising_edge(UUTclk);
                   while s_tready /= '1' loop
                       wait until rising_edge(UUTclk);
                   end loop;
              end loop;
              s_tvalid <= '0';       
              control_sel <= "0000";

         wait for 10*period;
         control_sel <= "1100";
         wait for 10*period;
    end loop;
        assert false report "Simulation finished" severity note;
        finish;
        wait;
    end process;
    
end architecture;
