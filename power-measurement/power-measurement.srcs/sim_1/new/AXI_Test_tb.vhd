library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.AXI_Bus_Package.all;


entity AXI_Test_tb is
--  Port ( );
end AXI_Test_tb;

architecture Behavioral of AXI_Test_tb is

component AXI_Test is
    port (
        clk     :   in  std_logic;
        aresetn :   in  std_logic;

        addr_i          :   in  unsigned(AXI_ADDR_WIDTH-1 downto 0);            --Address out
        writeData_i     :   in  std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to write
        dataValid_i     :   in  std_logic_vector(1 downto 0);                   --Data valid out signal
        readData_o      :   out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);    --Data to read
        resp_o          :   out std_logic_vector(1 downto 0)                    --Response in
    );
end component;

constant clkPeriod  :   time    :=  10 ns;

signal clk, aresetn  :   std_logic  :=  '0';
signal addr :   t_axi_addr  :=  (others => '0');
signal writeData, readData  :   t_axi_data  :=  (others => '0');
signal dataValid, resp  :   std_logic_vector(1 downto 0)    :=  "00";

begin

uut: AXI_Test
port map(
    clk =>  clk,
    aresetn =>  aresetn,
    addr_i  =>  addr,
    writeData_i   =>  writeData,
    dataValid_i   =>  dataValid,
    readData_o    =>  readData,
    resp_o      =>  resp
);

-- Clock process definitions
clk_process :process
begin
	clk <= '0';
	wait for clkPeriod/2;
	clk <= '1';
	wait for clkPeriod/2;
end process;

Main: process
begin
    aresetn <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait until clk'event and clk = '1';
    addr <= X"01000000";
    writeData <= X"00000000";
    dataValid <= "01";
    wait until resp'event and resp = "01";
    dataValid <= "00";
    wait until clk'event and clk = '1';
    addr <= X"01000004";
    writeData <= X"00000001";
    dataValid <= "01";
    wait until resp'event and resp = "01";
    dataValid <= "00";
    wait until clk'event and clk = '1';
    addr <= X"01000008";
    writeData <= X"00000002";
    dataValid <= "01";
    wait until resp'event and resp = "01";
    dataValid <= "00";
    
    wait for 100 ns;
    wait until clk'event and clk = '1';
    addr <= X"01000000";
    dataValid <= "11";
    wait until resp'event and resp = "01";
    dataValid <= "00";
    wait until clk'event and clk = '1';
    addr <= X"01000004";
    dataValid <= "11";
    wait until resp'event and resp = "01";
    dataValid <= "00";
    wait until clk'event and clk = '1';
    addr <= X"01000008";
    dataValid <= "11";
    wait until resp'event and resp = "01";
    dataValid <= "00";
    wait for 100*clkPeriod;
    wait;
    
end process;

end Behavioral;
