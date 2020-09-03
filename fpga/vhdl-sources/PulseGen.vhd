library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;

entity PulseGen is
    port(
        clk         :   in  std_logic;                      --Input clock
        aresetn     :   in  std_logic;                      --Asynchronous reset
        cntrl_i     :   in  t_control;                      --Control structure
        
        --
        -- Array of parameters:
        -- 2: delay
        -- 1: period
        -- 0: (number of pulses (16), pulse width (16))
        --
        regs        :   in  t_param_reg_array(2 downto 0);
        
        pulse_o     :   out std_logic;                      --Output pulse
        status_o    :   out t_module_status                 --Output module status
    );
end PulseGen;

architecture Behavioural of PulseGen is

type t_status_local is (idle, pulsing, incrementing, delaying);

signal state        :   t_status_local  :=  idle;

signal trig, cntrl  :   std_logic_vector(1 downto 0)    :=  "00";
signal count        :   unsigned(31 downto 0)   :=  (others => '0');

signal numPulses, width :   unsigned(count'length-1 downto 0);
signal period   :   unsigned(31 downto 0);
signal delay    :   unsigned(31 downto 0);

signal pulseCount   :   unsigned(numPulses'length-1 downto 0)   :=  (others => '0');

begin

numPulses <= resize(unsigned(regs(0)(31 downto 16)),numPulses'length);
width <= resize(unsigned(regs(0)(15 downto 0)),width'length);
period <= unsigned(regs(1));
delay <= unsigned(regs(2));

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
        pulseCount <= (others => '0');
        count <= (others => '0');
        status_o <= INIT_MODULE_STATUS;
    elsif rising_edge(clk) then
        if cntrl = "10" then
            --
            -- Falling edge of cntrl signal indicates that the pulse
            -- process should stop
            --
            count <= (others => '0');
            pulseCount <= (others => '0');
            state <= idle;
            pulse_o <= '0';
            status_o <= (running => '0', done => '1', started => '0');
        else
            FSM: case state is
                when idle =>
                    pulseCount <= (others => '0');
                    status_o.done <= '0';
                    if trig = "01" and cntrl_i.enable = '1' then
                        count <= to_unsigned(1,count'length);
                        status_o.running <= '1';
                        status_o.started <= '1';
                        if delay = 0 then
                            pulse_o <= '1';
                            state <= pulsing;
                        else
                            pulse_o <= '0';
                            state <= delaying;
                        end if;
                    else
                        count <= to_unsigned(0,count'length);
                        pulse_o <= '0';
                        status_o.running <= '0';
                    end if;
                    
                when delaying =>
                    status_o.started <= '0';
                    if count < delay then
                        count <= count + 1;
                    else
                        count <= to_unsigned(1,count'length);
                        pulse_o <= '1';
                        state <= pulsing;
                    end if;
                    
                when pulsing =>
                    status_o.started <= '0';
                    if count < width then
                        count <= count + 1;
                        pulse_o <= '1';
                    elsif count < period - 1 then
                        count <= count + 1;
                        pulse_o <= '0';
                    else
                        count <= to_unsigned(1,count'length);
                        state <= incrementing;
                        pulseCount <= pulseCount + 1;
                    end if;
                    
                when incrementing =>
                    if pulseCount < numPulses then
                        state <= pulsing;
--                        pulseCount <= pulseCount + 1;
                        pulse_o <= '1';
                    else
                        state <= idle;
                        status_o <= (running => '0', done => '1', started => '0');
                    end if;
                    
                when others => state <= idle;
            end case;
        end if;     
    end if;
end process;

end architecture Behavioural;