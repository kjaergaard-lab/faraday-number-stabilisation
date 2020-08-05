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
        normalise_i :   in  std_logic;
        
        quad_o      :   out unsigned(QUAD_WIDTH-1 downto 0);
        valid_o     :   out std_logic
    );
end ComputeSignal;

architecture Behavioral of ComputeSignal is

--COMPONENT Square24
--  PORT (
--    CLK : IN STD_LOGIC;
--    A : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
--    B : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
--    P : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
--  );
--END COMPONENT;

--COMPONENT SquareRoot48
--  PORT (
--    aclk : IN STD_LOGIC;
--    s_axis_cartesian_tvalid : IN STD_LOGIC;
--    s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
--    m_axis_dout_tvalid : OUT STD_LOGIC;
--    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
--  );
--END COMPONENT;

COMPONENT PowDivider
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_divisor_tvalid : IN STD_LOGIC;
    s_axis_divisor_tready : OUT STD_LOGIC;
    s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    s_axis_dividend_tvalid : IN STD_LOGIC;
    s_axis_dividend_tready : OUT STD_LOGIC;
    s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(QUAD_WIDTH-1 DOWNTO 0)
  );
END COMPONENT;

type t_status_local is (idle,multiplying,rooting,waiting,dividing);

constant MULT_LATENCY   :   natural :=  4;
constant SQRT_LATENCY   :   natural :=  13; 
constant DIV_LATENCY    :   natural :=  50;

signal count    :   natural range 0 to 63   :=  0;
signal quad         :   std_logic_vector(31 downto 0);
signal quad_valid   :   std_logic;

signal quadDiv, powDiv  :   std_logic_vector(QUAD_BARE_WIDTH-1 downto 0)   :=  (others => '0');
signal div_o    :   std_logic_vector(QUAD_WIDTH-1 downto 0)   :=  (others => '0');

signal state    :   t_status_local  :=  idle;

begin

ComputePowDivision : PowDivider
  PORT MAP (
    aclk                    => adcClk,
    s_axis_divisor_tvalid   => '1',
    s_axis_divisor_tready   => open,
    s_axis_divisor_tdata    => powDiv,
    s_axis_dividend_tvalid  => '1',
    s_axis_dividend_tready  => open,
    s_axis_dividend_tdata   => quadDiv,
    m_axis_dout_tvalid      => open,
    m_axis_dout_tdata       => div_o
  );

MainProc: process(adcClk,aresetn) is
begin
    if aresetn = '0' then
        count <= 0;
        state <= idle;
        valid_o <= '0';
        quad_o <= (others => '0');
        quadDiv <= (others => '0');
        powDiv <= (0 => '1', others => '0');
    elsif rising_edge(adcClk) then
        FSM: case (state) is
            when idle =>
                valid_o <= '0';
                if valid_i = '1' then
                    quadDiv <= std_logic_vector(dataI_i);
                    if normalise_i = '1' then
                        powDiv <= std_logic_vector(dataQ_i);
                    else
                        powDiv <= (0 => '1', others => '0');
                    end if;
                    count <= 0;
                    state <= dividing;
                end if;
                
            when dividing =>
                if count < DIV_LATENCY then
                    count <= count + 1;
                else
                    count <= 0;
                    quad_o <= unsigned(div_o);
                    valid_o <= '1';
                    state <= idle;
                end if;
            
            when others => state <= idle;
        end case;
    end if;
end process;

end Behavioral;
