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
    generic(
        USE_EXT_PULSE   :   boolean
    );
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


--
-- AXI communication signals
--
signal comState     :   t_status            :=  idle;
signal bus_m        :   t_axi_bus_master    :=  INIT_AXI_BUS_MASTER;
signal bus_s        :   t_axi_bus_slave     :=  INIT_AXI_BUS_SLAVE;

--
-- Shared registers
--
signal triggers         :   t_param_reg :=  (others => '0');
signal sharedReg        :   t_param_reg :=  (others => '0');

--
-- Acquisition registers
--
signal pulseRegs        :   t_param_reg_array(2 downto 0)   :=  (others => (others => '0'));
signal avgRegs          :   t_param_reg_array(1 downto 0)   :=  (others => (others => '0'));
signal avgRegSignal     :   t_param_reg                     :=  (others => '0');
signal avgRegAux        :   t_param_reg                     :=  (others => '0');
signal integrateRegs    :   t_param_reg_array(1 downto 0)   :=  (others => (others => '0'));

--
-- Power acquisition signals
--
signal signalCntrl       :   t_control                               :=  INIT_CONTROL_ENABLED;
signal auxCntrl          :   t_control                               :=  INIT_CONTROL_ENABLED;


--
-- Block memory signals
--
signal mem_bus_m            :   t_mem_bus_master_array(3 downto 0)      :=  (others => INIT_MEM_BUS_MASTER);
signal mem_bus_s            :   t_mem_bus_slave_array(3 downto 0)       :=  (others => INIT_MEM_BUS_SLAVE);
signal reset                :   std_logic                               :=  '0';
signal memIdx               :   natural range 0 to 255                  :=  0;

signal autoReset            :   std_logic                               :=  '0';
signal autoResetCount       :   unsigned(31 downto 0)                   :=  (others => '0');
constant AUTO_RESET_TIMER   :   unsigned(autoResetCount'length-1 downto 0)  :=  to_unsigned(1250000000,autoResetCount'length);
signal trigSync             :   std_logic_vector(1 downto 0)            :=  "00";

begin

signalCntrl.start <= ext_i(2);
auxCntrl.start <= ext_i(3);

--TriggerSyncProc: process(sysClk,aresetn) is
--begin
--    if aresetn = '0' then
--        trigSync <= "00";
--    elsif rising_edge(sysClk) then
--        trigSync <= trigSync(0) & signalCntrl.start;
--    end if;
--end process;

--
-- Creates the component that acquires data for the power measurement ("signal")
--
SignalAcquisition: DualChannelAcquisition
generic map(
    USE_EXT_PULSE   =>  true
)
port map(
    sysClk          =>  sysClk,
    adcClk          =>  adcClk,
    aresetn         =>  aresetn,

    cntrl_i         =>  signalCntrl,
    adcData_i       =>  adcData_i,

    pulseRegs       =>  pulseRegs,
    avgReg          =>  avgRegSignal,
    integrateRegs   =>  integrateRegs,

    bus_m           =>  mem_bus_m(1 downto 0),
    bus_s           =>  mem_bus_s(1 downto 0),

    data_o          =>  open,
    valid_o         =>  open,

    pulse_o         =>  open,
    shutter_o       =>  open,
    status_o        =>  open
);

--
-- Creates the component that acquires data for the power measurement ("aux")
--
AuxiliaryAcquisition: DualChannelAcquisition
generic map(
    USE_EXT_PULSE   =>  true
)
port map(
    sysClk          =>  sysClk,
    adcClk          =>  adcClk,
    aresetn         =>  aresetn,

    cntrl_i         =>  auxCntrl,
    adcData_i       =>  adcData_i,

    pulseRegs       =>  pulseRegs,
    avgReg          =>  avgRegAux,
    integrateRegs   =>  integrateRegs,

    bus_m           =>  mem_bus_m(3 downto 2),
    bus_s           =>  mem_bus_s(3 downto 2),

    data_o          =>  open,
    valid_o         =>  open,

    pulse_o         =>  open,
    shutter_o       =>  open,
    status_o        =>  open
);

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
avgRegSignal <= avgRegs(0);
avgRegAux <= avgRegs(0)(avgRegAux'length-1 downto 14) & avgRegs(1)(13 downto 0);



AutoResetProc: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        autoReset <= '0';
        autoResetCount <= (others => '0');
    elsif rising_edge(sysClk) then
        if signalCntrl.start = '1' or auxCntrl.start = '1' then
            autoResetCount <= (others => '0');
            autoReset <= '0';
        elsif autoResetCount < AUTO_RESET_TIMER then
            autoResetCount <= autoResetCount + 1;
            autoReset <= '0';
        elsif autoResetCount = AUTO_RESET_TIMER then
            autoResetCount <= autoResetCount + 1;
            autoReset <= '1';
        else
            autoReset <= '0';
        end if;
    end if;
end process;

--
-- This sequence ensures that the memories are reset either on 
-- the receipt of a reset signal or when the pulses are started
--
mem_bus_m(0).reset <= reset or autoReset;
mem_bus_m(1).reset <= reset or autoReset;
mem_bus_m(2).reset <= reset or autoReset;
mem_bus_m(3).reset <= reset or autoReset;

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
                            -- when X"000008" => rw(bus_m,bus_s,comState,pulseRegs(0));
                            -- when X"00000C" => rw(bus_m,bus_s,comState,pulseRegs(1));


                            when X"000018" => rw(bus_m,bus_s,comState,avgRegs(0));
                            when X"00001C" => rw(bus_m,bus_s,comState,avgRegs(1));
                            when X"000020" => rw(bus_m,bus_s,comState,integrateRegs(0));
                            when X"000024" => rw(bus_m,bus_s,comState,integrateRegs(1));
                            
                            
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
                            when others => 
                                comState <= finishing;
                                bus_s.resp <= "11";
                        end case;
                    --
                    -- Read data
                    -- X"02" => Raw data for signal acquisition
                    -- X"03" => Integrated data for signal acquisition
                    -- X"04" => Raw data for aux acquisition
                    -- X"05" => Integrated data for aux acquisition
                    -- 
                    when X"02" | X"03" | X"04" | X"05" =>
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