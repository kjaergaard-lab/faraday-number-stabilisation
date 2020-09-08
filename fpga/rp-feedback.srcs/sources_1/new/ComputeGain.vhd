library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;

entity ComputeGain is
    port(
        clk         :   in  std_logic;                          --Input clock
        aresetn     :   in  std_logic;                          --Asynchronous reset
        
        data_i      :   in  t_adc_integrated_array(1 downto 0); --Input integrated data
        valid_i     :   in  std_logic;                          --High for one clock cycle when data_i is valid

        multipliers :   in  t_param_reg;                        --Multiplication factors (X (16), ADC1 factor (8), ADC2 factor (8))
        
        gain_o      :   out t_gain_array(1 downto 0);           --Output gain values
        valid_o     :   out std_logic                           --High for one clock cycle when gain_o is valid
    );
end ComputeGain;

architecture Behavioural of ComputeGain is

COMPONENT GainFromAuxMultiplier
PORT (
    CLK : IN STD_LOGIC;
    A : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    B : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    P : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
);
END COMPONENT;

constant MULT_LATENCY   :   natural range 0 to 7    :=  3;

type t_status_local is (idle, multiplying, ouput);
signal state        :   t_status_local  :=  idle;
signal count        :   natural range 0 to 7        :=  0;

type t_signal_slv is array(natural range <>) of std_logic_vector(23 downto 0);
type t_factor_slv is array(natural range <>) of std_logic_vector(7 downto 0);
type t_gain_slv is array(natural range <>) of std_logic_vector(31 downto 0);

signal signal_slv   :   t_signal_slv(1 downto 0)    :=  (others => (others => '0'));
signal factor_slv   :   t_factor_slv(1 downto 0)    :=  (others => (others => '0'));
signal gain_slv     :   t_gain_slv(1 downto 0)      :=  (others => (others => '0'));

begin

MultGen: for I in 0 to 1 generate
    AuxMultiplierX: GainFromAuxMultiplier
    port map (
        CLK => CLK,
        A => signal_slv(I),
        B => factor_slv(I),
        P => gain_slv(I)
    );
end generate MultGen;

MultProc: process(clk,aresetn) is
begin
    if aresetn = '0' then
        signal_slv <= (others => (others => '0'));
        factor_slv <= (others => (others => '0'));
        gain_o <= (others => (0 => '1', others => '0'));
        state <= idle;
        valid_o <= '0';
    elsif rising_edge(clk) then
        MultState: case (state) is
            when idle =>
                count <= 0;
                valid_o <= '0';
                if valid_i = '1' then
                    factor_slv(0) <= multipliers(7 downto 0);
                    factor_slv(1) <= multipliers(15 downto 8);
                    signal_slv(0) <= std_logic_vector(data_i(0));
                    signal_slv(1) <= std_logic_vector(data_i(1));
                    state <= multiplying;
                end if;
                
            when multiplying =>
                if count <  MULT_LATENCY then
                    count <= count + 1;
                else
                    gain_o(0) <= resize(shift_right(signed(gain_slv(0)),16),GAIN_WIDTH);
                    gain_o(1) <= resize(shift_right(signed(gain_slv(1)),16),GAIN_WIDTH);
                    valid_o <= '1';
                    state <= idle;
                end if;
                    
            when others => null;
        end case;
    end if;
end process;

end architecture Behavioural;