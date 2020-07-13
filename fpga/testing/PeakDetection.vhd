library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity PeakDetection is
    port(
        adcClk      :   in  std_logic;
        aresetn     :   in  std_logic;
        trig_i      :   in  std_logic;
        
        adcData_i   :   in  signed(15 downto 0);
        valid_i     :   in  std_logic;
        
        reg0        :   in  t_param_reg;
        
        amp_o       :   out unsigned(15 downto 0);
        valid_o     :   out std_logic
    );
end PeakDetection;

architecture Behavioral of PeakDetection is


type t_status_local is (idle, searching, output);

signal sumStart, sumEnd, width, count   :   unsigned(10 downto 0)    :=  (others => '0');
signal adcMax, adcMin   :   signed(adcData_i'length-1 downto 0) :=  (others => '0');
signal adcAmp           :   unsigned(adcData_i'length-1 downto 0)   :=  (others => '0');
signal trig             :   std_logic_vector(1 downto 0)   :=  "00";

signal state        :   t_status_local    :=  idle;

begin

sumStart <= unsigned(reg0(10 downto 0));
width <= resize(unsigned(reg0(31 downto 22)),width'length);
sumEnd <= sumStart + width;


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
        count <= (others => '0');
        valid_o <= '0';
        validSave_o <= '0';
        adcMax <= (others => '0');
        adcMin <= (others => '0');
        adcAmp <= (others => '0');
    elsif rising_edge(adcClk) then
        SumDiffFSM: case(state) is
            when idle =>
                valid_o <= '0';
                validSave_o <= '0';
                count <= (others => '0');
                if trig = "01" then
                    state <= searching;
                    adcMax <= (others => '0');
                    adcMin <= (others => '0');
                    adcAmp <= (others => '0');
                end if;
                
            when searching =>
                if valid_i = '1' then
                    count <= count + 1;
                    if count >= sumStart and count <= sumEnd then
                        if adcData_i > adcMax then
                            adcMax <= adcData_i;
                        end;
                        if adcData_i < adcMin then
                            adcMin <= adcData_i;
                        end if;
                    elsif count > sumEnd then
                        adcAmp <= unsigned(abs(adcMax - adcMin));
                        state <= output;
                    end if;
                end if;
                
            when output =>
                amp_o <= adcAmp;
                valid_o <= '1';

                state <= idle;

            when others => state <= idle;
        end case;
    end if;
end process;


end Behavioral;
