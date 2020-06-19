library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity SaveADCTest_tb is
--  Port ( );
end SaveADCTest_tb;

architecture Behavioral of SaveADCTest_tb is

component SaveADCData is
    port(
        sysClk      :   in  std_logic;
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        
        adcData_i   :   in  std_logic_vector(31 downto 0);
        valid_i     :   in  std_logic;
        
        bus_m       :   in  t_mem_bus_master;
        bus_s       :   out t_mem_bus_slave
        
    );
end component;

constant clkPeriod  :   time    :=  10 ns;

signal sysClk, adcClk, aresetn   :   std_logic  :=  '0';
signal adcData_i    :   std_logic_vector(31 downto 0)   :=  (others => '0');
signal valid_i  :   std_logic   :=  '0';

signal mem_bus    :   t_mem_bus   :=  INIT_MEM_BUS;

signal adcCount, count     :   natural :=  0;
signal adcPeriod            :   natural :=  4;
signal enable               :   std_logic   :=  '0';

begin

uut: SaveADCData
port map(
    sysClk  =>  sysClk,
    adcClk  =>  adcClk,
    aresetn =>  aresetn,
    adcData_i   =>  adcData_i,
    valid_i     =>  valid_i,
    bus_m       =>  mem_bus.m,
    bus_s       =>  mem_bus.s
);

-- Clock process definitions
clk_process :process
begin
	sysClk <= '0';
	adcClk <= '0';
	wait for clkPeriod/2;
	sysClk <= '1';
	adcClk <= '1';
	wait for clkPeriod/2;
end process;

--
-- ADC data process
--
ADCProc: process(adcClk,enable) is
begin
    if enable = '0' then
        adcCount <= 0;
        valid_i <= '0';
        count <= 0;
    elsif rising_edge(adcClk) then
        if adcCount = 0 then
            valid_i <= '1';
            count <= count + 1;
            adcData_i <= std_logic_vector(to_unsigned(count,adcData_i'length));
            adcCount <= adcCount + 1;
        elsif adcCount < adcPeriod-1 then
            valid_i <= '0';
            adcCount <= adcCount + 1;
        else
            adcCount <= 0;
            valid_i <= '0';
        end if;
    end if;
end process;

tb: process is
begin
    aresetn <= '0';
    enable <= '0';
    wait for 50 ns;
    aresetn <= '1';
    enable <= '1';
--    wait until sysClk'event and sysClk = '1';
    wait for 20*clkPeriod;
    enable <= '0';
    wait until sysClk'event and sysClk = '1';
    mem_bus.m.addr <= (others => '0');
    mem_bus.m.trig <= '1';
    wait until sysClk'event and sysClk = '1';
    mem_bus.m.trig <= '0';
    wait until mem_bus.s.valid'event and mem_bus.s.valid = '1';
    
    wait for 2*clkPeriod;
    wait until sysClk'event and sysClk = '1';
    mem_bus.m.addr <= mem_bus.m.addr + 1;
    mem_bus.m.trig <= '1';
    wait until sysClk'event and sysClk = '1';
    mem_bus.m.trig <= '0';
    wait until mem_bus.s.valid'event and mem_bus.s.valid = '1';
    
    wait for 2*clkPeriod;
    wait until sysClk'event and sysClk = '1';
    mem_bus.m.addr <= mem_bus.m.addr + 1;
    mem_bus.m.trig <= '1';
    wait until sysClk'event and sysClk = '1';
    mem_bus.m.trig <= '0';
    wait until mem_bus.s.valid'event and mem_bus.s.valid = '1';
    
    wait for 2*clkPeriod;
    wait until sysClk'event and sysClk = '1';
    mem_bus.m.addr <= mem_bus.m.addr + 1;
    mem_bus.m.trig <= '1';
    wait until sysClk'event and sysClk = '1';
    mem_bus.m.trig <= '0';
    wait until mem_bus.s.valid'event and mem_bus.s.valid = '1';
    
    wait;
end process;

end Behavioral;
