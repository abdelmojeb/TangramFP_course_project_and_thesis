library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MAC_interface is
    generic (
        precision : integer range 0 to 128 := 32;
        ex_width : integer range 0 to 32 := 8;
        man_width : integer range 0 to 32 := 23;
        vector_length : integer := 16  -- Number of elements in vector
    );
    Port (
        -- AXI Stream interface for vector A
        s_axis_a_tdata  : in std_logic_vector(precision-1 downto 0);
        s_axis_a_tvalid : in std_logic;
        s_axis_a_tready : out std_logic;
        s_axis_a_tlast  : in std_logic;
        
        -- AXI Stream interface for vector B
        s_axis_b_tdata  : in std_logic_vector(precision-1 downto 0);
        s_axis_b_tvalid : in std_logic;
        s_axis_b_tready : out std_logic;
        s_axis_b_tlast  : in std_logic;
        
        -- Initial sum input
        initial_sum     : in std_logic_vector(precision-1 downto 0);
        initial_valid   : in std_logic;
        
        -- Output interface
        m_axis_result_tdata  : out std_logic_vector(precision-1 downto 0);
        m_axis_result_tvalid : out std_logic;
        m_axis_result_tready : in std_logic;
        m_axis_result_tlast  : out std_logic;
        
        -- System signals
        clk    : in std_logic;
        n_rst  : in std_logic
    );
end MAC_interface;

architecture rtl of MAC_interface is
    -- State machine type
    type state_type is (IDLE, CALC_MAX_EXP, PROCESSING, DONE);
    signal state : state_type;
    
    -- Internal signals
    signal max_exp : std_logic_vector(ex_width-1 downto 0);
    signal current_sum : std_logic_vector(precision-1 downto 0);
    signal vector_count : integer range 0 to vector_length;
    signal mac_output : std_logic_vector(precision-1 downto 0);
    signal ready_for_data : std_logic;
    
    -- MAC component signals
    signal mac_a, mac_b, mac_c : std_logic_vector(precision-1 downto 0);
    signal mac_valid : std_logic;
begin
    -- MAC instance
    mac_inst: entity work.MAC
    generic map (
        precision => precision,
        precision64 => 64,
        ex_width => ex_width,
        man_width => man_width,
        cut => 11,
        offset => 0
    )
    port map (
        a => mac_a,
        b => mac_b,
        c => mac_c,
        max_exp => max_exp,
        clk => clk,
        n_rst => n_rst,
        sum => mac_output
    );

    -- Main process
    process(clk, n_rst)
        variable temp_exp : unsigned(ex_width-1 downto 0);
    begin
        if n_rst = '0' then
            state <= IDLE;
            vector_count <= 0;
            max_exp <= (others => '0');
            ready_for_data <= '0';
            mac_valid <= '0';
            m_axis_result_tvalid <= '0';
            m_axis_result_tlast <= '0';
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    if initial_valid = '1' then
                        current_sum <= initial_sum;
                        state <= CALC_MAX_EXP;
                        vector_count <= 0;
                        ready_for_data <= '1';
                    end if;
                    
                when CALC_MAX_EXP =>
                    if s_axis_a_tvalid = '1' and s_axis_b_tvalid = '1' then
                        -- Extract exponents and calculate max
                        temp_exp := unsigned(s_axis_a_tdata(precision-2 downto man_width)) + 
                                  unsigned(s_axis_b_tdata(precision-2 downto man_width)) - 127;
                        
                        if vector_count = 0 then
                            max_exp <= std_logic_vector(temp_exp);
                        elsif unsigned(max_exp) < temp_exp then
                            max_exp <= std_logic_vector(temp_exp);
                        end if;
                        
                        vector_count <= vector_count + 1;
                        
                        if s_axis_a_tlast = '1' or vector_count = vector_length-1 then
                            state <= PROCESSING;
                            vector_count <= 0;
                        end if;
                    end if;
                    
                when PROCESSING =>
                    if s_axis_a_tvalid = '1' and s_axis_b_tvalid = '1' then
                        -- Pass data to MAC
                        mac_a <= s_axis_a_tdata;
                        mac_b <= s_axis_b_tdata;
                        mac_c <= current_sum;
                        mac_valid <= '1';
                        
                        -- Update for next iteration
                        current_sum <= mac_output;
                        vector_count <= vector_count + 1;
                        
                        if s_axis_a_tlast = '1' or vector_count = vector_length-1 then
                            state <= DONE;
                        end if;
                    end if;
                    
                when DONE =>
                    if m_axis_result_tready = '1' then
                        m_axis_result_tdata <= mac_output;
                        m_axis_result_tvalid <= '1';
                        m_axis_result_tlast <= '1';
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;
    
    -- Assign ready signals
    s_axis_a_tready <= ready_for_data;
    s_axis_b_tready <= ready_for_data;

end architecture;