library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity NumberStabilisation is
    port(
        clk             :   in  std_logic;                          --Clock signal synchronous with ratio_i
        aresetn         :   in  std_logic;                          --Asynchronous clock signal
        cntrl_i         :   in  t_control;                          --Input control signals
        
        --
        -- Computation registers
        -- In descending order, concatenating arrays:
        -- (tolerance (24), target (24), maximum number of pulses (16))
        --
        computeRegs     :   in  t_param_reg_array(1 downto 0);
        --
        -- Pulse parameter registers
        -- 0 : (manual number of pulses (16), pulse width (16))
        -- 1 : (pulse period (32))
        --
        pulseRegs_i     :   in  t_param_reg_array(1 downto 0);
        auxReg          :   in  t_param_reg;                        --Auxiliary register (X (31), enable software triggers (1))
        
        ratio_i         :   in  unsigned(SIGNAL_WIDTH-1 downto 0);  --Input signal as a ratio
        valid_i         :   in  std_logic;                          --High for one cycle when ratio_i is valid
        
        cntrl_o         :   out t_control;                          --Output control signal
        pulse_o         :   out std_logic                           --Output microwave pulses
    );
end NumberStabilisation;

architecture Behavioral of NumberStabilisation is

COMPONENT NumPulses_Divider
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_divisor_tvalid : IN STD_LOGIC;
    s_axis_divisor_tready : OUT STD_LOGIC;
    s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    s_axis_dividend_tvalid : IN STD_LOGIC;
    s_axis_dividend_tready : OUT STD_LOGIC;
    s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(39 DOWNTO 0)
  );
END COMPONENT;

COMPONENT NumPulses_Multiplier
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

component PulseGen is
    port(
        clk         :   in  std_logic;                      --Input clock
        aresetn     :   in  std_logic;                      --Asynchronous reset
        cntrl_i     :   in  t_control;                      --Control structure
        
        --
        -- Array of parameters:
        -- 2: delay
        -- 1: period
        -- 0: (number of pulses (16), pulse width (16))
        --
        regs        :   in  t_param_reg_array(2 downto 0);
        
        pulse_o     :   out std_logic;                      --Output pulse
        status_o    :   out t_module_status                 --Output module status
    );
end component;   

constant DIVIDE_LATENCY :   natural :=  50;
constant MULT_LATENCY   :   natural :=  4;
constant MAX_NUM_PULSES :   natural :=  65535;

type t_status_local is (idle, dividing, multiplying, pulsing);
signal state            :   t_status_local                      :=  idle;
signal count            :   natural range 0 to 255              :=  0;

--
-- Software trigger signals
--
signal enableSoftTrig   :   std_logic   :=  '0';
signal trigSoft         :   std_logic   :=  '0';
signal trigSoftSync     :   std_logic_vector(1 downto 0)        :=  (others => '0');


--
-- Microwave pulse control signals
--
signal pulseCntrl       :   t_control                           :=  INIT_CONTROL_ENABLED;
signal pulseStatus      :   t_module_status                     :=  INIT_MODULE_STATUS;
signal pulseTrig        :   std_logic                           :=  '0';
signal pulseRegs        :   t_param_reg_array(2 downto 0)       :=  (others => (others => '0'));
signal numPulsesMan     :   std_logic_vector(PULSE_NUM_WIDTH-1 downto 0)    :=  (others => '0');

--
-- Feedback parameters
--
signal numPulsesMax     :   unsigned(PULSE_NUM_WIDTH-1 downto 0)                :=  (others => '0');
signal numPulsesCalc    :   unsigned(PULSE_NUM_WIDTH-1 downto 0)                :=  (others => '0');
signal numPulses_slv    :   std_logic_vector(2*PULSE_NUM_WIDTH-1 downto 0)      :=  (others => '0');
signal target           :   unsigned(SIGNAL_WIDTH-1 downto 0)                   :=  (others => '0');
signal tol              :   unsigned(SIGNAL_WIDTH-1 downto 0)                   :=  (others => '0');
signal diff             :   unsigned(SIGNAL_WIDTH-1 downto 0)                   :=  (others => '0');

signal div_o            :   std_logic_vector(39 downto 0)                       :=  (others => '0');
signal divValid         :   std_logic;


begin


numPulsesMax <= resize(unsigned(computeRegs(0)(15 downto 0)),numPulsesMax'length);
target <= unsigned(computeRegs(1)(7 downto 0)) & unsigned(computeRegs(0)(31 downto 16));
tol <= unsigned(computeRegs(1)(31 downto 8));
--target <= unsigned(computeRegs(1)) & unsigned(computeRegs(0)(31 downto 16));
--tol <= unsigned(computeRegs(3)(15 downto 0)) & unsigned(computeRegs(2));

PulseNumberDivision : NumPulses_Divider
PORT MAP (
    aclk                    => clk,
    s_axis_divisor_tvalid   => valid_i,
    s_axis_divisor_tdata    => std_logic_vector(ratio_i),
    s_axis_dividend_tvalid  => valid_i,
    s_axis_dividend_tdata   => std_logic_vector(diff),
    m_axis_dout_tvalid      => divValid,
    m_axis_dout_tdata       => div_o
);

PulseNumberMultiply: NumPulses_Multiplier
port map(
    CLK =>  clk,
    A   =>  div_o(PULSE_NUM_WIDTH-1 downto 0),
    B   =>  std_logic_vector(numPulsesMax),
    P   =>  numPulses_slv
);

--
-- Synchronizes the software trigger to the clk
--
TriggerSync: process(clk,aresetn) is
begin
    if aresetn = '0' then
        trigSoftSync <= "00";
    elsif rising_edge(clk) then
        trigSoftSync <= trigSoftSync(0) & cntrl_i.start;
    end if;
end process;

--
-- Creates a single-cycle high clock signal on the rising edge of the synchronized trigger
-- Only creates this trigger when the stabilisation routine is disabled (cntrl_i.enable = '0')
--
enableSoftTrig <= auxReg(0);
TrigCreate: process(clk,aresetn) is
begin
    if aresetn = '0' then
        trigSoft <= '0';
    elsif rising_edge(clk) then
        if trigSoftSync = "01" and cntrl_i.enable = '0' and enableSoftTrig = '1' then
            trigSoft <= '1';
        else
            trigSoft <= '0';
        end if;
    end if;
end process;

--
-- Start and enable signals for the microwave pulses.  Trigger and enable either when manual pulses
-- are enabled or when feedback is enabled
--
pulseCntrl.start <= pulseTrig or trigSoft;
pulseCntrl.enable <= cntrl_i.enable or enableSoftTrig;

--
-- Define pulse parameters, instantiate pulse generator
--
pulseRegs(0)(PARAM_WIDTH-1 downto 16) <= pulseRegs_i(0)(PARAM_WIDTH-1 downto 16) when cntrl_i.enable = '0' else std_logic_vector(numPulsesCalc);
pulseRegs(0)(15 downto 0) <= pulseRegs_i(0)(15 downto 0);
pulseRegs(1) <= pulseRegs_i(1);
pulseRegs(2) <= (others => '0');

MicrowavePulses: PulseGen
port map(
    clk     =>  clk,
    aresetn =>  aresetn,
    cntrl_i =>  pulseCntrl,
    regs    =>  pulseRegs,
    pulse_o =>  pulse_o,
    status_o=>  pulseStatus
);



ComputeProcess: process(clk,aresetn) is
begin
    if aresetn = '0' then
        state <= idle;
        pulseTrig <= '0';
        numPulsesCalc <= (others => '0');
        cntrl_o <= INIT_CONTROL_ENABLED;
        diff <= (others => '0');
    elsif rising_edge(clk) then
        ComputeFSM: case(state) is
            when idle =>
                pulseTrig <= '0';
                if valid_i = '1' and cntrl_i.enable = '1' then
                    if ratio_i > tol and ratio_i > target then
                        diff <= ratio_i - target;
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
                    state <= multiplying;
                end if;
                
            when multiplying =>
                if count < MULT_LATENCY then
                    count <= count + 1;
                else
                    count <= 0;
                    numPulsesCalc <= resize(shift_right(unsigned(numPulses_slv),16),numPulsesCalc'length);
                    state <= pulsing;
                    pulseTrig <= '1';
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
