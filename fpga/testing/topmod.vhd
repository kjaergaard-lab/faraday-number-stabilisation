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

component DispersiveProbing is
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
end component;

component NumberStabilisation is
    port(
        sysClk          :   in  std_logic;
        adcClk          :   in  std_logic;
        aresetn         :   in  std_logic;
        cntrl_i         :   in  t_control;

        cntrlReg        :   in  t_param_reg;
        computeRegs     :   in  t_param_reg_array(3 downto 0);
        pulseRegs       :   in  t_param_reg_array(1 downto 0);
        
        quad_i          :   in  unsigned(QUAD_WIDTH-1 downto 0);
        valid_i         :   in  std_logic;
        
        cntrl_o         :   out t_control;
        pulse_o         :   out std_logic
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
signal triggers     :   t_param_reg :=  (others => '0');
signal sharedReg    :   t_param_reg :=  (others => '0');

--
-- Dispersive signals
--
signal trig                 :   std_logic   :=  '0';
signal dpCntrlReg           :   t_param_reg                     :=  (others => '0');
signal pulseRegs            :   t_param_reg_array(3 downto 0)   :=  (others => (others => '0'));
signal procRegs             :   t_param_reg_array(1 downto 0)   :=  (others => (others => '0'));

signal ratioSignal          :   unsigned(QUAD_WIDTH-1 downto 0);
signal ratioValid           :   std_logic;
signal pulseDP, shutterDP   :   std_logic   :=  '0';
signal pulseEOM, pulseEOMMan:   std_logic   :=  '0';
signal pulseDPMan, shutterDPMan   :   std_logic   :=  '0';
signal dpControl_i          :   t_control   :=  INIT_CONTROL_ENABLED;
signal manualFlag           :   std_logic   :=  '0';
signal dpStatus             :   t_module_status :=  INIT_MODULE_STATUS;

--
-- Feedback signals
--
signal fbControl_i, fbControl_o     :   t_control   :=  INIT_CONTROL_ENABLED;
signal fbCntrlReg           :   t_param_reg :=  (others => '0');
signal computeRegs          :   t_param_reg_array(3 downto 0)   :=  (others => (others => '0'));
signal mwPulseRegs          :   t_param_reg_array(1 downto 0)   :=  (others => (others => '0'));
signal pulseMW, pulseMWMan                      :   std_logic;

--
-- Block memory signals
--
signal mem_bus_m    :   t_mem_bus_master_array(1 downto 0)    :=  (others => INIT_MEM_BUS_MASTER);
signal mem_bus_s    :   t_mem_bus_slave_array(1 downto 0)     :=  (others => INIT_MEM_BUS_SLAVE);
signal reset        :   std_logic   :=  '0';

begin

DispersiveProbe: DispersiveProbing
port map(
    sysClk          =>  sysClk,
    adcClk          =>  adcClk,
    aresetn         =>  aresetn,

    cntrl_i         =>  dpControl_i,
    adcData_i       =>  adcData_i,
    
    cntrlReg        =>  dpCntrlReg,
    pulseRegs       =>  pulseRegs,
    procRegs        =>  procRegs,

    bus_m           =>  mem_bus_m,
    bus_s           =>  mem_bus_s,

    amp_o           =>  ratioSignal,
    valid_o         =>  ratioValid,

    pulse_o         =>  pulseDP,
    aux_o           =>  pulseEOM,
    shutter_o       =>  shutterDP,
    status_o        =>  dpStatus
);

StabiliseNumber: NumberStabilisation
port map(
    sysClk          =>  sysClk,
    adcClk          =>  adcClk,
    aresetn         =>  aresetn,
    cntrl_i         =>  fbControl_i,
    
    cntrlReg        =>  fbCntrlReg,
    computeRegs     =>  computeRegs,
    pulseRegs       =>  mwPulseRegs,
    
    quad_i          =>  ratioSignal,
    valid_i         =>  ratioValid,
    
    cntrl_o         =>  fbControl_o,
    pulse_o         =>  pulseMW
    
);

ext_o(0) <= pulseDP or not dpStatus.running when manualFlag = '0' else pulseDPMan;
ext_o(1) <= shutterDP when manualFlag = '0' else shutterDPMan;
ext_o(2) <= pulseMW when manualFlag = '0' else pulseMWMan;
ext_o(3) <= pulseDP;
ext_o(4) <= pulseEOM when manualFlag = '0' else pulseEOMMan;



--
-- AXI communication
--
bus_m.addr <= addr_i;
bus_m.valid <= dataValid_i;
bus_m.data <= writeData_i;
readData_o <= bus_s.data;
resp_o <= bus_s.resp;

--
-- Shared registers
--
trig <= ext_i(0);
dpControl_i.start <= triggers(0) or trig;
dpControl_i.stop <= fbControl_o.stop;
fbControl_i.start <= triggers(1) or trig;

dpControl_i.enable <= sharedReg(0);
fbControl_i.enable <= sharedReg(1);
dpCntrlReg <= (0 => sharedReg(2), others => '0');
fbCntrlReg <= (0 => sharedReg(3), others => '0');

manualFlag <= sharedReg(31);
pulseDPMan <= sharedReg(30);
shutterDPMan <= sharedReg(29);
pulseMWMan <= sharedReg(28);
pulseEOMMan <= sharedReg(27);

mem_bus_m(0).reset <= reset or dpControl_i.start;
mem_bus_m(1).reset <= reset or dpControl_i.start;

Parse: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        comState <= idle;
        reset <= '0';
        bus_s <= INIT_AXI_BUS_SLAVE;
        mem_bus_m(0).addr <= (others => '0');
        mem_bus_m(0).trig <= '0';
        mem_bus_m(0).status <= idle;
        mem_bus_m(1).addr <= (others => '0');
        mem_bus_m(1).trig <= '0';
        mem_bus_m(1).status <= idle;
        triggers <= (others => '0');
        sharedReg <= (others => '0');
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
                            when X"000000" => 
                                rw(bus_m,bus_s,comState,triggers);
                                reset <= '1';
                                
                            when X"000004" => rw(bus_m,bus_s,comState,sharedReg);
                            when X"000008" => rw(bus_m,bus_s,comState,pulseRegs(0));
                            when X"00000C" => rw(bus_m,bus_s,comState,pulseRegs(1));
                            when X"000010" => rw(bus_m,bus_s,comState,pulseRegs(2));
                            when X"000014" => rw(bus_m,bus_s,comState,pulseRegs(3));
                            when X"000018" => rw(bus_m,bus_s,comState,procRegs(0));
                            when X"00001C" => rw(bus_m,bus_s,comState,procRegs(1));
                            when X"000020" => rw(bus_m,bus_s,comState,computeRegs(0));
                            when X"000024" => rw(bus_m,bus_s,comState,computeRegs(1));
                            when X"000028" => rw(bus_m,bus_s,comState,computeRegs(2));
                            when X"00002C" => rw(bus_m,bus_s,comState,computeRegs(3));
                            when X"000030" => rw(bus_m,bus_s,comState,mwPulseRegs(0));
                            when X"000034" => rw(bus_m,bus_s,comState,mwPulseRegs(1));
                            
                            
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
                            when others => 
                                comState <= finishing;
                                bus_s.resp <= "11";
                        end case;
                    --
                    -- Read raw/averaged data
                    -- 
                    -- When the address starts with X"01", then we read from or write to memory
                    --
                    when X"02" =>
                        if bus_m.valid(1) = '0' then
                            bus_s.resp <= "11";
                            comState <= finishing;
                            mem_bus_m(0).trig <= '0';
                            mem_bus_m(0).status <= idle;
                        elsif mem_bus_s(0).valid = '1' then
                            bus_s.data <= mem_bus_s(0).data;
                            comState <= finishing;
                            bus_s.resp <= "01";
                            mem_bus_m(0).status <= idle;
                            mem_bus_m(0).trig <= '0';
                        elsif mem_bus_m(0).status = idle then
                            mem_bus_m(0).addr <= bus_m.addr(MEM_ADDR_WIDTH+1 downto 2);
                            mem_bus_m(0).status <= waiting;
                            mem_bus_m(0).trig <= '1';
                         else
                            mem_bus_m(0).trig <= '0';
                        end if;
                    --
                    -- Read processed data
                    -- 
                    -- When the address starts with X"02", then we read from or write to memory
                    --
                    when X"03" =>
                        if bus_m.valid(1) = '0' then
                            bus_s.resp <= "11";
                            comState <= finishing;
                            mem_bus_m(1).trig <= '0';
                            mem_bus_m(1).status <= idle;
                        elsif mem_bus_s(1).valid = '1' then
                            bus_s.data <= mem_bus_s(1).data;
                            comState <= finishing;
                            bus_s.resp <= "01";
                            mem_bus_m(1).status <= idle;
                            mem_bus_m(1).trig <= '0';
                        elsif mem_bus_m(1).status = idle then
                            mem_bus_m(1).addr <= bus_m.addr(MEM_ADDR_WIDTH+1 downto 2);
                            mem_bus_m(1).status <= waiting;
                            mem_bus_m(1).trig <= '1';
                         else
                            mem_bus_m(1).trig <= '0';
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