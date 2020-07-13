library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;

entity QuickAvg is
    port(
        clk         :   in  std_logic;
        aresetn     :   in  std_logic;
        trig_i      :   in  std_logic;
        
        reg0        :   in  t_param_reg;
        
        adcData_i   :   in  t_adc_combined;
        adcData_o   :   out t_adc_combined;
        valid_o     :   out std_logic
    );
end QuickAvg;

architecture Behavioural of QuickAvg is

constant MAX_AVGS   :   natural :=  255;
constant PADDING    :   natural :=  8;  
constant EXT_WIDTH  :   natural :=  adcData_i'length/2+PADDING; 

signal trig         :   std_logic_vector(1 downto 0)    :=  "00";
signal count        :   unsigned(31 downto 0)   :=  (others => '0');

signal delay        :   unsigned(13 downto 0)   :=  (others => '0');
signal numSamples   :   unsigned(13 downto 0)   :=  (others => '0');
signal log2Avgs     :   natural range 0 to 15   :=  0;
signal numAvgs      :   unsigned(7 downto 0)    :=  to_unsigned(1,8);

signal avgCount     :   unsigned(numAvgs'length-1 downto 0) :=  (others => '0');
signal delayCount, sampleCount  :   unsigned(delay'length-1 downto 0)   :=  (others => '0');

signal state        :   t_status    :=  idle;

signal adc1, adc1_tmp, adc2, adc2_tmp   :   signed(EXT_WIDTH-1 downto 0) :=  (others => '0');

begin

delay <= unsigned(reg0(13 downto 0));
numSamples <= unsigned(reg0(27 downto 14));
log2Avgs <= to_integer(unsigned(reg0(31 downto 28)));
numAvgs <= shift_left(to_unsigned(1,numAvgs'length),log2Avgs);

adc1_tmp <= resize(signed(adcData_i(15 downto 0)),adc1_tmp'length);
adc2_tmp <= resize(signed(adcData_i(31 downto 16)),adc2_tmp'length);

TrigSync: process(clk,aresetn) is
begin
    if aresetn = '0' then
        trig <= "00";
    elsif rising_edge(clk) then
        trig <= trig(0) & trig_i;
    end if;
end process;

MainProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        avgCount <= (others => '0');
        delayCount <= (others => '0');
        sampleCount <= (others => '0');
        adc1 <= (others => '0');
        adc2 <= (others => '0');
        valid_o <= '0';
        adcData_o <= (others => '0');
    elsif rising_edge(clk) then
        AvgFSM: case(state) is
            --
            -- Wait for trigger
            --
            when idle =>
                avgCount <= (others => '0');
                sampleCount <= to_unsigned(1,sampleCount'length);
                delayCount <= to_unsigned(1,delayCount'length);
                adc1 <= (others => '0');
                adc2 <= (others => '0');
                valid_o <= '0';
                adcData_o <= (others => '0');
                if trig = "01" then
                    state <= waiting;
                end if;
            --
            -- Waits for a delay
            --
            when waiting =>
                if delayCount < delay then
                    delayCount <= delayCount + 1;
                else
                    delayCount <= (others => '0');
                    state <= processing;
                end if;
                
            --
            -- Average data
            --
            when processing =>
                if sampleCount <= numSamples then
                    if log2Avgs = 0 then
                        adcData_o <= adcData_i;
                        valid_o <= '1';
                        sampleCount <= sampleCount + 1;
                    elsif avgCount = 0 then
                        adc1 <= adc1_tmp;
                        adc2 <= adc2_tmp;
                        valid_o <= '0';
                        avgCount <= avgCount + 1;
                    elsif avgCount = numAvgs - 1 then
                        adcData_o(31 downto 16) <= std_logic_vector(resize(shift_right(adc2 + adc2_tmp,log2Avgs),16));
                        adcData_o(15 downto 0) <= std_logic_vector(resize(shift_right(adc1 + adc1_tmp,log2Avgs),16));
                        
--                        adcData_o <= std_logic_vector(shift_right(adc2 + adc2_tmp,log2Avgs)) & std_logic_vector(shift_right(adc1 + adc1_tmp,log2Avgs));
                        valid_o <= '1';
                        sampleCount <= sampleCount + 1;
                        avgCount <= (others => '0');
                    else
                        adc1 <= adc1 + adc1_tmp;
                        adc2 <= adc2 + adc2_tmp;
                        valid_o <= '0';
                        avgCount <= avgCount + 1;
                     end if;
                 else
                    state <= idle;
                    valid_o <= '0';
                end if;
            when others => state <= idle;
        end case;
    end if;
end process;

end architecture Behavioural;