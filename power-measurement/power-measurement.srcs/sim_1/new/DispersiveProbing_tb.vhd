library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity DispersiveProbing_tb is
--  Port ( );
end DispersiveProbing_tb;

architecture Behavioral of DispersiveProbing_tb is

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

constant clkPeriod  :   time    :=  10 ns;

signal sysClk, adcClk, aresetn  :   std_logic  :=  '0';
signal adcData_i                :   std_logic_vector(31 downto 0)   :=  (others => '0');
signal trig_i                   :   std_logic   :=  '0';

signal mem_bus_masters          :   t_mem_bus_master_array(1 downto 0)  :=  (others => INIT_MEM_BUS_MASTER);
signal mem_bus_slaves           :   t_mem_bus_slave_array(1 downto 0)   :=  (others => INIT_MEM_BUS_SLAVE);

signal pulseReg0, pulseReg1, avgReg0, integrateReg0 :   t_param_reg :=  (others => '0');
signal quadSignal       :   unsigned(23 downto 0);
signal quadValid        :   std_logic;
signal pulse, shutter   :   std_logic   :=  '0';

begin

uut: DispersiveProbing
port map(
    sysClk      =>  sysClk,
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    
    trig_i      =>  trig_i,
    cntrl_i     =>  '0',
    
    adcData_i       =>  adcData_i,

    pulseReg0       =>  pulseReg0,
    pulseReg1       =>  pulseReg1,
    avgReg0         =>  avgReg0,
    integrateReg0   =>  integrateReg0,

    bus_m           =>  mem_bus_masters,
    bus_s           =>  mem_bus_slaves,

    quad_o          =>  quadSignal,
    valid_o         =>  quadValid,
    pulse_o         =>  pulse,
    shutter_o       =>  shutter
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

adcData_i <= (others => '0');
tb: process is
begin
    aresetn <= '0';
    pulseReg0 <= X"000a" & X"000a";
    pulseReg1 <= X"00000014";
    avgReg0 <= X"0" & std_logic_vector(to_unsigned(10,14)) & std_logic_vector(to_unsigned(0,14));
    integrateReg0 <= X"00" & X"05" & X"10" & X"01";
    trig_i <= '0'; 
    wait for 50 ns;
    aresetn <= '1';

    wait until sysClk'event and sysClk = '1';
    trig_i <= '1';
    wait until sysClk'event and sysClk = '1';
    trig_i <= '0';
    wait for 20*clkPeriod;
    wait;
end process;


end Behavioral;
