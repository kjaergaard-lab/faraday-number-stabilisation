library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity ComputeSignal_tb is
--  Port ( );
end ComputeSignal_tb;

architecture Behavioral of ComputeSignal_tb is

component ComputeSignal is
    port(
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        
        dataI_i     :   in  signed(23 downto 0);
        dataQ_i     :   in  signed(23 downto 0);
        valid_i     :   in  std_logic;
        
        pow_i       :   in  unsigned(23 downto 0);
        powValid_i  :   in  std_logic;
        usePow_i    :   in  std_logic;
        
        quad_o      :   out unsigned(23 downto 0);
        valid_o     :   out std_logic
    );
end component;

constant clkPeriod  :   time    :=  10 ns;

signal adcClk, aresetn   :   std_logic  :=  '0';
signal dataI_i, dataQ_i  :   signed(23 downto 0)   :=  (others => '0');
signal valid_i, valid_o, powValid_i, usePow_i  :   std_logic   :=  '0';
signal quad_o, pow_i   :   unsigned(23 downto 0)   :=  (others => '0');


begin

uut: ComputeSignal
port map(
    adcClk      =>  adcClk,
    aresetn     =>  aresetn,
    dataI_i     => dataI_i,
    dataQ_i     => dataQ_i,
    valid_i     => valid_i,
    pow_i       =>  pow_i,
    powValid_i  =>  powValid_i,
    usePow_i    =>  usePow_i,
    quad_o      => quad_o,
    valid_o     =>  valid_o
);

-- Clock process definitions
clk_process :process
begin
	adcClk <= '0';
	wait for clkPeriod/2;
	adcClk <= '1';
	wait for clkPeriod/2;
end process;



tb: process is
begin
    aresetn <= '0';
    wait for 50 ns;
    aresetn <= '1';
    wait until adcClk'event and adcClk = '1';
    valid_i <= '1';
    dataI_i <= to_signed(1300,dataI_i'length);
    dataQ_i <= to_signed(-6798,dataQ_i'length);
    pow_i <= to_unsigned(1000,pow_i'length);
    usePow_i <= '1';
    powValid_i <= '0';
    wait until adcClk'event and adcClk = '1';
    valid_i <= '0';
    wait for 100*clkPeriod;
    wait until adcClk'event and adcClk = '1';
    powValid_i <= '1';
    wait until adcClk'event and adcClk = '1';
    powValid_i <= '0';
    wait for 100*clkPeriod;
    wait;
    
end process;

end Behavioral;
