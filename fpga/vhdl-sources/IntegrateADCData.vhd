library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity IntegrateADCData is
    port(
        clk         :   in  std_logic;                          --Input clock synchronous with adcData_i
        aresetn     :   in  std_logic;                          --Asynchronous reset
        trig_i      :   in  std_logic;                          --Input trigger synchronous with clk
        
        adcData_i   :   in  t_adc_combined;                     --Two-channel ADC data
        valid_i     :   in  std_logic;                          --1-cycle signal high when adcData_i is valid
        
        --
        -- 1: (X (3 bits), use preset offsets (1), offset adc 2 (14), offset adc 1 (14))
        -- 0: (integration width (10), subtraction start (11), summation start (11))
        --
        regs        :   in  t_param_reg_array(1 downto 0);
        
        data_o      :   out t_adc_integrated_array(1 downto 0); --Integrated data from both ADCs
        valid_o     :   out std_logic;                          --High for one cycle when integrated data is valid
        
        dataSave_o  :   out t_mem_data;                         --Integrated data for memory
        validSave_o :   out std_logic                           --High for one cycle when dataSave_o i valid
    );
end IntegrateADCData;

architecture Behavioral of IntegrateADCData is

--
-- State machine state definition
--
type t_status_local is (idle, summing, finishing, output, saving, waiting);
signal state        :   t_status_local    :=  idle;

--
-- Signals for integrating data
--
signal sumStart, sumEnd, subStart, subEnd, width, count     :   unsigned(10 downto 0)    :=  (others => '0');
signal adc, adc_i, offsets                                  :   t_adc_integrated_array    :=  (others => (others => '0'));
signal usePresetOffsets                                     :   std_logic;

begin

--
-- Resize ADC data
--
adc_i(0) <= resize(signed(adcData_i(13 downto 0)),INTEG_WIDTH);
adc_i(1) <= resize(signed(adcData_i(29 downto 16)),INTEG_WIDTH);

--
-- Parse input registers
--
sumStart <= unsigned(regs(0)(10 downto 0));
subStart <= unsigned(regs(0)(21 downto 11));
width <= resize(unsigned(regs(0)(31 downto 22)),width'length);
sumEnd <= sumStart + width;
subEnd <= subStart + width;

usePresetOffsets <= regs(1)(28);
offsets(0) <= resize(signed(regs(1)(13 downto 0)),INTEG_WIDTH-1);
offsets(1) <= resize(signed(regs(1)(27 downto 14)),INTEG_WIDTH-1);


SumDiffProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        state <= idle;
        valid_o <= '0';
        validSave_o <= '0';
        data_o <= (others => (others => '0'));
    elsif rising_edge(clk) then
        SumDiffFSM: case(state) is
            --
            -- Waits for the input trigger which should be raised when 
            -- data should start to be acquired.  Resets the integrated
            -- values.
            --
            when idle =>
                valid_o <= '0';
                validSave_o <= '0';
                if trig_i = '1' then
                    state <= summing;
                    adc <= (others => (others => '0'));
                    count <= (others => '0');
                end if;
                
            --
            -- On each valid ADC  value, sum/subtract values from the integrated
            -- values as necessary.
            --
            when summing =>
                if valid_i = '1' then
                    count <= count + 1;
                    if usePresetOffsets = '0' then
                        if count >= sumStart and count <= sumEnd then
                            adc(0) <= adc(0) + adc_i(0);
                            adc(1) <= adc(1) + adc_i(1);
                        elsif count >= subStart and count <= subEnd then
                            adc(0) <= adc(0) - adc_i(0);
                            adc(1) <= adc(1) - adc_i(1);
                            if count = subEnd then
                                state <= output;
                            end if;
                        end if;
                    else
                        if count >= sumStart and count <= sumEnd then
                            adc(0) <= adc(0) + adc_i(0) - offsets(0);
                            adc(1) <= adc(1) + adc_i(1) - offsets(1);
                            if count = sumEnd then
                                state <= output;
                            end if;
                        end if;
                    end if;
                end if;
                
            --
            -- Produce a synchronized output, save integrated data from first ADC
            --
            when output =>
                data_o <= adc;
                valid_o <= '1';
                
                dataSave_o <= std_logic_vector(resize(adc(0),dataSave_o'length));
                validSave_o <= '1';
                state <= waiting;
                
            --
            -- Wait 1 clock cycle
            --
            when waiting =>
                valid_o <= '0';
                validSave_o <= '0';
                state <= saving;
                
            --
            -- Save integrated data from second ADC
            --
            when saving =>
                valid_o <= '0';
                dataSave_o <= std_logic_vector(resize(adc(1),dataSave_o'length));
                validSave_o <= '1';
                state <= idle;

            when others => state <= idle;
        end case;
    end if;
end process;

end Behavioral;
