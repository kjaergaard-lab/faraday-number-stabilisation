library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity ComputeGain_tb is
--  Port ( );
end ComputeGain_tb;

architecture Behavioral of ComputeGain_tb is

component ComputeGain is
    port(
        clk         :   in  std_logic;                          --Input clock
        aresetn     :   in  std_logic;                          --Asynchronous reset
        
        data_i      :   in  t_adc_integrated_array(1 downto 0); --Input integrated data
        valid_i     :   in  std_logic;                          --High for one clock cycle when data_i is valid

        multipliers :   in  t_param_reg;                        --Multiplication factors (X (16), ADC1 factor (8), ADC2 factor (8))
        
        gain_o      :   out t_gain_array(1 downto 0);           --Output gain values
        valid_o     :   out std_logic                           --High for one clock cycle when gain_o is valid
    );
end component;

constant clkPeriod  :   time    :=  10 ns;

signal sysClk, adcClk, aresetn  :   std_logic  :=  '0';

--
-- Aux signals
--
signal dataIntAux           :   t_adc_integrated_array(1 downto 0)  :=  (others => (others => '0'));
signal validIntAux          :   std_logic                       :=  '0';

signal gainMultipliers      :   t_param_reg                     :=  (others => '0');

signal gain                 :   t_gain_array(1 downto 0)        :=  (others => (others => '0'));
signal gainValid            :   std_logic                       :=  '0';

begin

GainComputation: ComputeGain
port map(
    clk             =>  adcClk,
    aresetn         =>  aresetn,
    
    data_i          =>  dataIntAux,
    valid_i         =>  validIntAux,

    multipliers     =>  gainMultipliers,

    gain_o          =>  gain,
    valid_o         =>  gainValid
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
    dataIntAux <= (0 => X"100000", 1 => X"200000");
    gainMultipliers(31 downto 16) <= X"0000";
    gainMultipliers(15 downto 0) <= X"10" & X"05";
    wait for 50 ns;
    aresetn <= '1';

    wait until sysClk'event and sysClk = '1';
    validIntAux <= '1';
    wait until sysClk'event and sysClk = '1';
    validIntAux <= '0';
    wait for 70*clkPeriod;
--    wait until adcClk'event and adcClk = '1';
--    powValid_i <= '1';
--    wait until adcClk'event and adcClk = '1';
--    powValid_i <= '0';
    wait;
end process;


end Behavioral;
