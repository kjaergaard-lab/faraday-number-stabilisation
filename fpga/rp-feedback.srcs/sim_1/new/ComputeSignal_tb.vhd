library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity ComputeSignal_tb is
--  Port ( );
end ComputeSignal_tb;

architecture Behavioral of ComputeSignal_tb is

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

component ComputeSignal is
    port(
        clk         :   in  std_logic;                              --Clock synchronous with data_i
        aresetn     :   in  std_logic;                              --Asynchronous reset
        
        data_i      :   in  t_adc_integrated_array(1 downto 0);     --Input integrated data on two channels
        valid_i     :   in  std_logic;                              --High for one cycle when data_i is valid
        
        gain_i      :   in  t_gain_array(1 downto 0);               --Input gain values on two channels
        validGain_i :   in  std_logic;                              --High for one cycle when gain_i is valid
        
        useFixedGain:   in  std_logic;                              --Use fixed gain multipliers
        multipliers :   in  t_param_reg;                            --Fixed gain multipliers (ch 1 (16), ch 0 (16))
        
        ratio_o     :   out unsigned(SIGNAL_WIDTH-1 downto 0);      --Output division signal
        valid_o     :   out std_logic                               --High for one cycle when ratio_o is valid
    );
end component;


constant clkPeriod  :   time    :=  10 ns;

signal sysClk, adcClk, aresetn  :   std_logic  :=  '0';

--
-- Signal signals
--
signal dataIntSignal        :   t_adc_integrated_array(1 downto 0)  :=  (others => (others => '0'));
signal validIntSignal       :   std_logic                       :=  '0';

signal useFixedGain         :   std_logic                       :=  '0';
signal fixedGains           :   t_param_reg                     :=  (others => '0');

--
-- Aux signals
--
signal dataIntAux           :   t_adc_integrated_array(1 downto 0)  :=  (others => (others => '0'));
signal validIntAux          :   std_logic                       :=  '0';

signal gainMultipliers      :   t_param_reg                     :=  (others => '0');

signal gain                 :   t_gain_array(1 downto 0)        :=  (others => (others => '0'));
signal gainValid            :   std_logic                       :=  '0';

signal ratio                :   unsigned(SIGNAL_WIDTH-1 downto 0)   :=  (others => '0');
signal ratioValid           :   std_logic                       :=  '0';

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

SignalComputation: ComputeSignal
port map(
    clk             =>  adcClk,
    aresetn         =>  aresetn,

    data_i          =>  dataIntSignal,
    valid_i         =>  validIntSignal,

    gain_i          =>  gain,
    validGain_i     =>  gainValid,

    useFixedGain    =>  useFixedGain,
    multipliers     =>  fixedGains,

    ratio_o         =>  ratio,
    valid_o         =>  ratioValid
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
    dataIntAux <= (0 => to_signed(5000*150,INTEG_WIDTH), 1 => to_signed(2000*150,INTEG_WIDTH));
    gainMultipliers(31 downto 16) <= X"0000";
    gainMultipliers(15 downto 0) <= std_logic_vector(to_unsigned(200,8)) & std_logic_vector(to_unsigned(100,8));
    
    dataIntSignal <= (0 => to_signed(500*150,INTEG_WIDTH), 1 => to_signed(2000*150,INTEG_WIDTH));
    useFixedGain <= '0';
    fixedGains <= X"0001" & X"0001";
    wait for 50 ns;
    aresetn <= '1';

    wait until adcClk'event and adcClk = '1';
    validIntSignal <= '1';
    wait until adcClk'event and adcClk = '1';
    validIntSignal <= '0';
    wait for 10*clkPeriod;
    wait until adcClk'event and adcClk = '1';
    validIntAux <= '1';
    wait until adcClk'event and adcClk = '1';
    validIntAux <= '0';
    
    
    wait for 70*clkPeriod;
--    wait until adcClk'event and adcClk = '1';
--    powValid_i <= '1';
--    wait until adcClk'event and adcClk = '1';
--    powValid_i <= '0';
    wait;
end process;

end Behavioral;
