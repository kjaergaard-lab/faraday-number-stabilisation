library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity NumberStabilisation_tb is
--  Port ( );
end NumberStabilisation_tb;

architecture Behavioral of NumberStabilisation_tb is

component NumberStabilisation is
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
        
        ratio_i         :   in  signed(SIGNAL_WIDTH-1 downto 0);    --Input signal as a ratio
        valid_i         :   in  std_logic;                          --High for one cycle when ratio_i is valid
        
        cntrl_o         :   out t_control;                          --Output control signal
        pulse_o         :   out std_logic                           --Output microwave pulses
    );
end component;

constant clkPeriod  :   time    :=  10 ns;

signal clk, aresetn :   std_logic  :=  '0';
signal cntrl_i      :   t_control   :=  INIT_CONTROL_ENABLED;

signal computeRegs  :   t_param_reg_array(1 downto 0)   :=  (others => (others => '0'));
signal pulseRegs    :   t_param_reg_array(1 downto 0)   :=  (others => (others => '0'));
signal auxReg       :   t_param_reg                     :=  (others => '0');
signal ratio_i      :   signed(SIGNAL_WIDTH-1 downto 0)   :=  (others => '0');
signal valid_i      :   std_logic                       :=  '0';

signal cntrl_o      :   t_control;
signal pulse_o      :   std_logic;

signal target, tol  :   std_logic_vector(SIGNAL_WIDTH-1 downto 0)   :=  (others => '0');
signal numPulsesMax :   std_logic_vector(PULSE_NUM_WIDTH-1 downto 0)    :=  (others => '0');
signal numPulsesMan :   std_logic_vector(PULSE_NUM_WIDTH-1 downto 0)    :=  (others => '0');

signal pulsePeriod  :   t_param_reg;
signal pulseWidth   :   std_logic_vector(15 downto 0);

begin

uut: NumberStabilisation
port map(
    clk             =>  clk,
    aresetn         =>  aresetn,
    cntrl_i         =>  cntrl_i,
    
    computeRegs     =>  computeRegs,
    pulseRegs_i     =>  pulseRegs,
    auxReg          =>  auxReg,
    
    ratio_i         =>  ratio_i,
    valid_i         =>  valid_i,
    
    cntrl_o         =>  cntrl_o,
    pulse_o         =>  pulse_o
);

-- Clock process definitions
clk_process :process
begin
	clk <= '0';
	wait for clkPeriod/2;
	clk <= '1';
	wait for clkPeriod/2;
end process;

target <= X"0800";
tol <= X"0810";
numPulsesMax <= std_logic_vector(to_unsigned(10,numPulsesMan'length));
numPulsesMan <= std_logic_vector(to_unsigned(10,numPulsesMan'length));

pulsePeriod <= std_logic_vector(to_unsigned(10,pulsePeriod'length));
pulseWidth <= std_logic_vector(to_unsigned(5,pulseWidth'length));

tb: process is
begin
    aresetn <= '0';
    valid_i <= '0';
    ratio_i <= X"0800";
    wait for 50 ns;
    aresetn <= '1';
    
    computeRegs <= (0 => (target(15 downto 0) & numPulsesMax), 1 => X"0000" & tol);
    pulseRegs <= (0 => (numPulsesMan & pulseWidth), 1 => pulsePeriod);
    auxReg <= (0 => '0', others => '0');
    
    cntrl_i <= (start => '0', stop => '0', enable => '1', debug => (others => '0'));

    wait for 50 ns;

    wait until clk'event and clk = '1';
    cntrl_i.start <= '1';
    wait until clk'event and clk = '1';
    cntrl_i.start <= '0';
    wait for 100 ns;
    wait until clk'event and clk = '1';
    valid_i <= '1';
    wait until clk'event and clk = '1';
    valid_i <= '0';
    wait for 2 us;
    wait until clk'event and clk = '1';
    ratio_i <= X"0400";
    valid_i <= '1';
    wait until clk'event and clk = '1';
    valid_i <= '0';
    wait for 1 us;
    wait;
end process;


end Behavioral;
