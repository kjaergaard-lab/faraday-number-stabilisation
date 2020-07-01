library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--
-- Reads one data word NUM_BITS long from serial with baud period BAUD_PERIOD
-- Assumes that there is 1 start bit, 1 stop bit, and no parity bits
--
entity UART_Receiver is
	generic(BAUD_PERIOD    : natural;								--Baud period in clock cycles
	        NUM_BITS       : natural);
	port(	clk 		   : in  std_logic;							--Clock signal
	        aresetn        : in  std_logic;
            data_o         : out std_logic_vector(NUM_BITS-1 downto 0);	--Output data
			valid_o	       : out std_logic;							--Signal to register the complete read of a byte
			RxD			   : in	 std_logic);							--Output baud tick, used for debugging
end UART_Receiver;

architecture Behavioral of UART_Receiver is

type t_state_local is (idle,firstwait,waiting,reading,finishing);

signal bitCount	    :	integer range 0 to NUM_BITS+1	:= 0;
signal state		:	t_state_local   :=  idle;
signal syncRxD		:	std_logic_vector(1 downto 0) := (others => '1');
signal data         :   std_logic_vector(data_o'length-1 downto 0);

signal count		:	integer range 0 to BAUD_PERIOD		:= 0;

begin

Sync:process(clk,aresetn) is
begin
    if aresetn = '0' then
        syncRxD <= "11";
    elsif rising_edge(clk) then
        syncRxD <= syncRxD(0) & RxD;
    end if;
end process;


ReceiveData: process(clk,aresetn) is
begin
    if aresetn = '0' then
        valid_o <= '0';
        data <= (others => '0');
        data_o <= (others => '0');
        count <= 0;
        state <= idle;
	elsif rising_edge(clk) then
		UART_FSM: case state is
			--
			-- Idling state.  Waits for 4 consecutive low values of
			-- the RxD signal before deciding that a signal is being
			-- transmitted.
			--
			when idle =>
				bitCount <= 0;
				valid_o <= '0';
				count <= 0;
				if syncRxD = "10" then
					state <= firstwait;
				end if;
				
            --
            -- Wait 0.5 BAUD_PERIOD so that first bit is registered
            -- in the middle of the BAUD_PERIOD
            --
            when firstwait =>
                if count < BAUD_PERIOD/2 then
					count <= count + 1;
				else
					count <= 0;
					state <= waiting;
				end if;
				
			--
			-- Wait a full period. Baud ticks appear in the middle of bits
			--
			when waiting =>
				if count < BAUD_PERIOD then
					count <= count + 1;
				else
					count <= 0;
					state <= reading;
				end if;
				
			--
			-- Read bit
			--
			when reading =>
				if bitCount < NUM_BITS-1 then
					data(bitCount) <= RxD;	--read bit in
					bitCount <= bitCount + 1;
					state <= waiting;						--Return to delay loop
					count <= 0;
				else
				    data(bitCount) <= RxD;	--read bit in
					bitCount <= 0;				--reset bit count
					state <= finishing;
				end if;
				
            --
            -- Issue valid signal
            --
            when finishing =>
                valid_o <= '1';
                data_o <= data;
                state <= idle;
			
			when others => null;
		end case;
	
	end if;
end process;


end Behavioral;

