library IEEE;
use ieee.std_logic_1164.all; 
use ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all; 

--
-- This package contains both constants and functions used for
-- servo control.
--
package CustomDataTypes is

subtype t_param_reg is std_logic_vector(31 downto 0);
subtype t_adc_combined is std_logic_vector(31 downto 0);

--
-- Defines AXI address and data widths
--
constant MEM_ADDR_WIDTH :   natural :=  14;
constant MEM_DATA_WIDTH :   natural :=  32;

--
-- Defines MEM address and data signals
--
subtype t_mem_addr is unsigned(MEM_ADDR_WIDTH-1 downto 0);
subtype t_mem_data is std_logic_vector(MEM_DATA_WIDTH-1 downto 0);

type t_status is (idle,waiting,reading,writing,processing,running,finishing);

--
-- Defines data buses for handling block memories
--
type t_mem_bus_master is record
    addr    :   t_mem_addr;
    trig    :   std_logic;
    reset   :   std_logic;
    status  :   t_status;
end record t_mem_bus_master;

type t_mem_bus_slave is record
    data    :   t_mem_data;
    valid   :   std_logic;
    last    :   t_mem_addr;
    status  :   t_status;
end record t_mem_bus_slave;

type t_mem_bus is record
    m   :   t_mem_bus_master;
    s   :   t_mem_bus_slave;
end record t_mem_bus;

type t_mem_bus_master_array is array(natural range <>) of t_mem_bus_master;
type t_mem_bus_slave_array is array(natural range <>) of t_mem_bus_slave;

--
-- Define initial values
--
constant INIT_MEM_BUS_MASTER    :  t_mem_bus_master :=  (addr   =>  (others => '0'),
                                                         trig   =>  '0',
                                                         reset  =>  '0',
                                                         status =>  idle);
constant INIT_MEM_BUS_SLAVE     :   t_mem_bus_slave :=  (data   =>  (others => '0'),
                                                         valid  =>  '0',
                                                         last   =>  (others => '0'),
                                                         status =>  idle);
constant INIT_MEM_BUS           :   t_mem_bus       :=  (m  =>  INIT_MEM_BUS_MASTER,
                                                         s  =>  INIT_MEM_BUS_SLAVE);

--constant INIT_MEM_BUS_MASTERS   :   t_mem_bus_master_array  :=  (others => INIT_MEM_BUS_MASTER);                                                         
--constant INIT_MEM_BUS_SLAVES    :   t_mem_bus_slave_array   :=  (others => INIT_MEM_BUS_SLAVE);
	
end CustomDataTypes;

--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
package body CustomDataTypes is

end CustomDataTypes;
