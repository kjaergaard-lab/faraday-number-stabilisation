classdef DPFeedbackRegister < handle
    properties
        addr
        value
    end
    
    properties(Access = protected)
        conn
    end
    
    properties(Constant)
        ADDR_OFFSET = uint32(hex2dec('40000000'));
        MAX_ADDR = uint32(hex2dec('3fffffff'));
    end
    
    methods
        function self = DPFeedbackRegister(addr,conn)
            self.addr = addr;
            self.value = uint32(0);
            if nargin>1
                self.conn = conn;
            end
        end
    
        function set.addr(self,addr)
            if ischar(addr)
                addr = hex2dec(addr);
            end

            if addr<0 || addr>self.MAX_ADDR
                error('Address is out of range [%08x,%08x]',0,self.MAX_ADDR);
            else
                self.addr = addr;
            end
        end
        
        function self = set(self,v,bits)
            tmp = self.value;
            mask = intmax('uint32');
            mask = bitshift(bitshift(mask,bits(2)-bits(1)+1-32),bits(1));
            v = bitshift(uint32(v),bits(1));
            self.value = bitor(bitand(tmp,bitcmp(mask)),v);
        end
        
        function v = get(self,bits)
            mask = intmax('uint32');
            mask = bitshift(bitshift(mask,bits(2)-bits(1)+1-32),bits(1));
            v = bitshift(bitand(self.value,mask),-bits(1));
        end
        
        function self = write(self)
            %write to connection...
        end
        
        function self = read(self)
            %read from connection
        end
    
    end
    
end