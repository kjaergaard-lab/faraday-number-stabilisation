classdef DPFeedbackParameter < handle
    properties
        addr
        bits
        value
    end
    
    properties(Constant)
        ADDR_OFFSET = hex2dec('40000000');
    end
    
    methods
        function self = DPFeedbackParameter(addr,bits)
            self.addr = addr;
            self.bits = bits;
        end
        
        function set.addr(self,addr)
            if addr<0 || addr>hex2dec('3fffffff')
                error('Address is out of range [%08x,%08x]',0,hex2dec('3fffffff'));
            else
                self.addr = addr;
            end
        end
        
        function set.bits(self,bits)
            if numel(bits)~=2 || any(bits<0) || any(bits>31)
                error('Bits must be a 2-element vector with values in [0,31]');
            else
                self.bits = bits;
            end  
        end
        
        
        
    end
    
end