----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/18/2025 08:17:36 AM
-- Design Name: 
-- Module Name: SysA_interface - Behavioral
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
use std.textio.all;
use work.my_types.all;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity SysA_interface_pipe1 is
Generic( N : integer := 2;
     Pre_in: integer :=16;
     ex_width_in : integer := 5;
     cut : integer := 5;
     offset : integer range 0 to 32 := 0;
     Pre_out : integer := 32
     );
  Port (-- Clock and Reset shared with the AXI-Lite Slave Port
    s00_axi_aclk : in std_logic ;
    s00_axi_aresetn : in std_logic ;
    
    -- AXI-Stream Slave
    s00_axis_tready :out std_logic ;
    s00_axis_tdata : in std_logic_vector (pre_in-1 downto 0) ;
    --in wire ((DATA_WIDTH/8)-1 : 0) s00_axis_tstrb;
    s00_axis_tlast : in std_logic ;
    s00_axis_tvalid : in std_logic ;

    -- AXI-Stream Master
    m00_axis_tvalid : out std_logic ;
    m00_axis_tdata : out std_logic_vector (pre_in-1 downto 0) ;
    --out wire ((DATA_WIDTH/8)-1 : 0) m00_axis_tstrb;
    m00_axis_tlast : out std_logic ;
    m00_axis_tready:  in std_logic ;

    -- Matrix-select and Start signals coming from the AXI-Lite Slave Port
    control_sel :in   std_logic_vector (3 downto 0)  -- loadW = 0011, loadA = 0010
--    led_out : out  std_logic_vector (1 downto 0) 
    );
end SysA_interface_pipe1;

architecture pipe_1_buff of SysA_interface_pipe1 is
-- signals
signal W_in  : std_logic_vector (pre_in-1 downto 0);
signal expB_in : unsigned(ex_width_in downto 0);
signal A_col, sum : N_1_prein;
signal A_exp_col :  max_array;
--signal A_exp : exp_array ; 
signal C_buffer, A_buffer : N_N_prein;
signal enA,enB, rwA,rwB: std_logic;
signal en, done, comp,feed_A  : std_logic;
type states is (idle, load_W, load_A);
signal state : states;
type outstates is (store_r, transfer_r);
signal outstate : outstates;
signal i,j, col,row, K, L,R  : natural range 0 to N;
signal stready : std_logic;
signal mode : mode_array;
signal jobcount : natural range 0 to N;
signal busy , B_loaded : std_logic;
signal count1, count2 : natural range 0 to 3*N+3+2;
signal fAcount : natural range 0 to N;
signal store , transfer: std_logic;
begin
-- load input matrices
process(s00_axi_aclk)
--variable i,j : integer range 0 to N;
    begin
--    s00_axis_tready <= stready;
    if rising_edge(s00_axi_aclk) then 
        if (s00_axi_aresetn = '0') then
            enA <= '0'; rwA <= '0';
            enA <= '0';
            enB <= '0'; rwB <= '0';
            i<= 0; j <= 0;
            B_loaded <= '0';
        else
        case state is 
             
            when idle => 
                comp <= '0';
              if control_sel = "0011" and jobcount = 0 and busy = '0' then
                  state <= load_W;
              elsif control_sel = "0010" and B_loaded ='1' then 
                  state <= load_A;
              else 
                  state <= idle;
              end if;
                
            when load_W =>
                col <= j;
                row <= i;
                if  s00_axis_tvalid ='1' then 
                    s00_axis_tready <= '1';
                    enB <= '1'; rwB <= '1';
--                    if i <= N-1 then
--                       W_buffer(i,j) <= s00_axis_tdata;
                       j <= j+1;
                       if j = N-1 then
                           i<= i+1;
                           j<= 0;
                       end if;
                       if i = N then 
                        state <= load_A;
                        s00_axis_tready <= '0';
                        i <= 0;
                        j<= 0;
                        enB <= '1'; rwB <= '0';
                        B_loaded <= '1';
                    end if;
--                  end if;  
                end if;
            when load_A =>
                col <= j;
                row <= i;
                if  s00_axis_tvalid ='1' then 
                    s00_axis_tready <= '1';
                    enA <= '1'; rwA <= '1';
--                    enB <= '0';
--                    if i <= N-1 then
--                       A_buffer(i,j) <= s00_axis_tdata;
                       j <= j+1;
                       if j = N-1 then
                           i<= i+1;
                           j<= 0;
                       end if;
                       if i = N then 
                        comp <= '1';
                        state <= idle;
                        s00_axis_tready <= '0';
                        i <= 0;
                        j <= 0;
                        enA <= '1'; rwA <= '0';
                    end if;
                end if;

       end case;
   end if;
   end if;                                               
 end process;
 
 enabling: process(s00_axi_aclk)
 variable job_count : integer;
 variable encount1,encount2 : std_logic;
     begin
     if rising_edge(s00_axi_aclk)  then 
         if s00_axi_aresetn = '0' then
             busy <= '0';
             done <= '0';
             jobcount <= 0;
             job_count := 0;
             count1 <= 0;
             count2 <= 0;
             encount1 := '0';
             encount2 := '0';
         else
             if comp ='1'then
                 busy <= '1';
                 en <= '1';
                 job_count := job_count + 1;
                 if job_count mod 2 = 0 then
                    encount1 := '1';
                 else
                    encount2 := '1';
                 end if;
             end if;
             if done ='1' and jobcount > 0 then
                 job_count := job_count - 1;
                 if job_count = 0 and busy = '1' then
                      en <= '0';
                        busy <= '0';
                  end if; 
             end if;
      
             if encount1 = '1' then
                count1 <= count1 + 1;
                done <= '0';
                if count1 >= 2*N+3+2 and count1 <= 3*N+2+2 then
                    store <= '1';
                elsif count1 > 3*N+2+2 then
                    count1 <= 0;
                    store <= '0';
                    encount1 := '0';
                else 
                    store <= '0';
                end if; 
                if count1 = 3*N+2+2 then
                    done <= '1';
                else 
                    done <= '0';
                end if;
             end if;
             if encount2 = '1' then
                 count2 <= count2 + 1;
                 done <= '0';
                 if count2 >= 2*N+3+2 and count2 <= 3*N+2+2 then
                     store <= '1';
                 elsif count2 > 3*N+2+2 then
                     count2 <= 0;
                     store <= '0';
--                     done <= '1';
                      encount2 := '0';
                 else 
                     store <= '0';
--                     done <= '0';
                 end if; 
                 if count2 = 3*N+2+2 then
                     done <= '1';
                 else 
                     done <= '0';
                 end if;
              end if;
        end if;          
        jobcount <= job_count;
    end if;      
 end process;
--feed: process (comp, busy,done,jobcount)
--    begin
--        if comp ='1' then
--            en <= '1';
--        elsif done = '1'  and jobcount = 0 then
--            en <= '0';
--        elsif jobcount >0 and done = '0' then
--            en <= '1';
--        else 
--            en <= '0';
--        end if;
--  end process;
 output: process (s00_axi_aclk) 
-- variable i,j : integer range 0 to N;
    begin
        if rising_edge(s00_axi_aclk) then         
            if (s00_axi_aresetn = '0') then
                m00_axis_tdata <= (others => '0'); 
                m00_axis_tlast <= '0';
                m00_axis_tvalid <= '0';
                K <= 0;
                L<= 0;
                R <= 0;
            else    
            case outstate is
                when store_r =>
                if store = '1' then
                    for colmn in 0 to N-1 loop
                        C_Buffer(colmn, R) <= sum(colmn);
                    end loop;
                    R <= R + 1;
                    if R = N-1 then
                        R <= 0;
                        outstate <= transfer_r;
                    end if;
                end if;
                when transfer_r =>
                if  m00_axis_tready = '1' then 
                    m00_axis_tvalid <= '1';
                    if K <= N-1 then
                        m00_axis_tdata <= C_Buffer(K,L);
                        L <= L +1; 
                        if L = N-1 then 
                            L <= 0;
                            K <= K+1;
                       end if;
                       if K = N-1 and L = N-1 then 
                        m00_axis_tlast <= '1';
                        
                        
                       end if; 
                    else     
                       K <= 0; L <= 0;
                       outstate <= store_r;
                       m00_axis_tlast <= '0';
                       m00_axis_tvalid <= '0';
                   end if ;
               end if;
           end case;
           end if;
        end if; 
   end process;
   --loading A and W
   RW_A: process(s00_axi_aclk)
    begin
        if rising_edge (s00_axi_aclk) then
            if s00_axi_aresetn = '0' then 
                A_buffer <= (others =>(others => (others => '0')));
            else 
                if enA = '1' and rwa = '1' then
                        A_buffer(row,col) <= s00_axis_tdata;
--                        A_exp(row, col) <= unsigned('0' & s00_axis_tdata(Pre_in-2 downto man_width_in));
                        
                end if;
            end if;
       end if ;
    end process;

    -- feeding A and Aexp columns to systolic array and mode unit         
pass_Acol : process(s00_axi_aclk,feed_A)
--        variable counter : integer := 0;
        begin
            if rising_edge(s00_axi_aclk) and feed_A = '1' then 
                if s00_axi_aresetn = '0' then
                    A_col <= (others => (others => '0'));
                    fAcount <= 0;
                else
                    if fAcount < N then
                        for i in 0 to N-1 loop
                            A_col(i) <= A_buffer(i, fAcount );
--                            A_exp_col(i) <= A_exp(i,fAcount);
                             A_exp_col(i) <= unsigned('0' & A_buffer(i, fAcount )(Pre_in-2 downto man_width_in));
                        end loop;
                        fAcount <= fAcount + 1;
                    else
                        fAcount <= 0;
                    end if;
                        
                end if;
            end if;
        end process;
        
    feed_A_p : process(comp, fAcount)
        begin
            if  (comp = '1') then
                feed_A <= '1';
            elsif fAcount < N then
                feed_A <= '1';
            else
                feed_A <= '0';
            end if;
         end process;
 --forwarding B to systolic array and mode unit           
 passing_B:   process(enB,rwB,s00_axis_tdata)
        begin
            if enB = '1' and rwB ='1' then
                expB_in <= unsigned('0' & s00_axis_tdata(Pre_in -2 downto man_width_in));
                W_in <= s00_axis_tdata;
            else 
                expB_in <= (others => '0');
                W_in <= (others => '0');
            end if;
   end process;
systolic: entity work.systolic_array_pipe1 
    port map (
              clk       => s00_axi_aclk,
              n_rst     => s00_axi_aresetn,
              A_colmn  => A_col,
              B_in  => W_in,
              col  => col,
              row  => row,
              enB  => enB,
              rwB  => rwB,
              sum      => sum,
              mode => mode,
              en        => en
              );   
             
  --instantiate mode selection module
mode_select : entity work.modes_op2_pipe1
      port map (clk  =>  s00_axi_aclk,
                n_rst => s00_axi_aresetn,
                en => en,
                A_exp => A_exp_col, -- A ,
                expB_in => expB_in,
                col  => col,
                row  => row,
                enB  => enB,
                rwB  => rwB, 
              modes => mode);
end pipe_1_buff;
