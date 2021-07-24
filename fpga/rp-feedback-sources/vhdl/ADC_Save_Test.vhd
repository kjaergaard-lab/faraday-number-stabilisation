library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.AXI_Bus_Package.all;
use work.CustomDataTypes.all;

entity ADC_Save_Test is
    port(
        sysClk  :   in  std_logic;
        adcClk  :   in  std_logic;
        aresetn :   in  std_logic;
        
        adcData     :   in  std_logic_vector(31 downto 0);
        trig_i      :   in  std_logic;
        numSamples  :   in  unsigned(9 downto 0);
        
        bus_m       :   in  t_mem_bus_master;
        bus_s       :   out t_mem_bus_slave
        
    );
end ADC_Save_Test;

architecture Behavioral of ADC_Save_Test is

COMPONENT BlockMemory32x10
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

signal trig     :   std_logic_vector(1 downto 0)    :=  "00";
signal count    :   unsigned(numSamples'length-1 downto 0)  :=  (others => '0');
signal wea      :   std_logic_vector(0 downto 0)    :=  "0";
signal addra    :   t_mem_addr  :=  (others => '0');

signal state    :   natural range 0 to 3    :=  0;

begin

--
-- Instantiate the block memory
--
BlockMem : BlockMemory32x10
  PORT MAP (
    clka => adcClk,
    wea => wea,
    addra => addra,
    dina => adcData,
    clkb => sysClk,
    addrb => bus_m.addr,
    doutb => bus_s.data
  );

--
-- Create a trigger for the write process by crossing clock domains.
-- The input trigger from the user is synchronous with sysClk, but 
-- the output trig signal is synchronous with adcClk.
--
TrigSync: process(adcClk,aresetn) is
begin
    if aresetn = '0' then
        trig <= "00";
    elsif rising_edge(adcClk) then
        trig <= trig(0) & trig_i;
    end if;
end process;

--
-- Write ADC data to memory
-- On the rising edge of 'trig' we write numSamples to memory
-- On the falling edge of 'trig' we reset the counter
--
WriteProc: process(adcClk,aresetn) is
begin
    if aresetn = '0' then
        count <= (others => '0');
    elsif rising_edge(adcClk) then
        if trig = "10" or (count >= numSamples) then
            wea <= "0";
            count <= (others => '0');  
        elsif (trig = "01" and count = 0) or (wea = "1" and count < numSamples) then
            wea <= "1";
            addra <= std_logic_vector(count);
            count <= count + 1;
        end if;
    end if;
end process;

--
-- Reads data from the memory address provided by the user
-- Note that we need an extra clock cycle to read data compared to writing it
--
ReadProc: process(sysClk,aresetn) is
begin
    if aresetn = '0' then
        state <= 0;
        bus_s.valid <= '0';
    elsif rising_edge(sysClk) then
        if state = 0 and bus_m.trig = '1' then
            state <= 1;
            bus_s.valid <= '0';
        elsif state < 2 then
            state <= state + 1;
        elsif state = 2 then
            state <= 0;
            bus_s.valid <= '1';
        else
            bus_s.valid <= '0';
        end if;
    end if;
end process;

end Behavioral;
