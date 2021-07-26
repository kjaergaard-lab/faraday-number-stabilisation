library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PulseGen_tb is
--  Port ( );
end PulseGen_tb;

architecture Behavioral of PulseGen_tb is

component PulseGen is
    port(
        clk         :   in  std_logic;                      --Input clock
        aresetn     :   in  std_logic;                      --Asynchronous reset
        cntrl_i     :   in  t_control;                      --Control structure
        
        --
        -- Array of parameters:
        -- 3: (enable additional pulses(1), additional pulses (8))
        -- 2: delay
        -- 1: period
        -- 0: (number of pulses (16), pulse width (16))
        --
        regs        :   in  t_param_reg_array(3 downto 0);
        
        pulse_o     :   out std_logic;                      --Output pulse
        status_o    :   out t_module_status                 --Output module status
    );
end component;

constant clkPeriod  :   time    :=  10 ns;

signal sysClk, adcClk, aresetn  :   std_logic  :=  '0';
signal regs     :   t_param_reg_array(3 downto 0);
signal cntrl    :   t_control;
signal pulse_o  :   std_logic;
signal status   :   t_module_status;

begin

uut: PulseGen
port map(
    clk     =>  adcClk,
    aresetn =>  aresetn,
    cntrl_i =>  cntrl,
    regs    =>  regs,
    pulse_o =>  pulse_o,
    status_o=>  status
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

regs(0) <= X"000a" & X"000a";
regs(1) <= X"00000014";
regs(2) <= X"00000000";
regs(3) <= X"00000105";


tb: process is
begin
    aresetn <= '0';
    cntrl <= (enable => '1', start => '0', stop => '0', debug => X"0");
    wait for 50 ns;
    aresetn <= '1';
    wait until adcClk'event and adcClk = '1';
    cntrl.start <= '1';
    wait until adcClk'event and adcClk = '1';
    cntrl.start <= '0';
    wait for 520 ns;
    wait until adcClk'event and adcClk = '1';
    cntrl.stop <= '1';
    wait until adcClk'event and adcClk = '1';
    cntrl.stop <= '0';
    wait for 1 us;
    wait;
    
end process;


end Behavioral;
