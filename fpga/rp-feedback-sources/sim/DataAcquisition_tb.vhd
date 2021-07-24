library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity DataAcquisition_tb is
--  Port ( );
end DataAcquisition_tb;

architecture Behavioral of DataAcquisition_tb is

component DualChannelAcquisition is
    port(
        --
        -- Clocking and reset
        --
        sysClk          :   in  std_logic;                          --Clock for pulses and reading data from memory
        adcClk          :   in  std_logic;                          --Clock for ADCs and writing data to memory
        aresetn         :   in  std_logic;                          --Asynchronous reset

        --
        -- Input signals
        --
        cntrl_i         :   in  t_control;                          --Control signal for pulses
        adcData_i       :   in  t_adc_combined;                     --Combined ADC data
        
        --
        -- Parameter registers
        --
        pulseRegs       :   in  t_param_reg_array(2 downto 0);      --Registers for controlling pulses
        avgReg          :   in  t_param_reg;                        --Register for controlling quick averaging/downsampling
        integrateRegs   :   in  t_param_reg_array(1 downto 0);      --Registers for controlling integration

        --
        -- Memory signals
        --
        bus_m           :   in  t_mem_bus_master_array(1 downto 0); --Master memory bus signals
        bus_s           :   out t_mem_bus_slave_array(1 downto 0);  --Slave memory bus signals

        --
        -- Output data
        --
        data_o          :   out t_adc_integrated_array(1 downto 0); --Integrated output data for both ADCs
        valid_o         :   out std_logic;                          --Output signal high for one adcClk cycle when data_o is valid

        --
        -- Output signals
        --
        pulse_o         :   out std_logic;                          --Output pulse signal
        shutter_o       :   out std_logic;                          --Output shutter signal
        status_o        :   out t_module_status                     --Output module status
    );
end component;

constant clkPeriod  :   time    :=  10 ns;

signal sysClk, adcClk, aresetn  :   std_logic  :=  '0';
signal adcData_i                :   std_logic_vector(31 downto 0)   :=  (others => '0');

signal mem_bus_m                :   t_mem_bus_master_array(1 downto 0)  :=  (others => INIT_MEM_BUS_MASTER);
signal mem_bus_s                :   t_mem_bus_slave_array(1 downto 0)   :=  (others => INIT_MEM_BUS_SLAVE);

--
-- Acquisition registers
--
signal pulseRegs            :   t_param_reg_array(2 downto 0)   :=  (others => (others => '0'));
signal avgReg               :   t_param_reg                     :=  (others => '0');
signal integrateRegs        :   t_param_reg_array(1 downto 0)   :=  (others => (others => '0'));

--
-- Shared signals
--
signal trig                 :   std_logic                       :=  '0';
signal manualFlag           :   std_logic                       :=  '0';
signal acqControl_i         :   t_control                       :=  INIT_CONTROL_ENABLED;

--
-- Signal acquisition signals
--
signal pulseSignal          :   std_logic;
signal shutterSignal        :   std_logic;
signal statusSignal         :   t_module_status                 :=  INIT_MODULE_STATUS;

signal pulseSignalMan       :   std_logic                       :=  '0';
signal shutterSignalMan     :   std_logic                       :=  '0';
signal signalDefaultState   :   std_logic                       :=  '1';

signal dataIntSignal        :   t_adc_integrated_array(1 downto 0)  :=  (others => (others => '0'));
signal validIntSignal       :   std_logic                       :=  '0';

begin

uut: DualChannelAcquisition
port map(
    sysClk          =>  sysClk,
    adcClk          =>  adcClk,
    aresetn         =>  aresetn,

    cntrl_i         =>  acqControl_i,
    adcData_i       =>  adcData_i,

    pulseRegs       =>  pulseRegs,
    avgReg          =>  avgReg,
    integrateRegs   =>  integrateRegs,

    bus_m           =>  mem_bus_m(1 downto 0),
    bus_s           =>  mem_bus_s(1 downto 0),

    data_o          =>  dataIntSignal,
    valid_o         =>  validIntSignal,

    pulse_o         =>  pulseSignal,
    shutter_o       =>  shutterSignal,
    status_o        =>  statusSignal
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

adcData_i <= X"00030001" when pulseSignal = '1' else (others => '0');

tb: process is
begin
    aresetn <= '0';
    pulseRegs(0) <= X"0002" & X"0008";
    pulseRegs(1) <= X"000001F4";
    pulseRegs(2) <= (others => '0');
    avgReg <= X"0" & std_logic_vector(to_unsigned(100,14)) & std_logic_vector(to_unsigned(0,14));
    integrateRegs(0) <= std_logic_vector(to_unsigned(5,10) & to_unsigned(10,11) & to_unsigned(1,11));
    integrateRegs(1) <= X"1" & std_logic_vector(to_unsigned(1,14) & to_unsigned(1,14));
    
    acqControl_i <= INIT_CONTROL_ENABLED; 
    wait for 50 ns;
    aresetn <= '1';

    wait until sysClk'event and sysClk = '1';
    acqControl_i.start <= '1';
    wait until sysClk'event and sysClk = '1';
    acqControl_i.start <= '0';
    wait for 70*clkPeriod;
--    wait until adcClk'event and adcClk = '1';
--    powValid_i <= '1';
--    wait until adcClk'event and adcClk = '1';
--    powValid_i <= '0';
    wait;
end process;


end Behavioral;
