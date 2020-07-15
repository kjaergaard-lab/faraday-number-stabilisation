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
        
        peak_i      :   in  unsigned(15 downto 0);
        peakValid_i :   in  std_logic;
        pow_i       :   in  unsigned(23 downto 0);
        powValid_i  :   in  std_logic;
        usePow_i    :   in  std_logic;
        
        ratio_o     :   out unsigned(QUAD_WIDTH-1 downto 0);
        valid_o     :   out std_logic
    );
end ComputeSignal;

architecture Behavioral of ComputeSignal is

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

constant DIV_LATENCY    :   natural :=  50;

signal count    :   natural range 0 to 63   :=  0;

signal peakDiv, powDiv  :   std_logic_vector(QUAD_BARE_WIDTH-1 downto 0)   :=  (others => '0');
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
        ratio_o <= (others => '0');
        peakDiv <= (others => '0');
        powDiv <= (0 => '1', others => '0');
    elsif rising_edge(adcClk) then
        FSM: case (state) is
            when idle =>
                valid_o <= '0';
                if peakValid_i = '1' then
                    state <= waiting;
                    peakDiv <= std_logic_vector(resize(peak_i,peakDiv'length));
                end if;
                
            when waiting =>
                if usePow_i = '0' then
                    quad_o <= shift_left(resize(unsigned(peakDiv),QUAD_WIDTH),QUAD_FRAC_WIDTH);
                    valid_o <= '1';
                    state <= idle;
                elsif powValid_i = '1' then
                    count <= 0;
                    powDiv <= std_logic_vector(resize(pow_i,powDiv'length));
                    state <= dividing;
                end if;
                
            when dividing =>
                if count < DIV_LATENCY then
                    count <= count + 1;
                else
                    count <= 0;
                    ratio_o <= unsigned(div_o);
                    valid_o <= '1';
                    state <= idle;
                end if;
            
            when others => state <= idle;
        end case;
    end if;
end process;

end Behavioral;
