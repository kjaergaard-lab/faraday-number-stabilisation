library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;

entity PulseGen is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;  
        cntrl_i     :   in  t_control;
        
        reg0        :   in  t_param_reg;
        reg1        :   in  t_param_reg;
        
        pulse_o     :   out std_logic;
        gate_o      :   out std_logic;
        status_o    :   out t_module_status
    );
end PulseGen;

architecture Behavioural of PulseGen is

signal trig, cntrl  :   std_logic_vector(1 downto 0)    :=  "00";
signal count        :   unsigned(31 downto 0)   :=  (others => '0');

signal numPulses, width :   unsigned(count'length-1 downto 0);
signal period   :   unsigned(31 downto 0);

signal pulseCount   :   unsigned(numPulses'length-1 downto 0)   :=  to_unsigned(10,numPulses'length);

begin

numPulses <= resize(unsigned(reg0(31 downto 16)),numPulses'length);
width <= resize(unsigned(reg0(15 downto 0)),width'length);
period <= unsigned(reg1);
--gate_o <= '0';

TrigSync: process(clk,aresetn) is
begin
    if aresetn = '0' then
        trig <= "00";
        cntrl <= "00";
    elsif rising_edge(clk) then
        trig <= trig(0) & cntrl_i.start;
        cntrl <= cntrl(0) & cntrl_i.stop;
    end if;
end process;

PulseProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        pulse_o <= '0';
        gate_o <= '0';
        pulseCount <= (others => '0');
        count <= (others => '0');
        status_o <= INIT_MODULE_STATUS;
    elsif rising_edge(clk) then
        if pulseCount >= numPulses or cntrl = "10" then
            count <= (others => '0');
            pulseCount <= (others => '0');
            status_o <= (running => '0',done => '1');
        elsif count = 0 then
            if ((trig = "01" and pulseCount = 0 and cntrl_i.enable = '1') or (pulseCount > 0 and pulseCount < numPulses)) then
                count <= to_unsigned(1,count'length);
                pulse_o <= '1';
                gate_o <= '1';
                status_o <= (running => '1',done => '0');
            else
                pulse_o <= '0';
                gate_o <= '0';
                status_o <= INIT_MODULE_STATUS;
            end if;
        elsif count < width then
            count <= count + 1;
            pulse_o <= '1';
            gate_o <= '1';
        elsif count < period - 1 then
            count <= count + 1;
            pulse_o <= '0';
            gate_o <= '0';
        elsif count >= period - 1 then
            count <= (others => '0');
            pulse_o <= '0';
            pulseCount <= pulseCount + 1;
        else
            count <= (others => '0');
            pulseCount <= (others => '0');
            pulse_o <= '0';
            gate_o <= '0';
        end if;
            
    end if;
end process;

end architecture Behavioural;