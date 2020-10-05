library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity topmod_tb is
--  Port ( );
end topmod_tb;

architecture Behavioral of topmod_tb is

component topmod is
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
end component;

constant clkPeriod      :   time    :=  10 ns;

signal sysClk, adcClk   :   std_logic;
signal aresetn          :   std_logic;
signal ext_i, ext_o     :   std_logic_vector(7 downto 0);
signal adcData_i        :   std_logic_vector(31 downto 0);

signal addr_i           :   unsigned(AXI_ADDR_WIDTH-1 downto 0);
signal writeData_i      :   std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal dataValid_i      :   std_logic_vector(1 downto 0);
signal readData_o       :   std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal resp_o           :   std_logic_vector(1 downto 0);


begin

uut: topmod
port map(
    sysClk      =>  sysClk,
    aresetn     =>  aresetn,
    ext_i       =>  ext_i,
    
    addr_i      =>  addr_i,
    writeData_i =>  writeData_i,
    dataValid_i =>  dataValid_i,
    readData_o  =>  readData_o,
    resp_o      =>  resp_o,
    
    adcClk      =>  adcClk,
    adcData_i   =>  adcData_i
);

clk_process :process
begin
	adcClk <= '0';
	sysClk <= '0';
	wait for clkPeriod/2;
	adcClk <= '1';
	sysClk <= '1';
	wait for clkPeriod/2;
end process;


tb: process
begin
    aresetn <= '0';
    addr_i <= (others => '0');
    writeData_i <= (others => '0');
    dataValid_i <= (others => '0');
    adcData_i <= std_logic_vector(to_unsigned(4000,16) & to_unsigned(3000,16));
    ext_i <= (others => '0');
    wait for 100 ns;
    aresetn <= '1';
    wait until adcClk'event and adcClk = '1';
    ext_i(2) <= '1';
    wait until adcClk'event and adcClk = '1';
    ext_i(2) <= '0';
    wait for 1000 ns;
    wait until adcClk'event and adcClk = '1';
    ext_i(2) <= '1';
    wait until adcClk'event and adcClk = '1';
    ext_i(2) <= '0';
    wait;
    
end process;


end Behavioral;
