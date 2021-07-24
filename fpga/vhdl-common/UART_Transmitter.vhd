library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--
-- Sends a data word to another device using UART protocol using a baud rate set by generic constant
-- Sends all data in a single stream with one start bit and two stop bits
--
entity UART_Transmitter is
	generic(BAUD_PERIOD	:	natural;									--Baud period
	        NUM_BITS    :   natural);
	
	port(	clk 		: 	in 	std_logic;								--Clock signal
			dataIn		:	in	std_logic_vector(NUM_BITS-1 downto 0);	--32-bit word to be sent
			trigIn		:	in	std_logic;								--Trigger to send data
			TxD			:	out	std_logic;								--Serial transmit port
			baudTickOut	:	out	std_logic;								--Output for baud ticks for testing
			busy		:	out	std_logic);								--Busy signal is high when transmitting
end UART_Transmitter;

architecture Behavioral of UART_Transmitter is


signal state		:	integer range 0 to 3	:=	0;
signal bitCount	    :	integer range 0 to NUM_BITS+5	:=	0;
signal data			:	std_logic_vector(NUM_BITS+2 downto 0) := (others => '0');
signal count		:	integer range 0 to BAUD_PERIOD	:=	0;

begin

SendData: process(clk) is
begin
	if rising_edge(clk) then
		SendFSM: case state is
			--
			-- Idle state.  When a trigger is received, the busy signal is raised
			-- and the data to be sent is latched into an internal signal
			--
			when 0 =>
				if trigIn = '1' then
					bitCount <= 0;
					count <= 0;
					data <= "11" & dataIn & "0";
					state <= 2;	--Immediately send the first bit
					busy <= '1';
				else
					TxD <= '1';	--Idle signal for UART TxD is high
					busy <= '0';
				end if;
				
			--
			-- Baud counter
			--
			when 1 =>
				if count < BAUD_PERIOD then
					count <= count + 1;
					baudTickOut <= '0';
				else
					baudTickOut <= '1';
					state <= 2;
					count <= 0;
				end if;
				
			--
			-- Send data
			--
			when 2 =>
				TxD <= data(bitCount);
				if bitCount < NUM_BITS+2 then
				    bitCount <= bitCount + 1;
				    state <= 1;
                else
                    bitCount <= 0;
                    state <= 0;
                end if;
--				if bitCount >= (NUM_BITS - 1) then
--					bitCount <= 0;
--					state <= 0;
--				else
--					bitCount <= bitCount + 1;
--					state <= 1;
--				end if;
		
			when others => null;
		end case;
	end if;
end process;


end Behavioral;

