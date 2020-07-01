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
        sysClk          :   in  std_logic;
        adcClk          :   in  std_logic;
        aresetn         :   in  std_logic;
        cntrl_i         :   in  t_control;
        
        computeReg0     :   in  t_param_reg;
        computeReg1     :   in  t_param_reg;
        computeReg2     :   in  t_param_reg;
        computeReg3     :   in  t_param_reg;
        
        pulseReg0       :   in  t_param_reg;
        pulseReg1       :   in  t_param_reg;
        
        auxReg0         :   in  t_param_reg;
        
        quad_i          :   in  unsigned(QUAD_WIDTH-1 downto 0);
        valid_i         :   in  std_logic;
        
        cntrl_o         :   out t_control;
        pulse_o         :   out std_logic
    );
end component;

constant clkPeriod  :   time    :=  10 ns;

signal sysClk, adcClk, aresetn  :   std_logic  :=  '0';

signal computeReg0, computeReg1, computeReg2, computeReg3, pulseReg0, pulseReg1, auxReg0   :   t_param_reg :=  (others => '0');
signal quad_i       :   unsigned(QUAD_WIDTH-1 downto 0)   :=  (others => '0');
signal valid_i, pulse_o      :  std_logic   :=  '0';
signal cntrl_i, cntrl_o :   t_control   :=  INIT_CONTROL_ENABLED;

signal numPulses0   :   std_logic_vector(PULSE_NUM_WIDTH-1 downto 0);
signal quadTarget   :   std_logic_vector(QUAD_WIDTH+PULSE_NUM_WIDTH-1 downto 0);
signal quadTol      :   std_logic_vector(QUAD_WIDTH-1 downto 0);
signal numPulsesMW  :   std_logic_vector(PULSE_NUM_WIDTH-1 downto 0);
signal pulseWidthMW :   std_logic_vector(PULSE_NUM_WIDTH-1 downto 0);
signal pulsePeriodMW:   std_logic_vector(31 downto 0);

begin

uut: NumberStabilisation
port map(
    sysClk      =>  sysClk,
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    cntrl_i     =>  cntrl_i,
    
    computeReg0 =>  computeReg0,
    computeReg1 =>  computeReg1,
    computeReg2 =>  computeReg2,
    computeReg3 =>  computeReg3,
    
    pulseReg0   =>  pulseReg0,
    pulseReg1   =>  pulseReg1,
    
    auxReg0     =>  auxReg0,
    
    quad_i      =>  quad_i,
    valid_i     =>  valid_i,
    
    cntrl_o     =>  cntrl_o,
    pulse_o     =>  pulse_o
);

-- Clock process definitions
clk_process :process
begin
	sysClk <= '0';
	adcClk <= '0';
	wait for clkPeriod/2;
	sysClk <= '1';
	adcClk <= '1';
	wait for clkPeriod/2;
end process;

tb: process is
begin
    aresetn <= '0';
    valid_i <= '0';
    
    quad_i <= to_unsigned(10000,quad_i'length);
    numPulses0 <= std_logic_vector(to_unsigned(15,numPulses0'length));
    quadTarget <= std_logic_vector(to_unsigned(100000,quadTarget'length));
    quadTol <= std_logic_vector(to_unsigned(5250,quadTol'length));
    
    numPulsesMW <= std_logic_vector(to_unsigned(10,numPulsesMW'length));
    pulsePeriodMW <= std_logic_vector(to_unsigned(10,pulsePeriodMW'length));
    pulseWidthMW <= std_logic_vector(to_unsigned(2,pulseWidthMW'length));
    
    auxReg0 <= (0 => '0', others => '0');
    
    wait for 50 ns;
    computeReg0 <= quadTarget(15 downto 0) & numPulses0;
    computeReg1 <= quadTarget(quadTarget'length-8-1 downto 16);
    computeReg2 <= quadTol(23 downto 0) & quadTarget(quadTarget'length-1 downto quadTarget'length-8);
    computeReg3(15 downto 0) <= quadTol(39 downto 24);
    
    pulseReg0 <= numPulsesMW & pulseWidthMW;
    pulseReg1 <= pulsePeriodMW;
    cntrl_i <= (start => '0', stop => '0', enable => '1', debug => (others => '0'));

    wait for 50 ns;
    aresetn <= '1';

    wait until sysClk'event and sysClk = '1';
    valid_i <= '1';
    cntrl_i.start <= '1';
    wait until sysClk'event and sysClk = '1';
    valid_i <= '0';
    cntrl_i.start <= '0';
    wait for 50*clkPeriod;
    wait until sysClk'event and sysClk = '1';
    quad_i <= to_unsigned(5150,quad_i'length);
    wait for 50*clkPeriod;
    wait until sysClk'event and sysClk = '1';
    valid_i <= '1';
    wait until sysClk'event and sysClk = '1';
    valid_i <= '0';
    
    wait for 100*clkPeriod;
    wait;
end process;


end Behavioral;
