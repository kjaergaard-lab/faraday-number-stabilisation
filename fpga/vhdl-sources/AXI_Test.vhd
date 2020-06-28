library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.AXI_Bus.all;


entity AXI_Test is
    port (
        clk     :   in  std_logic;
        aresetn :   in  std_logic;

        addr_i          :   in  unsigned(ADDR_WIDTH-1 downto 0);            --Address out
        dataValid_i     :   in  std_logic_vector(1 downto 0);               --Data valid out signal
        writeData_i     :   in  std_logic_vector(DATA_WIDTH-1 downto 0);    --Data to write
        readData_o      :   out std_logic_vector(DATA_WIDTH-1 downto 0);    --Data to read
        resp_o          :   out std_logic_vector(1 downto 0)                --Response in
    );
end AXI_Test;


architecture Behavioural of AXI_Test is
    
signal comState     :   natural range 0 to 3    :=  0;

signal axiBus       :   t_axi_bus   :=  INIT_AXI_BUS;
signal a    :   std_logic   :=  '0';
signal b    :   std_logic_vector(15 downto 0)   :=  (others => '0');
signal c    :   unsigned(23 downto 0)   :=  (others => '0');
signal d    :   signed(23 downto 0)   :=  (others => '0');

begin

axiBus.m.addr <= addr;
axiBus.m.valid <= dataValid_i;
axiBus.m.data <= writeData_i;
readData_o <= axiBus.s.data;
resp_o <= axiBus.s.resp;


Parse: process(clk,aresetn) is
begin
    if aresetn = '0' then
        comState <= 0;
    elsif rising_edge(clk) then
        FSM: case(comState) is
            when 0 =>
                resp_o <= "00";
                if dataValid_i(0) then
                    comState <= 1;
                end if;

            when 1 =>
                AddrCase: case(addr_i) is
                    when X"00000000" => rw(axiBus,comState,a);
                    when X"00000004" => rw(axiBus,comState,b);
                    when X"00000008" => rw(axiBus,comState,c);
                    when X"0000000c" => rw(axiBus,comState,d);
                    when others => 
                        comState <= 2;
                        axiBus.s.resp <= "11";
                end case;

            when 2 =>
                axiBus.s.resp <= "00";
                comState <= 0;

            when others => comState <= 0;
        end case;
    end if;
end process;
    
end architecture Behavioural;