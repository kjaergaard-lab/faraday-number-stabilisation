library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity DualChannelAcquisition is
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
end DualChannelAcquisition;

architecture Behavioral of DualChannelAcquisition is

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

component QuickAvg is
    port(
        clk         :   in  std_logic;          --Input clock
        aresetn     :   in  std_logic;          --Asynchronous reset
        trig_i      :   in  std_logic;          --Input trigger
        
        reg0        :   in  t_param_reg;        --Parameters: (log2Avgs (4), number of samples (14), delay (14)) 
        
        adcData_i   :   in  t_adc_combined;     --Input ADC data
        adcData_o   :   out t_adc_combined;     --Output, averaged ADC data
        trig_o      :   out std_logic;          --Input trigger delayed by "delay" cycles
        valid_o     :   out std_logic           --Indicates valid averaged data
    );
end component;

component IntegrateADCData is
    port(
        clk         :   in  std_logic;                          --Input clock synchronous with adcData_i
        aresetn     :   in  std_logic;                          --Asynchronous reset
        trig_i      :   in  std_logic;                          --Input trigger synchronous with clk
        
        adcData_i   :   in  t_adc_combined;                     --Two-channel ADC data
        valid_i     :   in  std_logic;                          --1-cycle signal high when adcData_i is valid
        
        --
        -- 1: (X (3 bits), use preset offsets (1), offset adc 2 (14), offset adc 1 (14))
        -- 0: (integration width (10), subtraction start (11), summation start (11))
        --
        regs        :   in  t_param_reg_array(1 downto 0);
        
        data_o      :   out t_adc_integrated_array(1 downto 0); --Integrated data from both ADCs
        valid_o     :   out std_logic;                          --High for one cycle when integrated data is valid
        
        dataSave_o  :   out t_mem_data;                         --Integrated data for memory
        validSave_o :   out std_logic                           --High for one cycle when dataSave_o i valid
    );
end component;

component SaveADCData is
    port(
        readClk     :   in  std_logic;          --Clock for reading data
        writeClk    :   in  std_logic;          --Clock for writing data
        aresetn     :   in  std_logic;          --Asynchronous reset
        
        data_i      :   in  std_logic_vector;   --Input data, maximum length of 32 bits
        valid_i     :   in  std_logic;          --High for one clock cycle when data_i is valid
        
        bus_m       :   in  t_mem_bus_master;   --Master memory bus
        bus_s       :   out t_mem_bus_slave     --Slave memory bus
    );
end component;

--
-- Pulse signals
--
signal pulse            :   std_logic                           :=  '0';
signal pulseStatus      :   t_module_status                     :=  INIT_MODULE_STATUS;

--
-- Averaging signals
--
signal adcAvg           :   t_adc_combined                      :=  (others => '0');
signal validAvg, trigAvg:   std_logic;

--
-- Integrated signals
--
signal dataInt          :   t_adc_integrated_array(1 downto 0)  :=  (others => (others => '0'));
signal validInt         :   std_logic                           :=  '0';
signal intSave          :   t_mem_data;
signal intSaveValid     :   std_logic;

--
-- Shutter delay/holdoff signals
--
type t_status_local is (idle, counting);
signal state                :   t_status_local                  :=  idle;
signal statusCount          :   unsigned(23 downto 0)           :=  (others => '0');
constant SHUTTER_HOLDOFF    :   unsigned(23 downto 0)           :=  to_unsigned(625000,24);

begin

--
-- This process introduces a delay between when the DP pulses finish and when the DP module
-- says that it is done.  This delay is necessary when the system is set up such that the DP
-- AOM is kept on when no sequence is running because the DP signal will be raised before
-- the shutter is closed.  This process makes sure that there is a sufficient delay between
-- when the shutter is closed and when the module says it is finished running.
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
                    --Register the module status as started/running when pulses start
                    status_o.started <= '1';
                    status_o.running <= '1';
                elsif pulseStatus.done = '1' then
                    --When the pulses are done, start counting the shutter holdoff
                    state <= counting;
                    status_o.started <= '0';
                else
                    status_o.started <= '0';
                end if;

            --
            -- When the shutter holdoff is counted out, indicate that the module is done
            --
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

LaserPulses: PulseGen
port map(
    clk     =>  adcClk,
    aresetn =>  aresetn,
    cntrl_i =>  cntrl_i,
    regs    =>  pulseRegs,
    pulse_o =>  pulse,
    status_o=>  pulseStatus
);

pulse_o <= pulse;
shutter_o <= pulseStatus.running;

InitAvg: QuickAvg
port map(
    clk         =>  adcClk,
    aresetn     =>  aresetn,
    trig_i      =>  pulse,
    reg0        =>  avgReg,
    adcData_i   =>  adcData_i,
    adcData_o   =>  adcAvg,
    trig_o      =>  trigAvg,
    valid_o     =>  validAvg
);

Integrate: IntegrateADCData
port map(
    clk         =>  adcClk,
    aresetn     =>  aresetn,
    trig_i      =>  trigAvg,
    adcData_i   =>  adcAvg,
    valid_i     =>  validAvg,
    regs        =>  integrateRegs,
    data_o      =>  dataInt,
    valid_o     =>  validInt,
    dataSave_o  =>  intSave,
    validSave_o =>  intSaveValid
);

valid_o <= validInt;
data_o <= dataInt;

SaveAvgData: SaveADCData
port map(
    readClk     =>  sysClk,
    writeClk    =>  adcClk,
    aresetn     =>  aresetn,
    data_i      =>  adcAvg,
    valid_i     =>  validAvg,
    bus_m       =>  bus_m(0),
    bus_s       =>  bus_s(0)
);

SaveIntegratedData: SaveADCData
port map(
    readClk     =>  sysClk,
    writeClk    =>  adcClk,
    aresetn     =>  aresetn,
    data_i      =>  intSave,
    valid_i     =>  intSaveValid,
    bus_m       =>  bus_m(1),
    bus_s       =>  bus_s(1)
);

end Behavioral;
