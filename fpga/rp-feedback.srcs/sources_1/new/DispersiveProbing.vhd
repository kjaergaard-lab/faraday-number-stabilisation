library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity DispersiveProbing is
    port(
        sysClk          :   in  std_logic;
        adcClk          :   in  std_logic;
        aresetn         :   in  std_logic;

        trig_i          :   in  std_logic;
        cntrl_i         :   in  std_logic;
        adcData_i       :   in  t_adc_combined;

        pulseReg0       :   in  t_param_reg;
        pulseReg1       :   in  t_param_reg;
        avgReg0         :   in  t_param_reg;
        integrateReg0   :   in  t_param_reg;

        bus_m           :   in  t_mem_bus_master_array(1 downto 0);
        bus_s           :   out t_mem_bus_slave_array(1 downto 0);

        quad_o          :   out unsigned(23 downto 0);
        valid_o         :   out std_logic;
        pulse_o         :   out std_logic;
        shutter_o       :   out std_logic
    );
end DispersiveProbing;

architecture Behavioral of DispersiveProbing is

component PulseGen is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        trig_i      :   in  std_logic;   
        cntrl_i     :   in  std_logic;
        
        reg0        :   in  t_param_reg;
        reg1        :   in  t_param_reg;
        
        pulse_o     :   out std_logic;
        gate_o      :   out std_logic;
        status_o    :   out std_logic
    );
end component;    

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
        valid_o     :   out std_logic
    );
end component;

component ComputeSignal is
    port(
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        
        dataI_i     :   in  signed(23 downto 0);
        dataQ_i     :   in  signed(23 downto 0);
        valid_i     :   in  std_logic;
        
        quad_o      :   out unsigned(23 downto 0);
        valid_o     :   out std_logic
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


signal pulse, pulseGate, pulseStatus    :   std_logic   :=  '0';
signal adcAvg   :   t_adc_combined  :=  (others => '0');
signal validAvg :   std_logic;

signal dataI, dataQ :   signed(23 downto 0) :=  (others => '0');
signal validIntegrate   :   std_logic   :=  '0';

signal quadSignal   :   unsigned(23 downto 0);
signal validQuad    :   std_logic   :=  '0';

begin

Pulses: PulseGen
port map(
    clk     =>  sysClk,
    aresetn =>  aresetn,
    trig_i  =>  trig_i,
    cntrl_i =>  cntrl_i,
    reg0    =>  pulseReg0,
    reg1    =>  pulseReg1,
    pulse_o =>  pulse,
    gate_o  =>  pulseGate,
    status_o=>  pulseStatus
);
pulse_o <= pulse;
shutter_o <= pulseStatus;

InitAvg: QuickAvg
port map(
    clk         =>  adcClk,
    aresetn     =>  aresetn,
    trig_i      =>  pulse,
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
    trig_i      =>  pulse,
    adcData_i   =>  adcAvg,
    valid_i     =>  validAvg,
    reg0        =>  integrateReg0,
    dataI_o     =>  dataI,
    dataQ_o     =>  dataQ,
    valid_o     =>  validIntegrate
);

Compute: ComputeSignal
port map(
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    dataI_i     =>  dataI,
    dataQ_i     =>  dataQ,
    valid_i     =>  validIntegrate,
    quad_o      =>  quadSignal,
    valid_o     =>  validQuad
);

quad_o <= quadSignal;
valid_o <= validQuad;

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
    data_i      =>  std_logic_vector(quadSignal),
    valid_i     =>  validQuad,
    bus_m       =>  bus_m(1),
    bus_s       =>  bus_s(1)
);

end Behavioral;
