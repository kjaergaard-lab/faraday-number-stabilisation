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

component UART_Transmitter is
	generic(BAUD_PERIOD	:	natural;									--Baud period
	        NUM_BITS    :   natural);
	
	port(	clk 		: 	in 	std_logic;								--Clock signal
			dataIn		:	in	std_logic_vector(NUM_BITS-1 downto 0);	--32-bit word to be sent
			trigIn		:	in	std_logic;								--Trigger to send data
			TxD			:	out	std_logic;								--Serial transmit port
			baudTickOut	:	out	std_logic;								--Output for baud ticks for testing
			busy		:	out	std_logic);								--Busy signal is high when transmitting
end component;

component PowerMeasurement is
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
constant BAUD_PERIOD:   natural             :=  12;
constant SERIAL_BITS:   natural             :=  24;
signal uart_i       :   std_logic_vector(SERIAL_BITS-1 downto 0)    :=  (others => '0');
signal TxD          :   std_logic           :=  '0';


--
-- Shared registers
--
signal triggers         :   t_param_reg :=  (others => '0');
signal sharedReg0       :   t_param_reg :=  (others => '0');

--
-- Dispersive signals
--
signal powerCntrl :   t_control   :=  INIT_CONTROL_ENABLED;
signal avgReg0, integrateReg0 :   t_param_reg :=  (others => '0');
signal power                :   std_logic_vector(23 downto 0);
signal powerValid           :   std_logic;

--
-- Block memory signals
--
signal mem_bus_m    :   t_mem_bus_master_array(1 downto 0)    :=  (others => INIT_MEM_BUS_MASTER);
signal mem_bus_s    :   t_mem_bus_slave_array(1 downto 0)     :=  (others => INIT_MEM_BUS_SLAVE);
signal reset        :   std_logic   := '0';
signal autoReset        :   std_logic   :=  '0';
signal autoResetCount   :   unsigned(31 downto 0)   :=  (others => '0');
constant AUTO_RESET_TIMER   :   unsigned(autoResetCount'length-1 downto 0)  :=  to_unsigned(1250000000,autoResetCount'length);
signal trigSync :   std_logic_vector(1 downto 0)    :=  "00";

begin

powerCntrl.start <= ext_i(2);

TriggerSyncProc: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        trigSync <= "00";
    elsif rising_edge(sysClk) then
        trigSync <= trigSync(0) & powerCntrl.start;
    end if;
end process;

MeasPower: PowerMeasurement
port map(
    sysClk          =>  sysClk,
    adcClk          =>  adcClk,
    aresetn         =>  aresetn,

    cntrl_i         =>  powerCntrl,
    adcData_i       =>  adcData_i,

    avgReg0         =>  avgReg0,
    integrateReg0   =>  integrateReg0,

    bus_m           =>  mem_bus_m,
    bus_s           =>  mem_bus_s,

    power_o         =>  power,
    valid_o         =>  powerValid
);

--
-- AXI communication
--
bus_m.addr <= addr_i;
bus_m.valid <= dataValid_i;
bus_m.data <= writeData_i;
readData_o <= bus_s.data;
resp_o <= bus_s.resp;

--
-- UART transmission
--
Transmit: UART_Transmitter
generic map(
    BAUD_PERIOD =>  BAUD_PERIOD,
    NUM_BITS    =>  SERIAL_BITS)
port map(
    clk         =>  adcClk,
    dataIn      =>  power,
    trigIn      =>  powerValid,
    TxD         =>  TxD,
    baudTickOut =>  open,
    busy        =>  open
);

ext_o(2) <= TxD;

AutoResetProc: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        autoReset <= '0';
        autoResetCount <= (others => '0');
    elsif rising_edge(sysClk) then
        if powerCntrl.start = '1' then
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
-- Shared registers
--
mem_bus_m(0).reset <= reset or autoReset;
mem_bus_m(1).reset <= reset or autoReset;

Parse: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        comState <= idle;
        bus_s <= INIT_AXI_BUS_SLAVE;
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
                            when X"000008" => rw(bus_m,bus_s,comState,avgReg0);
                            when X"00000C" => rw(bus_m,bus_s,comState,integrateReg0);

                            
                            when others => 
                                comState <= finishing;
                                bus_s.resp <= "11";
                        end case;  
                    --
                    -- Read-only properties
                    --
                    when X"01" =>
                        ReadOnlyCase: case(bus_m.addr(23 downto 0)) is
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