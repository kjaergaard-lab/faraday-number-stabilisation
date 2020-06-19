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
end component;

--
-- AXI communication signals
--
signal comState     :   t_status            :=  idle;
signal bus_m        :   t_axi_bus_master    :=  INIT_AXI_BUS_MASTER;
signal bus_s        :   t_axi_bus_slave     :=  INIT_AXI_BUS_SLAVE;

--
-- Dispersive signals
--
signal triggers     :   t_param_reg :=  (others => '0');
signal pulseReg0, pulseReg1, avgReg0, integrateReg0 :   t_param_reg :=  (others => '0');
signal quadSignal   :   unsigned(23 downto 0);
signal quadValid    :   std_logic;
signal pulse, shutter   :   std_logic   :=  '0';

--
-- Block memory signals
--
signal mem_bus_m    :   t_mem_bus_master_array(1 downto 0)    :=  (others => INIT_MEM_BUS_MASTER);
signal mem_bus_s    :   t_mem_bus_slave_array(1 downto 0)     :=  (others => INIT_MEM_BUS_SLAVE);

begin

DispersiveProbe: DispersiveProbing
port map(
    sysClk          =>  sysClk,
    adcClk          =>  adcClk,
    aresetn         =>  aresetn,

    trig_i          =>  triggers(0),
    cntrl_i         =>  '0',
    adcData_i       =>  adcData_i,

    pulseReg0       =>  pulseReg0,
    pulseReg1       =>  pulseReg1,
    avgReg0         =>  avgReg0,
    integrateReg0   =>  integrateReg0,

    bus_m           =>  mem_bus_m,
    bus_s           =>  mem_bus_s,

    quad_o          =>  quadSignal,
    valid_o         =>  quadValid,
    pulse_o         =>  pulse,
    shutter_o       =>  shutter
);

ext_o(0) <= pulse;
ext_o(1) <= shutter;


--
-- AXI communication
--
bus_m.addr <= addr_i;
bus_m.valid <= dataValid_i;
bus_m.data <= writeData_i;
readData_o <= bus_s.data;
resp_o <= bus_s.resp;

Parse: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        comState <= idle;
        bus_s <= INIT_AXI_BUS_SLAVE;
        mem_bus_m <= (others => INIT_MEM_BUS_MASTER);
    elsif rising_edge(sysClk) then
        FSM: case(comState) is
            when idle =>
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
                                mem_bus_m(0).reset <= '1';
                                mem_bus_m(1).reset <= '1';
                                
                            when X"000004" => rw(bus_m,bus_s,comState,pulseReg0);
                            when X"000008" => rw(bus_m,bus_s,comState,pulseReg1);
                            when X"00000C" => rw(bus_m,bus_s,comState,avgReg0);
                            when X"000010" => readOnly(bus_m,bus_s,comState,mem_bus_s(0).last);
                            when X"000014" => rw(bus_m,bus_s,comState,integrateReg0);
                            
                            
                            when others => 
                                comState <= finishing;
                                bus_s.resp <= "11";
                        end case;            
                    --
                    -- Read raw/averaged data
                    -- 
                    -- When the address starts with X"01", then we read from or write to memory
                    --
                    when X"01" =>
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
                    when X"02" =>
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
                    
                    when others => null;
                end case;
            when finishing =>
                triggers <= (others => '0');
                mem_bus_m(0).reset <= '0';
                mem_bus_m(1).reset <= '0';
                comState <= idle;

            when others => comState <= idle;
        end case;
    end if;
end process;

    
end architecture Behavioural;