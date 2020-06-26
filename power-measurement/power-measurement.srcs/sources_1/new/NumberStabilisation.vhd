library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity NumberStabilisation is
    port(
        sysClk          :   in  std_logic;
        adcClk          :   in  std_logic;
        aresetn         :   in  std_logic;
        cntrl_i         :   in  t_control;
        
        computeReg0     :   in  t_param_reg;
        computeReg1     :   in  t_param_reg;
        computeReg2     :   in  t_param_reg;
        
        pulseReg0       :   in  t_param_reg;
        pulseReg1       :   in  t_param_reg;
        
        quad_i          :   in  unsigned(23 downto 0);
        valid_i         :   in  std_logic;
        
        cntrl_o         :   out t_control;
        pulse_o         :   out std_logic
        
    );
end NumberStabilisation;

architecture Behavioral of NumberStabilisation is

COMPONENT NumPulses_Divider
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_divisor_tvalid : IN STD_LOGIC;
    s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    s_axis_dividend_tvalid : IN STD_LOGIC;
    s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(39 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
  );
END COMPONENT;

component PulseGen is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        cntrl_i     :   in  t_control;
        
        reg0        :   in  t_param_reg;
        reg1        :   in  t_param_reg;
        
        pulse_o     :   out std_logic;
        gate_o      :   out std_logic;
        status_o    :   out t_module_status
    );
end component;   

constant DIVIDE_LATENCY :   natural :=  42;

type t_status_local is (idle, dividing, subtracting, pulsing);

signal state    :   t_status_local  :=  idle;

signal numPulses0, numPulses1, numPulses   :   unsigned(39 downto 0)  :=  (others => '0');
signal quadTarget   :   unsigned(39 downto 0)  :=  (others => '0');
signal quadTol      :   unsigned(quad_i'length-1 downto 0)  :=  (others => '0');

signal pulseTrig, pulseTrig_i    :   std_logic   :=  '0';
signal pulseStatus  :   t_module_status :=  INIT_MODULE_STATUS;

signal divideValid  :   std_logic;
signal divideOutput :   std_logic_vector(63 downto 0);

signal count        :   natural range 0 to 255  :=  0;

signal pulseReg0_sig    :   t_param_reg :=  (others => '0');

--signal enableTrig, softTrig :   std_logic   :=  '0';
signal enableSoftTrig :   std_logic   :=  '0';
--signal enable :   std_logic_vector(1 downto 0)    :=  "00";
signal trig :   std_logic   :=  '0';

signal pulseCntrl   :   t_control   :=  INIT_CONTROL_ENABLED;

begin

numPulses0 <= resize(unsigned(computeReg0(15 downto 0)),numPulses0'length);
quadTarget <= unsigned(computeReg1(23 downto 0) & computeReg0(computeReg0'length-1 downto 16));
quadTol <= unsigned(computeReg2(quadTol'length-1 downto 0));

numPulses1 <= unsigned(divideOutput(divideOutput'length-1 downto quad_i'length));


PulseNumberDivision : NumPulses_Divider
PORT MAP (
    aclk => adcClk,
    s_axis_divisor_tvalid => valid_i,
    s_axis_divisor_tdata => std_logic_vector(quad_i),
    s_axis_dividend_tvalid => valid_i,
    s_axis_dividend_tdata => std_logic_vector(quadTarget),
    m_axis_dout_tvalid => divideValid,
    m_axis_dout_tdata => divideOutput
);

--pulseReg0_sig <= std_logic_vector(numPulses(15 downto 0)) & pulseReg0(15 downto 0);
pulseReg0_sig(15 downto 0) <= pulseReg0(15 downto 0);
pulseReg0_sig(31 downto 16) <= std_logic_vector(numPulses(15 downto 0)) when cntrl_i.enable = '1' else pulseReg0(31 downto 16);
--enable <= computeReg2(computeReg2'length-1 downto computeReg2'length-2);
enableSoftTrig <= computeReg2(computeReg2'length-1);
--softTrig <= computeReg2(computeReg2'length-2);

TrigSync: process(adcClk,aresetn) is
begin
    if aresetn = '0' then
        trig <= '0';
    elsif rising_edge(adcClk) then
        if trig = '0' and cntrl_i.enable = '0' and enableSoftTrig = '1' and cntrl_i.start = '1' then
            trig <= '1';
        else
            trig <= '0';
        end if;
    end if;
end process;

--pulseTrig_i <= pulseTrig or trig;
pulseCntrl.start <= pulseTrig or trig;
pulseCntrl.enable <= cntrl_i.enable or enableSoftTrig;

MicrowavePulses: PulseGen
port map(
    clk     =>  sysClk,
    aresetn =>  aresetn,
    cntrl_i =>  pulseCntrl,
    reg0    =>  pulseReg0_sig,
    reg1    =>  pulseReg1,
    pulse_o =>  pulse_o,
    gate_o  =>  open,
    status_o=>  pulseStatus
);

ComputeProcess: process(adcClk,aresetn) is
begin
    if aresetn = '0' then
        state <= idle;
        pulseTrig <= '0';
        numPulses <= (others => '0');
        cntrl_o <= INIT_CONTROL_ENABLED;
    elsif rising_edge(adcClk) then
        ComputeFSM: case(state) is
            when idle =>
                pulseTrig <= '0';
                if valid_i = '1' and cntrl_i.enable = '1' then
                    if quad_i > quadTol then
                        state <= dividing;
                        count <= 0;
                    else
                        cntrl_o.stop <= '1';
                    end if;
                else
                    cntrl_o.stop <= '0';
                end if;
                
            when dividing =>
                if count < DIVIDE_LATENCY then
                    count <= count + 1;
                else
                    count <= 0;
                    if numPulses1 < numPulses0 then
                        numPulses <= numPulses0 - numPulses1;
                        pulseTrig <= '1';
                        state <= pulsing;
                    else
                        state <= idle;
                        cntrl_o.stop <= '1';
                    end if;
                end if;
                
            when pulsing =>
                pulseTrig <= '0';
                if pulseStatus.done = '1' then
                    state <= idle;
                end if;
            when others => state <= idle;
        end case;
    end if;
end process;



end Behavioral;
