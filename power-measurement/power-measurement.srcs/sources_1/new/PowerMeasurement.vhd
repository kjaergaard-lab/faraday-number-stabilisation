library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PowerMeasurement is
    port(
        sysClk          :   in  std_logic;
        adcClk          :   in  std_logic;
        aresetn         :   in  std_logic;
        
        cntrl_i         :   in  t_control;
        adcData_i       :   in  t_adc_combined;

        avgReg0         :   in  t_param_reg;
        integrateReg0   :   in  t_param_reg;

        bus_m           :   in  t_mem_bus_master_array(1 downto 0);
        bus_s           :   out t_mem_bus_slave_array(1 downto 0);
        
        power_o         :   out std_logic_vector(23 downto 0);
        valid_o         :   out std_logic
        
    );
end PowerMeasurement;

architecture Behavioral of PowerMeasurement is

component QuickAvg is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        trig_i      :   in  std_logic;
        
        reg0        :   in  t_param_reg;
        
        adcData_i   :   in  t_adc_combined;
        adcData_o   :   out t_adc_combined;
        valid_o     :   out std_logic
    );
end component;

component IntegrateADCData is
    generic(
        PAD         :   natural :=  8;
        EXT_WIDTH   :   natural :=  24
    );
    port(
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        trig_i      :   in  std_logic;
        
        adcData_i   :   in  t_adc_combined;
        valid_i     :   in  std_logic;
        
        reg0        :   in  t_param_reg;
        
        dataI_o     :   out signed(EXT_WIDTH-1 downto 0);
        dataQ_o     :   out signed(EXT_WIDTH-1 downto 0);
        valid_o     :   out std_logic;
        
        dataSave_o  :   out t_mem_data;
        validSave_o :   out std_logic
    );
end component;

component SaveADCData is
    port(
        sysClk      :   in  std_logic;
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        
        data_i      :   in  std_logic_vector;
        valid_i     :   in  std_logic;
        
        bus_m       :   in  t_mem_bus_master;
        bus_s       :   out t_mem_bus_slave
    );
end component;


signal pulse, pulseGate    :   std_logic   :=  '0';
signal pulseStatus  :   t_module_status :=  INIT_MODULE_STATUS;
signal adcAvg   :   t_adc_combined  :=  (others => '0');
signal validAvg :   std_logic;

signal dataI, dataQ :   signed(23 downto 0) :=  (others => '0');
signal validIntegrate   :   std_logic   :=  '0';
signal intSave      :   t_mem_data;
signal intSaveValid :   std_logic;


begin

InitAvg: QuickAvg
port map(
    clk         =>  adcClk,
    aresetn     =>  aresetn,
    trig_i      =>  cntrl_i.start,
    reg0        =>  avgReg0,
    adcData_i   =>  adcData_i,
    adcData_o   =>  adcAvg,
    valid_o     =>  validAvg
);

Integrate: IntegrateADCData
generic map(
    PAD         =>  8,
    EXT_WIDTH   =>  24
)
port map(
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    trig_i      =>  cntrl_i.start,
    adcData_i   =>  adcAvg,
    valid_i     =>  validAvg,
    reg0        =>  integrateReg0,
    dataI_o     =>  dataI,
    dataQ_o     =>  dataQ,
    valid_o     =>  validIntegrate,
    dataSave_o  =>  intSave,
    validSave_o =>  intSaveValid
);

power_o <= std_logic_vector(abs(dataI));
valid_o <= validIntegrate;

SaveAvgData: SaveADCData
port map(
    sysClk      =>  sysClk,
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    data_i      =>  adcAvg,
    valid_i     =>  validAvg,
    bus_m       =>  bus_m(0),
    bus_s       =>  bus_s(0)
);

SaveQuadSignal: SaveADCData
port map(
    sysClk      =>  sysClk,
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    data_i      =>  intSave,
    valid_i     =>  intSaveValid,
    bus_m       =>  bus_m(1),
    bus_s       =>  bus_s(1)
);

end Behavioral;
