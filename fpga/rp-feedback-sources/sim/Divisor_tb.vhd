library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity Divisor_tb is
--  Port ( );
end Divisor_tb;

architecture Behavioral of Divisor_tb is


COMPONENT SignalDivider
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_divisor_tvalid : IN STD_LOGIC;
    s_axis_divisor_tready : OUT STD_LOGIC;
    s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_dividend_tvalid : IN STD_LOGIC;
    s_axis_dividend_tready : OUT STD_LOGIC;
    s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(79 DOWNTO 0)
  );
END COMPONENT;

constant clkPeriod  :   time    :=  10 ns;

signal clk, aresetn  :   std_logic  :=  '0';

signal valid_i  :   std_logic_vector(1 downto 0)    :=  "00";
signal valid_o  :   std_logic                       :=  '0';
signal divisor  :   std_logic_vector(31 downto 0)   :=  (others => '0');
signal dividend :   std_logic_vector(47 downto 0)   :=  (others => '0');
signal div_o    :   std_logic_vector(79 downto 0);
signal div_int  :   std_logic_vector(47 downto 0);
signal res      :   signed(23 downto 0)             :=  (others => '0');
signal res_abs  :   unsigned(23 downto 0);  

begin

clk_process :process
begin
	clk <= '0';
	wait for clkPeriod/2;
	clk <= '1';
	wait for clkPeriod/2;
end process;



SIG_DIV: SignalDivider
port map(
    aclk                    =>  clk,
    s_axis_divisor_tvalid   =>  valid_i(0),
    s_axis_divisor_tdata    =>  divisor,
    s_axis_dividend_tvalid  =>  valid_i(1),
    s_axis_dividend_tdata   =>  dividend,
    m_axis_dout_tvalid      =>  valid_o,
    m_axis_dout_tdata       =>  div_o
);

div_int <= div_o(div_o'length-1 downto divisor'length);
res <= resize(signed(div_int),res'length);
res_abs <= unsigned(abs(res));

tb: process is
begin
    
    divisor <= std_logic_vector(to_signed(4,32));
    dividend <= std_logic_vector(shift_left(to_signed(-2,48),16));

    wait until clk'event and clk = '1';
    valid_i <= "11";
    wait until clk'event and clk = '1';
    valid_i <= "00";
    wait for 10*clkPeriod;
    
    
    wait for 70*clkPeriod;
--    wait until clk'event and clk = '1';
--    powValid_i <= '1';
--    wait until clk'event and clk = '1';
--    powValid_i <= '0';
    wait;
end process;

end Behavioral;
