library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity ComputeSignal is
    port(
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        
        dataI_i     :   in  signed(23 downto 0);
        dataQ_i     :   in  signed(23 downto 0);
        valid_i     :   in  std_logic;
        
        quad_o      :   out unsigned(23 downto 0);
        valid_o     :   out std_logic
    );
end ComputeSignal;

architecture Behavioral of ComputeSignal is

COMPONENT Square24
  PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
  );
END COMPONENT;

COMPONENT SquareRoot48
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_cartesian_tvalid : IN STD_LOGIC;
    s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

type t_status_local is (idle,multiplying,rooting);

constant MULT_LATENCY   :   natural :=  4;
constant SQRT_LATENCY   :   natural :=  13; 

signal count    :   natural range 0 to 31   :=  0;
signal I2, Q2   :   std_logic_vector(47 downto 0)   :=  (others => '0');
signal iqSum    :   unsigned(47 downto 0)   :=  (others => '0');
signal quad         :   std_logic_vector(31 downto 0);
signal quad_valid   :   std_logic;

signal state    :   t_status_local  :=  idle;

begin

SquareI: Square24
port map(
    CLK =>  adcClk,
    A   =>  std_logic_vector(dataI_i),
    B   =>  std_logic_vector(dataI_i),
    P   =>  I2
);

SquareQ: Square24
port map(
    CLK =>  adcClk,
    A   =>  std_logic_vector(dataQ_i),
    B   =>  std_logic_vector(dataQ_i),
    P   =>  Q2
);

iqSum <= unsigned(I2) + unsigned(Q2);

Root: SquareRoot48
port map(
    aclk    =>  adcClk,
    s_axis_cartesian_tvalid => '1',
    s_axis_cartesian_tdata => std_logic_vector(iqSum),
    m_axis_dout_tvalid => quad_valid,
    m_axis_dout_tdata => quad
);

MainProc: process(adcClk,aresetn) is
begin
    if aresetn = '0' then
        count <= 0;
        state <= idle;
        valid_o <= '0';
        quad_o <= (others => '0');
    elsif rising_edge(adcClk) then
        FSM: case (state) is
            when idle =>
            valid_o <= '0';
                if valid_i = '1' then
                    count <= 0;
                    state <= multiplying;
                end if;
                
            when multiplying =>
                if count < MULT_LATENCY then
                    count <= count + 1;
                else
                    count <= 0;
                    state <= rooting;
                end if;
                
            when rooting =>
                if count < SQRT_LATENCY - 2 then
                    count <= count + 1;
                else
                    count <= 0;
                    quad_o <= unsigned(quad(quad_o'length-1 downto 0));
                    valid_o <= '1';
                    state <= idle;
                end if;
            
            when others => state <= idle;
        end case;
    end if;
end process;



end Behavioral;
