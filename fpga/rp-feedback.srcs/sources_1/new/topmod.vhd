library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;


entity topmod is
    port (
        sysClk          :   in  std_logic;
        aresetn         :   in  std_logic;
        ext_i           :   in  std_logic_vector(7 downto 0);

        addr_i          :   in  unsigned(AXI_ADDR_WIDTH-1 downto 0);            --Address out
        writeData_i     :   in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to write
        dataValid_i     :   in  std_logic_vector(1 downto 0);                   --Data valid out signal
        readData_o      :   out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to read
        resp_o          :   out std_logic_vector(1 downto 0);                   --Response in
        
        ext_o           :   out std_logic_vector(7 downto 0);
        
        adcClk          :   in  std_logic;
        adcData_i       :   in  std_logic_vector(31 downto 0)
    );
end topmod;


architecture Behavioural of topmod is

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
        multipliers :   in  t_param_reg_array(1 downto 0);          --Fixed gain multipliers, 32 bits each
        
        ratio_o     :   out signed(SIGNAL_WIDTH-1 downto 0);        --Output division signal
        valid_o     :   out std_logic                               --High for one cycle when ratio_o is valid
    );
end component;

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

component SaveADCData is
    generic(
        MEM_SIZE    :   natural                 --Options are 14, 13, and 12
    );
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
-- AXI communication signals
--
signal comState             :   t_status                        :=  idle;
signal bus_m                :   t_axi_bus_master                :=  INIT_AXI_BUS_MASTER;
signal bus_s                :   t_axi_bus_slave                 :=  INIT_AXI_BUS_SLAVE;

--
-- Shared registers
--
signal triggers             :   t_param_reg                     :=  (others => '0');
signal sharedReg            :   t_param_reg                     :=  (others => '0');

--
-- Acquisition registers
--
signal pulseRegs            :   t_param_reg_array(2 downto 0)   :=  (others => (others => '0'));
signal pulseRegsSignal      :   t_param_reg_array(2 downto 0)   :=  (others => (others => '0'));
signal pulseRegsAux         :   t_param_reg_array(2 downto 0)   :=  (others => (others => '0'));
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
signal cntrlSignal_i        :   t_control                       :=  INIT_CONTROL_ENABLED;
signal pulseSignal          :   std_logic;
signal shutterSignal        :   std_logic;
signal statusSignal         :   t_module_status                 :=  INIT_MODULE_STATUS;

signal pulseSignalMan       :   std_logic                       :=  '0';
signal shutterSignalMan     :   std_logic                       :=  '0';
signal signalDefaultState   :   std_logic                       :=  '1';

signal dataIntSignal        :   t_adc_integrated_array(1 downto 0)  :=  (others => (others => '0'));
signal validIntSignal       :   std_logic                       :=  '0';

--
-- Auxiliary acquisition signals
--
signal cntrlAux_i           :   t_control                       :=  INIT_CONTROL_ENABLED;
signal pulseAux             :   std_logic;
signal shutterAux           :   std_logic;
signal statusAux            :   t_module_status                 :=  INIT_MODULE_STATUS;

signal pulseAuxMan          :   std_logic                       :=  '0';
signal shutterAuxMan        :   std_logic                       :=  '0';
signal auxDefaultState      :   std_logic                       :=  '1';

signal dataIntAux           :   t_adc_integrated_array(1 downto 0)  :=  (others => (others => '0'));
signal validIntAux          :   std_logic                       :=  '0';

--
-- Gain computation signals
--
signal gainMultipliers      :   t_param_reg                     :=  (others => '0');
signal gain                 :   t_gain_array(1 downto 0)        :=  (others => (others => '0'));
signal gainValid            :   std_logic                       :=  '0';

--
-- Signal computation signals
--
signal useFixedGain         :   std_logic;
signal fixedGains           :   t_param_reg_array(1 downto 0)   :=  (others => (others => '0'));
signal ratio                :   signed(SIGNAL_WIDTH-1 downto 0) :=  (others => '0');
signal ratioValid           :   std_logic                       :=  '0';

--
-- Feedback signals
--
signal fbControl_i          :   t_control                       :=  INIT_CONTROL_ENABLED;
signal fbControl_o          :   t_control                       :=  INIT_CONTROL_ENABLED;
signal fbComputeRegs        :   t_param_reg_array(1 downto 0)   :=  (others => (others => '0'));
signal fbPulseRegs          :   t_param_reg_array(1 downto 0)   :=  (others => (others => '0'));
signal fbAuxReg             :   t_param_reg                     :=  (others => '0');

signal pulseMW              :   std_logic;
signal pulseMWMan           :   std_logic;

--
-- Block memory signals
--
signal mem_bus_m    :   t_mem_bus_master_array(4 downto 0)      :=  (others => INIT_MEM_BUS_MASTER);
signal mem_bus_s    :   t_mem_bus_slave_array(4 downto 0)       :=  (others => INIT_MEM_BUS_SLAVE);
signal reset        :   std_logic   :=  '0';
signal memIdx       :   natural range 0 to 255                  :=  0;

begin

--
-- Creates the component that acquires data for the main measurement (the "signal")
--
SignalAcquisition: DualChannelAcquisition
port map(
    sysClk          =>  sysClk,
    adcClk          =>  adcClk,
    aresetn         =>  aresetn,

    cntrl_i         =>  cntrlSignal_i,
    adcData_i       =>  adcData_i,

    pulseRegs       =>  pulseRegsSignal,
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

--
-- Creates the component that acquires data for the auxiliary measurement
-- that is used for determining the gain of the input channels
--
AuxiliaryAcquisition: DualChannelAcquisition
port map(
    sysClk          =>  sysClk,
    adcClk          =>  adcClk,
    aresetn         =>  aresetn,

    cntrl_i         =>  cntrlAux_i,
    adcData_i       =>  adcData_i,

    pulseRegs       =>  pulseRegsAux,
    avgReg          =>  avgReg,
    integrateRegs   =>  integrateRegs,

    bus_m           =>  mem_bus_m(3 downto 2),
    bus_s           =>  mem_bus_s(3 downto 2),

    data_o          =>  dataIntAux,
    valid_o         =>  validIntAux,

    pulse_o         =>  pulseAux,
    shutter_o       =>  shutterAux,
    status_o        =>  statusAux
);

--
-- Compute the gain values from the auxiliary measuremnts
--
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

--
-- Compute the ratio S_-/S_+
--
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

--
-- Creates the component that actually performs number stabilisation
--
StabiliseNumber: NumberStabilisation
port map(
    clk             =>  adcClk,
    aresetn         =>  aresetn,
    cntrl_i         =>  fbControl_i,

    computeRegs     =>  fbComputeRegs,
    pulseRegs_i     =>  fbPulseRegs,
    auxReg          =>  fbAuxReg,
    
    ratio_i         =>  ratio,
    valid_i         =>  ratioValid,
    
    cntrl_o         =>  fbControl_o,
    pulse_o         =>  pulseMW
    
);

--
-- Save ratio data
--
SaveRatioData: SaveADCData
generic map(
    MEM_SIZE    =>  13
)
port map(
    readClk     =>  sysClk,
    writeClk    =>  adcClk,
    aresetn     =>  aresetn,
    data_i      =>  std_logic_vector(ratio),
    valid_i     =>  ratioValid,
    bus_m       =>  mem_bus_m(4),
    bus_s       =>  mem_bus_s(4)
);


--
-- Routes signals to digital outputs
--
ext_o(0) <= pulseSignal or ((not statusSignal.running) and signalDefaultState) when manualFlag = '0' else pulseSignalMan;
ext_o(1) <= shutterSignal when manualFlag = '0' else shutterSignalMan;
ext_o(2) <= pulseMW when manualFlag = '0' else pulseMWMan;
ext_o(3) <= pulseSignal;
ext_o(4) <= pulseAux or ((not statusAux.running) and auxDefaultState) when manualFlag = '0' else pulseAuxMan;

--
-- AXI communication routing - connects bus objects to std_logic signals
--
bus_m.addr <= addr_i;
bus_m.valid <= dataValid_i;
bus_m.data <= writeData_i;
readData_o <= bus_s.data;
resp_o <= bus_s.resp;

--
-- Assigns appropriate values to pulse registers
--
pulseRegsSignal(1 downto 0) <= pulseRegs(1 downto 0);
pulseRegsAux(1 downto 0) <= pulseRegs(1 downto 0);

--
-- Shared registers
--
trig <= ext_i(0);
cntrlSignal_i.start <= triggers(0) or trig;
cntrlSignal_i.stop <= fbControl_o.stop;
cntrlAux_i.start <= triggers(0) or trig;
cntrlAux_i.stop <= fbControl_o.stop;
fbControl_i.start <= triggers(1) or trig;

cntrlSignal_i.enable <= sharedReg(0);
cntrlAux_i.enable <= sharedReg(0) and (not useFixedGain);
fbControl_i.enable <= sharedReg(1);
useFixedGain <= sharedReg(2);
fbAuxReg <= (0 => sharedReg(3), others => '0');
signalDefaultState <= sharedReg(4);
auxDefaultState <= sharedReg(5);

--
-- Manual signals
--
manualFlag <= sharedReg(31);
pulseSignalMan <= sharedReg(30);
shutterSignalMan <= sharedReg(29);
pulseMWMan <= sharedReg(28);
pulseAuxMan <= sharedReg(27);
shutterAuxMan <= sharedReg(26);

--
-- This sequence ensures that the memories are reset either on 
-- the receipt of a reset signal or when the pulses are started
--
mem_bus_m(0).reset <= reset or cntrlSignal_i.start;
mem_bus_m(1).reset <= reset or cntrlSignal_i.start;
mem_bus_m(2).reset <= reset or cntrlAux_i.start;
mem_bus_m(3).reset <= reset or cntrlAux_i.start;
mem_bus_m(4).reset <= reset or cntrlSignal_i.start;

--
-- Define useful signals for parsing AXI communications
--
memIdx <= to_integer(bus_m.addr(31 downto 24)) - 2;

Parse: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        comState <= idle;
        reset <= '0';
        bus_s <= INIT_AXI_BUS_SLAVE;
        triggers <= (others => '0');
        sharedReg <= (others => '0');
        --
        -- Reset some of the master memory bus signals
        --
        mem_bus_m(0).addr <= (others => '0');
        mem_bus_m(0).trig <= '0';
        mem_bus_m(0).status <= idle;
        mem_bus_m(1).addr <= (others => '0');
        mem_bus_m(1).trig <= '0';
        mem_bus_m(1).status <= idle;
        mem_bus_m(2).addr <= (others => '0');
        mem_bus_m(2).trig <= '0';
        mem_bus_m(2).status <= idle;
        mem_bus_m(3).addr <= (others => '0');
        mem_bus_m(3).trig <= '0';
        mem_bus_m(3).status <= idle;
        mem_bus_m(4).addr <= (others => '0');
        mem_bus_m(4).trig <= '0';
        mem_bus_m(4).status <= idle;
        
    elsif rising_edge(sysClk) then
        FSM: case(comState) is
            when idle =>
                triggers <= (others => '0');
                reset <= '0';
                bus_s.resp <= "00";
                if bus_m.valid(0) = '1' then
                    comState <= processing;
                end if;

            when processing =>
                AddrCase: case(bus_m.addr(31 downto 24)) is
                    --
                    -- Parameter parsing
                    --
                    when X"00" =>
                        ParamCase: case(bus_m.addr(23 downto 0)) is
                            --
                            -- This issues a reset signal to the memories and writes data to
                            -- the trigger registers
                            --
                            when X"000000" => 
                                rw(bus_m,bus_s,comState,triggers);
                                reset <= '1';
                                
                            when X"000004" => rw(bus_m,bus_s,comState,sharedReg);
                            when X"000008" => rw(bus_m,bus_s,comState,pulseRegs(0));
                            when X"00000C" => rw(bus_m,bus_s,comState,pulseRegs(1));
                            when X"000010" => rw(bus_m,bus_s,comState,pulseRegsSignal(2));
                            when X"000014" => rw(bus_m,bus_s,comState,pulseRegsAux(2));
                            when X"000018" => rw(bus_m,bus_s,comState,avgReg);
                            when X"00001C" => rw(bus_m,bus_s,comState,integrateRegs(0));
                            when X"000020" => rw(bus_m,bus_s,comState,integrateRegs(1));
                            when X"000024" => rw(bus_m,bus_s,comState,gainMultipliers);
                            when X"000028" => rw(bus_m,bus_s,comState,fixedGains(0));
                            when X"00002C" => rw(bus_m,bus_s,comState,fixedGains(1));
                            when X"000030" => rw(bus_m,bus_s,comState,fbComputeRegs(0));
                            when X"000034" => rw(bus_m,bus_s,comState,fbComputeRegs(1));
                            when X"000038" => rw(bus_m,bus_s,comState,fbPulseRegs(0));
                            when X"00003C" => rw(bus_m,bus_s,comState,fbPulseRegs(1));
                            
                            
                            when others => 
                                comState <= finishing;
                                bus_s.resp <= "11";
                        end case;
                    --
                    -- Read-only parameters
                    --
                    when X"01" =>
                        ParamCaseReadOnly: case(bus_m.addr(23 downto 0)) is
                            when X"000000" => readOnly(bus_m,bus_s,comState,mem_bus_s(0).last);
                            when X"000004" => readOnly(bus_m,bus_s,comState,mem_bus_s(1).last);
                            when X"000008" => readOnly(bus_m,bus_s,comState,mem_bus_s(2).last);
                            when X"00000C" => readOnly(bus_m,bus_s,comState,mem_bus_s(3).last);
                            when X"000010" => readOnly(bus_m,bus_s,comState,mem_bus_s(4).last);
                            when others => 
                                comState <= finishing;
                                bus_s.resp <= "11";
                        end case;
                    --
                    -- Read data
                    -- X"02" => Raw data for signal acquisition
                    -- X"03" => Integrated data for signal acquisition
                    -- X"04" => Raw data for auxiliary acquisition
                    -- X"05" => Integrated data for signal acquisition
                    -- 
                    when X"02" | X"03" | X"04" | X"05" | X"06" =>
                        if bus_m.valid(1) = '0' then
                            bus_s.resp <= "11";
                            comState <= finishing;
                            mem_bus_m(memIdx).trig <= '0';
                            mem_bus_m(memIdx).status <= idle;
                        elsif mem_bus_s(memIdx).valid = '1' then
                            bus_s.data <= mem_bus_s(memIdx).data;
                            comState <= finishing;
                            bus_s.resp <= "01";
                            mem_bus_m(memIdx).status <= idle;
                            mem_bus_m(memIdx).trig <= '0';
                        elsif mem_bus_m(memIdx).status = idle then
                            mem_bus_m(memIdx).addr <= bus_m.addr(MEM_ADDR_WIDTH+1 downto 2);
                            mem_bus_m(memIdx).status <= waiting;
                            mem_bus_m(memIdx).trig <= '1';
                         else
                            mem_bus_m(memIdx).trig <= '0';
                        end if;
                    
                    when others => 
                        comState <= finishing;
                        bus_s.resp <= "11";
                end case;
            when finishing =>
                triggers <= (others => '0');
                reset <= '0';
                comState <= idle;

            when others => comState <= idle;
        end case;
    end if;
end process;

    
end architecture Behavioural;