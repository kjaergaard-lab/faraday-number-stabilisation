library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 
use work.CustomDataTypes.all;
use work.AXI_Bus_Package.all;

entity UART_Receiver_tb is
--  Port ( );
end UART_Receiver_tb;

architecture Behavioral of UART_Receiver_tb is

component UART_Receiver is
	generic(BAUD_PERIOD    : natural;								--Baud period in clock cycles
	        NUM_BITS       : natural);
	port(	clk 		   : in  std_logic;							--Clock signal
	        aresetn        : in  std_logic;
            data_o         : out std_logic_vector(NUM_BITS-1 downto 0);	--Output data
			valid_o	       : out std_logic;							--Signal to register the complete read of a byte
			RxD			   : in	 std_logic);							--Output baud tick, used for debugging
end component;

component UART_Transmitter is
	generic(BAUD_PERIOD	:	natural;									--Baud period
	        NUM_BITS    :   natural);
	
	port(	clk 		: 	in 	std_logic;								--Clock signal
			dataIn		:	in	std_logic_vector(NUM_BITS-1 downto 0);	--32-bit word to be sent
			trigIn		:	in	std_logic;								--Trigger to send data
			TxD			:	out	std_logic;								--Serial transmit port
			baudTickOut	:	out	std_logic;								--Output for baud ticks for testing
			busy		:	out	std_logic);								--Busy signal is high when transmitting
end component;

constant clkPeriod  :   time    :=  10 ns;
constant NUM_BITS   :   natural :=  24;
constant BAUD_PERIOD:   natural :=  12;

signal clk, aresetn,valid_o,RxD, trig_i,TxD  :   std_logic  :=  '0';

signal data, data_o :   std_logic_vector(NUM_BITS-1 downto 0)   :=  (others => '0');
signal count    :   unsigned(7 downto 0)    :=  (others => '0');

type t_data_array is array (integer range <>) of std_logic_vector(NUM_BITS-1 downto 0);

--constant SER_DATA :   t_data_array(



begin

uut: UART_Receiver
generic map(
    BAUD_PERIOD =>  BAUD_PERIOD,
    NUM_BITS    =>  NUM_BITS
)
port map(
    clk         =>  clk,
    aresetn     =>  aresetn,
    data_o      =>  data,
    valid_o     =>  valid_o,
    RxD         =>  RxD
);

trans: UART_Transmitter
generic map(
    BAUD_PERIOD =>  BAUD_PERIOD,
    NUM_BITS    =>  NUM_BITS
)
port map(
    clk         =>  clk,
    dataIn      =>  data_o,
    trigIn      =>  trig_i,
    TxD         =>  RxD,
    baudTickOut =>  open,
    busy        =>  open
);

-- Clock process definitions
clk_process :process
begin
	clk <= '0';
	wait for clkPeriod/2;
	clk <= '1';
	wait for clkPeriod/2;
end process;


tb: process is
begin
    aresetn <= '0';
    data_o <= X"aaaaaa";
    trig_i <= '0';
    wait for 100 ns;
    aresetn <= '1';
    wait until clk'event and clk = '1';
    trig_i <= '1';
    wait until clk'event and clk = '1';
    trig_i <= '0';
    
    wait for 100*clkPeriod;
    wait;
end process;

end Behavioral;
