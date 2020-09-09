library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;

entity QuickAvg is
    port(
        clk         :   in  std_logic;          --Input clock
        aresetn     :   in  std_logic;          --Asynchronous reset
        trig_i      :   in  std_logic;          --Input trigger
        
        reg0        :   in  t_param_reg;        --Parameters: (log2Avgs (4), number of samples (14), delay (14)) 
        
        adcData_i   :   in  t_adc_combined;     --Input ADC data
        adcData_o   :   out t_adc_combined;     --Output, averaged ADC data
        trig_o      :   out std_logic;          --Input trigger delayed by "delay" cycles
        valid_o     :   out std_logic           --Indicates valid averaged data
    );
end QuickAvg;

architecture Behavioural of QuickAvg is

constant MAX_AVGS   :   natural :=  255;
constant PADDING    :   natural :=  8;  
constant EXT_WIDTH  :   natural :=  adcData_i'length/2+PADDING; 

signal trigSync     :   std_logic_vector(1 downto 0)    :=  "00";
signal trig, trigOld:   std_logic               :=  '0';
signal count        :   unsigned(31 downto 0)   :=  (others => '0');

signal delay        :   unsigned(13 downto 0)   :=  (others => '0');
signal numSamples   :   unsigned(13 downto 0)   :=  (others => '0');
signal log2Avgs     :   natural range 0 to 15   :=  0;
signal numAvgs      :   unsigned(7 downto 0)    :=  to_unsigned(1,8);

signal avgCount     :   unsigned(numAvgs'length-1 downto 0) :=  (others => '0');
signal delayCount, sampleCount  :   unsigned(delay'length-1 downto 0)   :=  (others => '0');

signal state, delayState        :   t_status    :=  idle;

signal adc1, adc1_tmp, adc2, adc2_tmp   :   signed(EXT_WIDTH-1 downto 0) :=  (others => '0');

begin

delay <= unsigned(reg0(13 downto 0));
numSamples <= unsigned(reg0(27 downto 14));
log2Avgs <= to_integer(unsigned(reg0(31 downto 28)));
numAvgs <= shift_left(to_unsigned(1,numAvgs'length),log2Avgs);

adc1_tmp <= resize(signed(adcData_i(15 downto 0)),adc1_tmp'length);
adc2_tmp <= resize(signed(adcData_i(31 downto 16)),adc2_tmp'length);

trig_o <= trig;

--TrigSyncProc: process(clk,aresetn) is
--begin
--    if aresetn = '0' then
--        trigSync <= "00";
--    elsif rising_edge(clk) then
--        trigSync <= trigSync(0) & trig_i;
--    end if;
--end process;

TrigDelay: process(clk,aresetn) is
begin
    if aresetn = '0' then
        delayCount <= (others => '0');
        trig <= '0';
        delayState <= idle;
    elsif rising_edge(clk) then
    
        trigOld <= trig_i;
        
        DelayFSM: case delayState is
            when idle =>
                if trigOld = '0' and trig_i = '1' then
                    if delay = 0 then
                        trig <= '1';
                    else
                        trig <= '0';
                        delayCount <= (others => '0');
                        delayState <= waiting;
                    end if;
                else
                    trig <= '0';
                end if;
                
            when waiting =>
                if delayCount < delay then
                    delayCount <= delayCount + 1;
                    trig <= '0';
                else
                    delayState <= idle;
                    trig <= '1';
                end if;
                    
            when others => null;
        end case;
    end if;
end process;

MainProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        avgCount <= (others => '0');
--        delayCount <= (others => '0');
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
--                delayCount <= to_unsigned(1,delayCount'length);
                adc1 <= (others => '0');
                adc2 <= (others => '0');
                valid_o <= '0';
                adcData_o <= (others => '0');
                if trig = '1' then
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