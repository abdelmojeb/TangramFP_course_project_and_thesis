----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/05/2025 02:55:38 PM
-- Design Name: 
-- Module Name: sysA - Behavioral
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
--perform B*A multiplication B is fixed A rows are fed each clock cycles

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.my_types.all;
use work.tools.all;
entity systolic_array_pipe1 is

    port (
        clk    : in std_logic;
        n_rst    : in std_logic;
        A_colmn : in N_1_prein;
        B_in : in std_logic_vector(Pre_in-1 downto 0);
        col : in integer   range 0 to N;
        row : in integer range 0 to N;
        enB: in std_logic;
        rwB : in std_logic;
        sum     : out N_1_Prein;    
        mode : in mode_array;  
        en : std_logic
    );
end entity;

architecture rtl of systolic_array_pipe1 is
 attribute DONT_TOUCH : string;
    --mac ip
    component MAC_external_mode_pq is 
    generic( precision_in : integer range 0 to 32:=Pre_in; 
         precision_out : integer range 0 to 64:=Pre_out;
         ex_width_in: integer range 0 to 16:=ex_width_in;
         man_width_in: integer range 0 to 32:= man_width_in;
         ex_width_out: integer range 0 to 16:=ex_width_out; 
         man_width_out: integer range 0 to 64:= man_width_out;
         cut : integer range 0 to 32 := cut;
         offset : integer range 0 to 32 := offset);
        Port ( a : in  STD_LOGIC_VECTOR (precision_in-1 downto 0);
               b : in  STD_LOGIC_VECTOR (precision_in-1 downto 0);
               c : in STD_LOGIC_VECTOR (precision_out-1 downto 0);
               modein: in STD_LOGIC_VECTOR (1 downto 0);
               clk, n_rst : in STD_LOGIC;
               sumout : out STD_LOGIC_VECTOR (precision_out-1 downto 0));
    end component;
--      attribute DONT_TOUCH of MAC_external_mode_pq : component is "TRUE";

    signal  B_matrix : N_N_prein;
    signal C_matrix : N_N_preout; --C_matrix accumulation interconnection, Cout matrix output
--    signal Cout : N_N_Prein;
    signal A_input, A_input1 : N_1_prein;
    signal A_pipe   : A_pipeline; -- N_N_prein; -- A interconnection between PEs
    signal sum_output : N_1_prein;
    --signal sum_out_connect : N_1_preout;
    signal mode_buffer : N_1_mode;
    attribute DONT_TOUCH of C_matrix : signal is "TRUE";
    attribute DONT_TOUCH of A_pipe : signal is "TRUE";
    attribute DONT_TOUCH of sum_output : signal is "TRUE";
--    attribute DONT_TOUCH of Cout : signal is "TRUE";
    begin
    RW_B: process( clk)
        begin
            if rising_edge ( clk) then
                if  n_rst = '0' then 
                    B_matrix <= (others =>(others => (others => '0')));
                else 
                
                    if enB = '1' then
                        if rwb = '1' then
                            B_matrix(row,col) <= B_in;
                       
                        end if; 
                    end if;
                end if;
           end if ;
        end process;
    
    
                
    -- propagate the modes accross levels in the systolic array 
    -- the buffer has for each row a vector that contains modes will 
    --be used for each row in b, N*2 -2 [8,6,4,2] each time will be coppied to the right bits in the vector
   

   --propagate through pipe
    mode_prop : process(clk)
        begin
            if rising_edge(clk)and en = '1' then
                if n_rst = '0' then
                    mode_buffer <= (others => (others => '1'));
                else
                   -- insert the first mode into the buffer
                 for x in 0 to N-1 loop
                           mode_buffer(x)(N*(N+1)-1 downto N*(N-1)) <= mode(x);
                       end loop;
                       
                    for y in 0 to N-1 loop
                        for k in 0 to N-2 loop
                            mode_buffer(y)((k+1)*(k+2)-1 downto k*(k+1)) <= 
                                    mode_buffer(y)((k+2)*(k+3)-1 downto (k+1)*(k+2)+2);
                        end loop;
                     end loop;
                end if;
           end if;
   end process; 
                    
                    
                    
                    
    -- Instantiate Processing Elements
    gen_rows: for i in 0 to N-1 generate
        gen_cols: for j in 0 to N-1 generate
        
            signal sum_in, sum_out : std_logic_vector(Pre_out-1 downto 0);
            signal A_in , B_in : std_logic_vector(Pre_in-1 downto 0);
            signal mode_in : std_logic_vector(1 downto 0);
        begin
            -- Define Inputs for First Row/Column
            A_in <= A_input(i) when j = 0 else A_pipe(i,j-1);
            B_in <= B_matrix(j, i);
            sum_in <= (others => '0') when (i = 0) else C_matrix(i-1, j);
            C_matrix(i, j) <= sum_out;
            sum_output(j) <= float_to_half(C_matrix(N-1, j));
            mode_in <= mode_buffer(i)((N-j)*(N-j-1) +1 downto (N-j)*(N-j-1));
            
            pipe : if j <N-1 generate
                process(clk) begin
                if rising_edge(clk) then
                    if n_rst = '0' then
                        A_pipe(i,j) <= (others => '0');
                    else 
                        A_pipe(i,j) <= A_in ;
                    end if; 
                    if i = N-1 then 
--                        report "sumout "& "("&to_string(j)&")" & to_string(sum_out);
                    end if;
                end if;
                end process;
            end generate pipe;
            
           PE: MAC_external_mode_pq
           
--            generic map (Pre_in=>Pre_in,Pre_out=>Pre_out)
                port map (
                    clk     => clk,
                    n_rst => n_rst,
                    a    => A_in,
                    b    => B_in,
                    c  => sum_in,
                    modein=>mode_in,

                    sumout => sum_out
                );
               
        end generate;
    end generate;

--tringluar buffers for A input
                buf : for i in 0 to N-1 generate 
                    signal Abuffer : std_logic_vector(pre_in*(i+1)-1 downto 0);
                    begin
--                        A_input(i) <= Abuffer(pre_in-1 downto 0);
                        
                    process(clk)
                        begin
                            if rising_edge(clk) and en = '1' then 
                                if n_rst = '0' then
                                    Abuffer <= (others => '0');
                                else
                                    A_input1(i) <= Abuffer(pre_in-1 downto 0);
                                    Abuffer <= std_logic_vector(shift_right(unsigned(Abuffer), pre_in));
                                    Abuffer(pre_in*(i+1)-1 downto pre_in*i) <= A_colmn(i);
                                    A_input <= A_input1; -- delay  one register and the other on the clock assignment
                                end if;
                            end if;
                        end process;
                        
                end generate;
    
    --tringluar buffers for sum input
            
            
            -- another way to buffer out output continously and let the end side to construct its Matrix
            -- the out is taken from sum_output and put into stair buffer (trainglar delays) the each clock the last row is sent out
--            sum_out_connect <= sum_output;
            C_buf : for i in 0 to N-1 generate 
                signal Cbuffer : std_logic_vector(pre_in*((N-i))-1 downto 0);
                begin
                  --   output(i) <= Cbuffer(pre_out-1 downto 0); removed

                process(clk)
                    begin
                        if rising_edge(clk)  then 
                            sum(i) <= Cbuffer(pre_in-1 downto 0);
                            Cbuffer <= std_logic_vector(shift_right(unsigned(Cbuffer), pre_in));
                            Cbuffer(pre_in*((N-i))-1 downto pre_in*(N-i-1)) <= sum_output(i);
                            
                            
                        end if;
                    end process;
                    
            end generate C_buf;
            --pass matrix output 

--                 
                    
end architecture;
