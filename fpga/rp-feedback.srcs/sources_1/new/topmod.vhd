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

component UART_Receiver is
	generic(BAUD_PERIOD    : natural;								--Baud period in clock cycles
	        NUM_BITS       : natural);
	port(	clk 		   : in  std_logic;							--Clock signal
	        aresetn        : in  std_logic;
            data_o         : out std_logic_vector(NUM_BITS-1 downto 0);	--Output data
			valid_o	       : out std_logic;							--Signal to register the complete read of a byte
			RxD			   : in	 std_logic);							--Output baud tick, used for debugging
end component;

component DispersiveProbing is
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
end component;

component NumberStabilisation is
    port(
        sysClk          :   in  std_logic;
        adcClk          :   in  std_logic;
        aresetn         :   in  std_logic;
        cntrl_i         :   in  t_control;
        
        computeReg0     :   in  t_param_reg;
        computeReg1     :   in  t_param_reg;
        computeReg2     :   in  t_param_reg;
        computeReg3     :   in  t_param_reg;
        
        pulseReg0       :   in  t_param_reg;
        pulseReg1       :   in  t_param_reg;
        
        auxReg0         :   in  t_param_reg;
        
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
-- UART signals
--
constant BAUD_PERIOD    :   natural         :=  12;
constant UART_NUM_BITS  :   natural         :=  24;
signal uartData         :   std_logic_vector(UART_NUM_BITS-1 downto 0)   :=  (others => '0');
signal uartValid        :   std_logic       :=  '0';

--
-- Shared registers
--
signal triggers     :   t_param_reg :=  (others => '0');
signal sharedReg0   :   t_param_reg :=  (others => '0');

--
-- Dispersive signals
--
signal trig                 :   std_logic   :=  '0';
signal pulseReg0, pulseReg1, pulseReg2, pulseReg3, pulseReg4, avgReg0, integrateReg0, auxReg0 :   t_param_reg :=  (others => '0');
signal quadSignal           :   unsigned(QUAD_WIDTH-1 downto 0);
signal quadValid            :   std_logic;
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
signal fbComputeReg0, fbComputeReg1, fbComputeReg2, fbComputeReg3   :   t_param_reg :=  (others => '0');
signal fbPulseReg0, fbPulseReg1     :   t_param_reg :=  (others => '0');
signal fbAuxReg0                    :   t_param_reg :=  (others => '0');
signal pulseMW, pulseMWMan                      :   std_logic;

--
-- Block memory signals
--
signal mem_bus_m    :   t_mem_bus_master_array(1 downto 0)    :=  (others => INIT_MEM_BUS_MASTER);
signal mem_bus_s    :   t_mem_bus_slave_array(1 downto 0)     :=  (others => INIT_MEM_BUS_SLAVE);
signal reset        :   std_logic   :=  '0';

begin

--PowerReceiver: UART_Receiver
--generic map(
--    BAUD_PERIOD =>  BAUD_PERIOD,
--    NUM_BITS    =>  UART_NUM_BITS)
--port map(
--    clk         =>  adcClk,
--    aresetn     =>  aresetn,
--    data_o      =>  uartData,
--    valid_o     =>  uartValid,
--    RxD         =>  ext_i(1)
--);

DispersiveProbe: DispersiveProbing
port map(
    sysClk          =>  sysClk,
    adcClk          =>  adcClk,
    aresetn         =>  aresetn,

    cntrl_i         =>  dpControl_i,
    adcData_i       =>  adcData_i,

    pulseReg0       =>  pulseReg0,
    pulseReg1       =>  pulseReg1,
    pulseReg2       =>  pulseReg2,
    pulseReg3       =>  pulseReg3,
    pulseReg4       =>  pulseReg4,
    avgReg0         =>  avgReg0,
    integrateReg0   =>  integrateReg0,
    auxReg0         =>  auxReg0,

    bus_m           =>  mem_bus_m,
    bus_s           =>  mem_bus_s,

    quad_o          =>  quadSignal,
    valid_o         =>  quadValid,
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
    
    computeReg0     =>  fbComputeReg0,
    computeReg1     =>  fbComputeReg1,
    computeReg2     =>  fbComputeReg2,
    computeReg3     =>  fbComputeReg3,
    
    pulseReg0       =>  fbPulseReg0,
    pulseReg1       =>  fbPulseReg1,
    
    auxReg0         =>  fbAuxReg0,
    
    quad_i          =>  quadSignal,
    valid_i         =>  quadValid,
    
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

dpControl_i.enable <= sharedReg0(0);
fbControl_i.enable <= sharedReg0(1);
auxReg0 <= (0 => sharedReg0(2), others => '0');
fbAuxReg0 <= (0 => sharedReg0(3), others => '0');

manualFlag <= sharedReg0(31);
pulseDPMan <= sharedReg0(30);
shutterDPMan <= sharedReg0(29);
pulseMWMan <= sharedReg0(28);
pulseEOMMan <= sharedReg0(27);

mem_bus_m(0).reset <= reset or dpControl_i.start;
mem_bus_m(1).reset <= reset or dpControl_i.start;

Parse: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        comState <= idle;
        reset <= '0';
        bus_s <= INIT_AXI_BUS_SLAVE;
--        mem_bus_m <= (others => INIT_MEM_BUS_MASTER);
        mem_bus_m(0).addr <= (others => '0');
        mem_bus_m(0).trig <= '0';
        mem_bus_m(0).status <= idle;
        mem_bus_m(1).addr <= (others => '0');
        mem_bus_m(1).trig <= '0';
        mem_bus_m(1).status <= idle;
        triggers <= (others => '0');
        sharedReg0 <= (others => '0');
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
                                
                            when X"000004" => rw(bus_m,bus_s,comState,sharedReg0);
                            when X"000008" => rw(bus_m,bus_s,comState,pulseReg0);
                            when X"00000C" => rw(bus_m,bus_s,comState,pulseReg1);
                            when X"000010" => rw(bus_m,bus_s,comState,pulseReg2);
                            when X"000014" => rw(bus_m,bus_s,comState,pulseReg3);
                            when X"000018" => rw(bus_m,bus_s,comState,pulseReg4);
                            when X"00001C" => rw(bus_m,bus_s,comState,avgReg0);
                            when X"000020" => rw(bus_m,bus_s,comState,integrateReg0);
                            when X"000024" => rw(bus_m,bus_s,comState,fbComputeReg0);
                            when X"000028" => rw(bus_m,bus_s,comState,fbComputeReg1);
                            when X"00002C" => rw(bus_m,bus_s,comState,fbComputeReg2);
                            when X"000030" => rw(bus_m,bus_s,comState,fbComputeReg3);
                            when X"000034" => rw(bus_m,bus_s,comState,fbPulseReg0);
                            when X"000038" => rw(bus_m,bus_s,comState,fbPulseReg1);
                            
                            
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