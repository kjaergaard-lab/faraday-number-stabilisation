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
        
        pulseReg0       :   in  t_param_reg;
        pulseReg1       :   in  t_param_reg;
        pulseReg2       :   in  t_param_reg;
        pulseReg3       :   in  t_param_reg;
        pulseReg4       :   in  t_param_reg;
        avgReg0         :   in  t_param_reg;
        integrateReg0   :   in  t_param_reg;
        auxReg0         :   in  t_param_reg;

        bus_m           :   in  t_mem_bus_master_array(1 downto 0);
        bus_s           :   out t_mem_bus_slave_array(1 downto 0);

        quad_o          :   out unsigned(QUAD_WIDTH-1 downto 0);
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
    generic(
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

component ComputeSignal is
    port(
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        
        dataI_i     :   in  signed(23 downto 0);
        dataQ_i     :   in  signed(23 downto 0);
        valid_i     :   in  std_logic;
        normalise_i :   in  std_logic;
        
        quad_o      :   out unsigned(QUAD_WIDTH-1 downto 0);
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


signal pulse, pulseEOM       :   std_logic   :=  '0';
signal pulseStatus  :   t_module_status :=  INIT_MODULE_STATUS;
signal adcAvg   :   t_adc_combined  :=  (others => '0');
signal validAvg, trigAvg :   std_logic;

signal dataI, dataQ :   signed(23 downto 0) :=  (others => '0');
signal validIntegrate   :   std_logic   :=  '0';
signal intSave      :   t_mem_data;
signal intSaveValid :   std_logic;

signal quadSignal   :   unsigned(QUAD_WIDTH-1 downto 0);
signal validQuad    :   std_logic   :=  '0';

signal usePow       :   std_logic   :=  '1';

signal statusCount :   unsigned(23 downto 0)    :=  (others => '0');
constant SHUTTER_HOLDOFF    :   unsigned(23 downto 0)   :=  to_unsigned(625000,24);

type t_status_local is (idle, counting);
signal state    :   t_status_local  :=  idle;

signal pulseRegEOM  :   t_param_reg;

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
    clk     =>  sysClk,
    aresetn =>  aresetn,
    cntrl_i =>  cntrl_i,
    reg0    =>  pulseReg0,
    reg1    =>  pulseReg1,
    reg2    =>  pulseReg2,
    pulse_o =>  pulse,
    status_o=>  pulseStatus
);

pulseRegEOM <= pulseReg0(31 downto 16) & pulseReg4(15 downto 0);
EOMPulses: PulseGen
port map(
    clk     =>  sysClk,
    aresetn =>  aresetn,
    cntrl_i =>  cntrl_i,
    reg0    =>  pulseRegEOM,
    reg1    =>  pulseReg1,
    reg2    =>  pulseReg3,
    pulse_o =>  pulseEOM,
    status_o=>  open
);
pulse_o <= pulse;
aux_o <= pulseEOM;
shutter_o <= pulseStatus.running;

InitAvg: QuickAvg
port map(
    clk         =>  adcClk,
    aresetn     =>  aresetn,
    trig_i      =>  pulse,
    reg0        =>  avgReg0,
    adcData_i   =>  adcData_i,
    adcData_o   =>  adcAvg,
    trig_o      =>  trigAvg,
    valid_o     =>  validAvg
);

Integrate: IntegrateADCData
generic map(
    EXT_WIDTH   =>  24
)
port map(
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    trig_i      =>  trigAvg,
    adcData_i   =>  adcAvg,
    valid_i     =>  validAvg,
    reg0        =>  integrateReg0,
    dataI_o     =>  dataI,
    dataQ_o     =>  dataQ,
    valid_o     =>  validIntegrate,
    dataSave_o  =>  intSave,
    validSave_o =>  intSaveValid
);

usePow <= auxReg0(0);

Compute: ComputeSignal
port map(
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    dataI_i     =>  dataI,
    dataQ_i     =>  dataQ,
    valid_i     =>  validIntegrate,
    normalise_i =>  usePow,
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
    data_i      =>  intSave,
    valid_i     =>  intSaveValid,
    bus_m       =>  bus_m(1),
    bus_s       =>  bus_s(1)
);

end Behavioral;
