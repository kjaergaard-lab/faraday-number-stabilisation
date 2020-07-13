library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity ProcessPowerData is
    port(
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        trig_i      :   in  std_logic;
        
        adcData_i   :   in  signed(15 downto 0);
        valid_i     :   in  std_logic;
        
        reg0        :   in  t_param_reg;
        
        pow_o       :   out unsigned(QUAD_BARE_WIDTH-1 downto 0);
        valid_o     :   out std_logic
    );
end ProcessPowerData;

architecture Behavioral of IntegrateADCData is

COMPONENT Division24by8
PORT (
    aclk : IN STD_LOGIC;
    s_axis_divisor_tvalid : IN STD_LOGIC;
    s_axis_divisor_tready : OUT STD_LOGIC;
    s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    s_axis_dividend_tvalid : IN STD_LOGIC;
    s_axis_dividend_tready : OUT STD_LOGIC;
    s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
);
END COMPONENT;

type t_status_local is (idle, summing, dividing, finishing, output, saving);

signal sumStart, sumEnd, subStart, subEnd, width, count   :   unsigned(10 downto 0)    :=  (others => '0');
signal adc1, adc1_i :   signed(QUAD_BARE_WIDTH-1 downto 0)    :=  (others => '0');
signal trig         :   std_logic_vector(1 downto 0)   :=  "00";

signal state        :   t_status_local    :=  idle;
signal divValid_i, divValid   :   std_logic   :=  '0';   
signal div_o        :   std_logic_vector(31 downto 0);
signal div_i        :   std_logic_vector(23 downto 0);

begin

sumStart <= unsigned(reg0(10 downto 0));
subStart <= unsigned(reg0(21 downto 11));
width <= resize(unsigned(reg0(31 downto 22)),width'length);
sumEnd <= sumStart + width;
subEnd <= subStart + width;

adc1_i <= resize(adcData_i(13 downto 0),adc1_i'length);
div_i <= std_logic_vector(abs(adc1));

TrigSync: process(adcClk,aresetn) is
begin
    if aresetn = '0' then
        trig <= "00";
    elsif rising_edge(adcClk) then
        trig <= trig(0) & trig_i;
    end if;
end process;


SumDiffProc: process(adcClk,aresetn) is
begin
    if aresetn = '0' then
        adc1 <= (others => '0');
        count <= (others => '0');
        divValid_i <= '0';
        valid_o <= '0';
        pow_o <= (others => '0');
    elsif rising_edge(adcClk) then
        SumDiffFSM: case(state) is
            when idle =>
                valid_o <= '0';
                divValid_i <= '0';
                count <= (others => '0');
                if trig = "01" then
                    state <= summing;
                    adc1 <= (others => '0');
                    count <= (others => '0');
                end if;
                
            when summing =>
                if valid_i = '1' then
                    count <= count + 1;
                    if count >= sumStart and count <= sumEnd then
                        adc1 <= adc1 + adc1_i;
                    elsif count >= subStart and count <= subEnd then
                        adc1 <= adc1 - adc1_i;
                        if count = subEnd then
                            state <= dividing;
                            divValid_i <= '1';
                        end if;
                    end if;
                end if;
                
           when dividing =>
               divValid_i <= '0';
               if divValid = '1' then
                   pow_o <= signed(pow_o(pow_o'length-1 downto 0));
                   valid_o <= '1';
                   state <= idle;
               end if;

            when others => state <= idle;
        end case;
    end if;
end process;

--DivI : Division24by8
--PORT MAP (
--    aclk => adcClk,
--    s_axis_divisor_tvalid => divValid_i,
--    s_axis_divisor_tready => open,
--    s_axis_divisor_tdata => std_logic_vector(adc1),
--    s_axis_dividend_tvalid => divValid_i,
--    s_axis_dividend_tready => open,
--    s_axis_dividend_tdata => std_logic_vector(width),
--    m_axis_dout_tvalid => divValidI,
--    m_axis_dout_tdata => divI_o
--);

end Behavioral;
