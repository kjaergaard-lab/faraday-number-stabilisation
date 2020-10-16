library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity ComputeSignal is
    port(
        clk         :   in  std_logic;                              --Clock synchronous with data_i
        aresetn     :   in  std_logic;                              --Asynchronous reset
        
        dataS_i     :   in  t_adc_integrated_array(1 downto 0);     --Input signal integrated data on two channels
        validS_i    :   in  std_logic;                              --High for one cycle when data_i is valid
        
        dataA_i     :   in  t_adc_integrated_array(1 downto 0);     --Input auxiliary integrated data on two channels
        validA_i    :   in  std_logic;                              --High for one cycle when data_i is valid
        
        useFixedGain:   in  std_logic;                              --Use fixed gain/auxiliary values
        fixedGains  :   in  t_param_reg_array(1 downto 0);          --The fixed gain/auxiliary values to use
        
        ratio_o     :   out signed(SIGNAL_WIDTH-1 downto 0);        --Output division signal
        valid_o     :   out std_logic                               --High for one cycle when ratio_o is valid
    );
end ComputeSignal;

architecture Behavioral of ComputeSignal is

COMPONENT BiSignalMultiplier
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
  );
END COMPONENT;

COMPONENT SignalDivider
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_divisor_tvalid : IN STD_LOGIC;
    s_axis_divisor_tready : OUT STD_LOGIC;
    s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    s_axis_dividend_tvalid : IN STD_LOGIC;
    s_axis_dividend_tready : OUT STD_LOGIC;
    s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
  );
END COMPONENT;

type t_signal_slv is array(1 downto 0) of std_logic_vector(INTEG_WIDTH-1 downto 0);
type t_prod_slv is array(1 downto 0) of std_logic_vector(2*INTEG_WIDTH-1 downto 0);

type t_status_local is (idle,multiplying,waiting_signal,waiting_aux,dividing);

constant MULT_LATENCY   :   natural                         :=  7;
constant DIV_LATENCY    :   natural                         :=  85;

signal state            :   t_status_local                  :=  idle;
signal count            :   natural range 0 to 255          :=  0;


signal signal_slv       :   t_signal_slv                    :=  (others => (others => '0'));
signal aux_slv          :   t_signal_slv                    :=  (others => (others => '0'));
signal prod_slv         :   t_prod_slv                      :=  (others => (others => '0'));
signal sum_slv          :   std_logic_vector(47 downto 0)   :=  (others => '0');
signal diff_slv         :   std_logic_vector(47 downto 0)   :=  (others => '0');

signal prod_valid       :   std_logic                       :=  '0';
signal div_valid        :   std_logic;
signal div_o            :   std_logic_vector(63 downto 0);

signal div_int, div_frac:   signed(SIGNAL_WIDTH-1 downto 0) :=  (others => '0');


begin

--
-- Parse parameters
--
--fixedGain_slv(0) <= multipliers(GAIN_WIDTH-1 downto 0);
--fixedGain_slv(1) <= multipliers(PARAM_WIDTH-1 downto GAIN_WIDTH);

--
-- Convert signal data
--
signal_slv(0) <= std_logic_vector(dataS_i(0));
signal_slv(1) <= std_logic_vector(dataS_i(1));

--
-- Note the reversal of the indices so that we get g_0 x S_1 and g_1 x S_0
--
aux_slv(0) <= std_logic_vector(dataA_i(1)) when useFixedGain = '0' else std_logic_vector(fixedGains(1)(INTEG_WIDTH-1 downto 0));
aux_slv(1) <= std_logic_vector(dataA_i(0)) when useFixedGain = '0' else std_logic_vector(fixedGains(0)(INTEG_WIDTH-1 downto 0));

--
-- Multiply signals
--
GEN_SIG_MULT: for I in 0 to 1 generate
    SignalMultX: BiSignalMultiplier
    port map(
        CLK =>  clk,
        A   =>  signal_slv(I),
        B   =>  aux_slv(I),
        P   =>  prod_slv(I)
    );
end generate GEN_SIG_MULT;


SIG_DIV: SignalDivider
port map(
    aclk                    =>  clk,
    s_axis_divisor_tvalid   =>  prod_valid,
    s_axis_divisor_tdata    =>  sum_slv,
    s_axis_dividend_tvalid  =>  prod_valid,
    s_axis_dividend_tdata   =>  diff_slv,
    m_axis_dout_tvalid      =>  div_valid,
    m_axis_dout_tdata       =>  div_o
);

div_int <= resize(signed(div_o(div_o'length-1 downto 16)),SIGNAL_WIDTH);
div_frac <= resize(signed(div_o(15 downto 0)),SIGNAL_WIDTH);

MainProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        count <= 0;
        state <= idle;
        prod_valid <= '0';
        valid_o <= '0';
        ratio_o <= (others => '0');
        sum_slv <= (0 => '1', others => '0');
        diff_slv <= (others => '0');
    elsif rising_edge(clk) then
        FSM: case (state) is
            when idle =>
                valid_o <= '0';
                prod_valid <= '0';
                count <= 0;
                if useFixedGain = '1' then
                    if validS_i = '1' then
                        state <= multiplying;
                    end if;
                else
                    if validS_i = '1' and validA_i = '1' then
                        state <= multiplying;
                    elsif validS_i = '1' then
                        state <= waiting_aux;
                    elsif validA_i = '1' then
                        state <= waiting_signal;
                    end if;
                end if;
                
            when waiting_aux =>
                if validA_i = '1' then
                    state <= multiplying;
                end if;
                
            when waiting_signal =>
                if validS_i = '1' then
                    state <= multiplying;
                end if;

            when multiplying =>
                if count < MULT_LATENCY then
                    count <= count + 1;
                else
                    count <= 0;
                    prod_valid <= '1';
                    sum_slv <= std_logic_vector(signed(prod_slv(0)) + signed(prod_slv(1)));
                    diff_slv <= std_logic_vector(signed(prod_slv(0)) - signed(prod_slv(1)));
                    state <= dividing;
                end if;
                
            when dividing =>
                prod_valid <= '0';
                if count < DIV_LATENCY then
                    count <= count + 1;
                else
                    count <= 0;
                    ratio_o <= div_frac;
                    valid_o <= '1';
                    state <= idle;
                end if;
            
            when others => state <= idle;
        end case;
    end if;
end process;

end Behavioral;
