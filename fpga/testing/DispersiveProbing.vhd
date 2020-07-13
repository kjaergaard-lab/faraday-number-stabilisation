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

        cntrl_i         :   in  t_control;
        adcData_i       :   in  t_adc_combined;
        
        cntrlReg        :   in  t_param_reg;
        pulseRegs       :   in  t_param_reg_array(3 downto 0);
        procRegs        :   in  t_param_reg_array(1 downto 0);

        bus_m           :   in  t_mem_bus_master_array(1 downto 0);
        bus_s           :   out t_mem_bus_slave_array(1 downto 0);

        amp_o           :   out unsigned(QUAD_WIDTH-1 downto 0);
        valid_o         :   out std_logic;
        
        pulse_o         :   out std_logic;
        aux_o           :   out std_logic;
        shutter_o       :   out std_logic;
        status_o        :   out t_module_status
    );
end DispersiveProbing;

architecture Behavioral of DispersiveProbing is

component PulseGen is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;  
        cntrl_i     :   in  t_control;
        
        regs        :   in  t_param_reg_array(3 downto 0);
        
        pulse_o     :   out std_logic;
        aux_o       :   out std_logic;
        status_o    :   out t_module_status
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

component ProcessPowerData is
    port(
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        trig_i      :   in  std_logic;
        
        adcData_i   :   in  signed(15 downto 0);
        valid_i     :   in  std_logic;
        
        reg0        :   in  t_param_reg;
        
        pow_o       :   out signed(QUAD_BARE_WIDTH-1 downto 0);
        valid_o     :   out std_logic
    );
end component;

component PeakDetection is
    port(
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        trig_i      :   in  std_logic;
        
        adcData_i   :   in  signed(15 downto 0);
        valid_i     :   in  std_logic;
        
        reg0        :   in  t_param_reg;
        
        amp_o       :   out unsigned(15 downto 0);
        valid_o     :   out std_logic
    );
end component;

component ComputeSignal is
    port(
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        
        peak_i      :   in  unsigned(15 downto 0);
        peakValid_i :   in  std_logic;
        pow_i       :   in  unsigned(23 downto 0);
        powValid_i  :   in  std_logic;
        usePow_i    :   in  std_logic;
        
        ratio_o     :   out unsigned(QUAD_WIDTH-1 downto 0);
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


signal pulse, pulseAux        :   std_logic   :=  '0';
signal pulseStatus  :   t_module_status :=  INIT_MODULE_STATUS;
signal adcAvg   :   t_adc_combined  :=  (others => '0');
signal validAvg :   std_logic;

signal ampValid, powValid   :   std_logic   :=  '0';
signal intSave              :   t_mem_data;
signal intSaveValid         :   std_logic;

signal ratio        :   unsigned(QUAD_WIDTH-1 downto 0);
signal ratioValid   :   std_logic   :=  '0';

signal usePow       :   std_logic   :=  '1';

signal statusCount :   unsigned(23 downto 0)    :=  (others => '0');
constant SHUTTER_HOLDOFF    :   unsigned(23 downto 0)   :=  to_unsigned(625000,24);

type t_status_local is (idle, counting, waiting, saving);
signal state    :   t_status_local  :=  idle;
signal combineState :   t_status_local  :=  idle;

begin

--
-- This process creates a status signal for the DispersiveProbing module as a whole
--
StatusProc: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        status_o <= INIT_MODULE_STATUS;
        statusCount <= (others => '0');
        state <= idle;
    elsif rising_edge(sysClk) then
        FSM: case state is
            when idle =>
                statusCount <= (others => '0');
                status_o.done <= '0';
                if pulseStatus.started = '1' then
                    status_o.started <= '1';
                    status_o.running <= '1';
                elsif pulseStatus.done = '1' then
                    state <= counting;
                    status_o.started <= '0';
                else
                    status_o.started <= '0';
                end if;

            when counting =>
                if statusCount < SHUTTER_HOLDOFF then
                    statusCount <= statusCount + 1;
                else
                    status_o.done <= '1';
                    status_o.running <= '0';
                    state <= idle;
                end if;
        end case;
    end if;
end process;

--
-- These commands create the dispersive probing pulses
--
pulse_o <= pulse;
aux_o <= pulseAux;
shutter_o <= pulseStatus.running;

Pulses: PulseGen
port map(
    clk     =>  sysClk,
    aresetn =>  aresetn,
    cntrl_i =>  cntrl_i,
    regs    =>  pulseRegs,
    pulse_o =>  pulse,
    aux_o   =>  pulseAux,
    status_o=>  pulseStatus
);

--
-- An initial quick averaging stage is used to down-sample the data by averaging
-- over N samples where N is a power of 2
--
InitAvg: QuickAvg
port map(
    clk         =>  adcClk,
    aresetn     =>  aresetn,
    trig_i      =>  pulse,
    reg0        =>  procRegs(0),
    adcData_i   =>  adcData_i,
    adcData_o   =>  adcAvg,
    valid_o     =>  validAvg
);

--
-- This module finds the amplitude of a sine signal in a given interval
--
FindAmplitude: PeakDetection
port map(
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    trig_i      =>  pulse,
    adcData_i   =>  signed(adcAvg(15 downto 0)),
    valid_i     =>  validAvg,
    reg0        =>  procRegs(1),
    amp_o       =>  amp,
    valid_o     =>  ampValid
);

--
-- This module calculates the average power signal over the same interval
-- as the PeakDetection module
--
IntegratePower: ProcessPowerData
port map(
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    trig_i      =>  pulse,
    adcData_i   =>  signed(adcAvg(31 downto 0)),
    valid_i     =>  validAvg,
    reg0        =>  procRegs(1),
    pow_o       =>  pow,
    valid_o     =>  powValid,
);

--
-- With the signal amplitude and the power determined we now compute
-- the ratio of the two to normalise out power fluctuations
--
usePow <= cntrlReg(0);

Compute: ComputeSignal
port map(
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    peak_i      =>  amp,
    peakValid_i =>  ampValid,
    pow_i       =>  pow,
    powValid_i  =>  powValid,
    usePow_i    =>  usePow,
    ratio_o     =>  ratio,
    valid_o     =>  ratioValid
);

--
-- Generate output signals
--
amp_o <= ratio;
valid_o <= ratioValid;

--
-- Saves the 'raw' data - really the averaged data
--
SaveRawData: SaveADCData
port map(
    sysClk      =>  sysClk,
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    data_i      =>  adcAvg,
    valid_i     =>  validAvg,
    bus_m       =>  bus_m(0),
    bus_s       =>  bus_s(0)
);

--
-- Save the amplitude data and the averaged power
--
CombinePulseData: process(adcClk,aresetn) is
begin
    if aresetn = '0' then

    elsif rising_edge(adcClk) then
        CombineFSM: case combineState is
            when idle =>
                intSaveValid <= '0';
                if ampValid = '1' then
                    intSave(15 downto 0) <= std_logic_vector(resize(amp,16));
                    if usePow = '1' then
                        combineState <= waiting;
                    else
                        combineState <= saving;
                    end if;
                end if;

            when waiting => 
                if powValid = '1' then
                    intSave(31 downto 16) <= std_logic_vector(pow(pow'length-1 downto pow'length-16));
                    combineState <= saving;
                end if;

            when saving =>
                intSaveValid <= '1';
                combineState <= idle;

            when others => idle;   
        end case;
    end if;
end process;

SaveProcessedSignal: SaveADCData
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
