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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
--perform B*A multiplication B is fixed A rows are fed each clock cycles

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.my_types.all;
entity systolic_array is
--    generic (
----        N : integer range 0 to 128 := 4; -- Matrix size
----        Pre_in : integer range 0 to 32 := 4;
----        Pre_out : integer range 0 to 64 := 8;
----        ex_width_in: integer range 0 to 16:=5;
----        man_width_in: integer range 0 to 32:= 10;
----        ex_width_out: integer range 0 to 16:=8;
----        man_width_out: integer range 0 to 64:= 23;
----        cut : integer range 0 to 32 := 5;
----        offset : integer range 0 to 32 := 0
--    );
    port (
        clk    : in std_logic;
        n_rst    : in std_logic;
        A, B   : in std_logic_vector(N*N*Pre_in-1 downto 0); -- Flattened input matrices
        C      : out std_logic_vector(N*N*Pre_out-1 downto 0); -- Output matrix
        done : out std_logic;
        en : std_logic
    );
end entity;

architecture rtl of systolic_array is
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
    component modes_option2 is
      Port ( clk  : in std_logic;
            n_rst : in std_logic;
            en    : in std_logic;
            A, B  : in std_logic_vector(N*N*Pre_in-1 downto 0); -- Flattened input matrices
            modes : out  mode_array);
    end component;
    
    type matrix8 is array (0 to N-1, 0 to N-1) of std_logic_vector(Pre_in-1 downto 0);
    type matrix16 is array (0 to N-1, 0 to N-1) of std_logic_vector(Pre_out-1 downto 0);
    type matrixsN is array ( 0 to N-1) of std_logic_vector(Pre_in-1 downto 0);
    type matrixdN is array ( 0 to N-1) of std_logic_vector(Pre_out-1 downto 0);
    type pipe is array(0 to N-1, 0 to N-2) of std_logic_vector(Pre_in-1 downto 0);
    type mode_buffer_array is array (0 to N-1) of std_logic_vector(N*(N+1)-1 downto 0);
    
    signal A_matrix, B_matrix : matrix8;
    signal C_matrix, Cout : matrix16; --C_matrix accumulation interconnection, Cout matrix output
    signal A_input,A_input1,A_input2 : matrixsN;
    signal A_pipe   : matrix8; -- A interconnection between PEs
    signal sum_output : matrixdN;
    signal counter : integer range 0 to N := 0;
    signal mode : mode_array;
    signal mode_buffer : mode_buffer_array;
    begin
    -- Unflatten Input Matrices
    process(A, B)
    begin
        for i in 0 to N-1 loop
            for j in 0 to N-1 loop
                A_matrix(i, j) <= A((i*N + j)*Pre_in + Pre_in-1 downto (i*N + j)*Pre_in);
                B_matrix(i, j) <= B((i*N + j)*Pre_in + Pre_in-1 downto (i*N + j)*Pre_in);
            end loop;
        end loop;
    end process;
    --instantiate mode selection module
    mode_select : modes_option2
        port map (clk  =>  clk,
                n_rst => n_rst,
                en => en,
                A => A , B => B, -- Flattened input matrices
                modes => mode);
                
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
            sum_output(j) <= C_matrix(N-1, j);
            mode_in <= mode_buffer(i)((N-j)*(N-j-1) +1 downto (N-j)*(N-j-1));
            process(clk) begin
            if rising_edge(clk) then
                if n_rst = '0' then
                    A_pipe(i,j) <= (others => '0');
                else 
                    A_pipe(i,j) <= A_in;
                end if; 
                if i = N-1 then 
                    report "sumout "& "("&to_string(j)&")" & to_string(sum_out);
                end if;
            end if;
            end process;
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
    
    -- buffering input and outputs
    process(clk)
    variable j : integer := 0;
        begin
            if rising_edge(clk) and en = '1' then
                if n_rst <= '0' then
--                    A_input <= (others =>(others => '0'));
                else 
                
                    for i in 0 to N-1 loop
--                        A_input(i) <= A_matrix(i, counter-i) when (counter >= i and counter < N+i)else (others => '0') ;
                          --buffering A_input old way
                        Cout(i,(counter - (N+3))-i) <= sum_output(i) when (counter >= N+3 and (counter - (N+3))>=i and (counter-(N+3))<N+i);
                        --N+1 originally, for any delay in A_input increase N+1 by 1 to accommodate the delay in the output.N+i remains unaffected
                        -- 2 clk delays affected A_input to align with mode dilevery, so 2 is add to N+1
                    end loop;
                    
--                    if j=N-1 then j := 0; else j:= j+1; end if;
                       if done = '1' then done <= '0'; end if;
                    if counter = 3*N+1 then -- if no delay of input A_input it takes 2N-1 to feed all inputs, N propagation delay inside
                        counter <= 0;       -- the systolic array, i.e last input to get out as input propagates N + delay N-1 + N inside = 3N-1
                        done <= '1';        -- added delay 2 results in 3N-1 + 2 = 3N+1
                    else
                        counter <= counter +1;
                    end if;
                end if;
            end if;
    end process;
    -- Flatten Output Matrix
    process(Cout, done )
    begin
    if done = '1' then
        
        for i in 0 to N-1 loop
            for j in 0 to N-1 loop
                C((i*N + j)*Pre_out + Pre_out-1 downto (i*N + j)*Pre_out) <= Cout(i, j);
            end loop;
        end loop;
    end if;
    end process;
    
    --tringluar buffers for A input
            buf : for i in 0 to N-1 generate 
                signal Abuffer : std_logic_vector(pre_in*(i+1)-1 downto 0);
                begin
--                    A_input(i) <= Abuffer(pre_in-1 downto 0);
                    
                process(clk)
                    begin
                        if rising_edge(clk) and en = '1' then 
                            if n_rst = '0' then
                                Abuffer <= (others => '0');
                            else
                                A_input1(i) <= Abuffer(pre_in-1 downto 0);
                                Abuffer <= std_logic_vector(shift_right(unsigned(Abuffer), pre_in));
                                Abuffer(pre_in*(i+1)-1 downto pre_in*i) <= A_matrix(i, counter ) when  counter < N;
                                A_input <= A_input1; -- delay  one register and the other on the clock assignment
                            end if;
                        end if;
                    end process;
                    
            end generate;
end architecture;
