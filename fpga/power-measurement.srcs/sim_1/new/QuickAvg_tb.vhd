library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity QuickAvg_tb is
--  Port ( );
end QuickAvg_tb;

architecture Behavioral of QuickAvg_tb is

component QuickAvg is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        trig_i      :   in  std_logic;
        
        reg0        :   in  std_logic_vector(31 downto 0);
        
        adcData_i   :   in  std_logic_vector(31 downto 0);
        adcData_o   :   out std_logic_vector(31 downto 0);
        valid_o     :   out std_logic
    );
end component;

constant clkPeriod  :   time    :=  10 ns;

signal sysClk, adcClk, aresetn   :   std_logic  :=  '0';
signal adcData_i, adcData_o    :   std_logic_vector(31 downto 0)   :=  (others => '0');
signal trig_i, valid_o      :   std_logic   :=  '0';

signal reg0 :   std_logic_vector(31 downto 0); 

begin

uut: QuickAvg
port map(
    clk =>  adcClk,
    aresetn =>  aresetn,
    trig_i  =>  trig_i,
    reg0    =>  reg0,
    adcData_i   =>  adcData_i,
    adcData_o   =>  adcData_o,
    valid_o     =>  valid_o
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

adcData_i <= X"00100100";
reg0 <= X"2" & std_logic_vector(to_unsigned(10,14)) & std_logic_vector(to_unsigned(0,14));  

tb: process is
begin
    aresetn <= '0';
    wait for 50 ns;
    aresetn <= '1';
    wait until sysClk'event and sysClk = '1';
    trig_i <= '1';
    wait until sysClk'event and sysClk = '1';
    trig_i <= '0';
    wait for 100*clkPeriod;
    wait;
    
end process;


end Behavioral;
