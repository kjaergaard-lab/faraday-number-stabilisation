classdef DPFeedbackRegister < handle
    %DPFEEDBACKREGISTER Defines a class that represents registers in the
    %feedback design.
    properties(SetAccess = protected)
        addr    %Register address as an unsigned 32 bit value
        value   %Register value as an unsigned 32 bit value
        conn    %Socket server connection as DPFeedbackClient instance
    end
    
    properties(Constant)
        ADDR_OFFSET = uint32(hex2dec('40000000'));  %Offset of address
        MAX_ADDR = uint32(hex2dec('3fffffff'));     %Maximum register address
    end
    
    methods
        function self = DPFeedbackRegister(addr,conn)
            %DPFEEDBACKREGISTER Creates an instance of DPFeedbackRegister
            %
            %   REG = DPFEEDBACKREGISTER(ADDR) creates an instance of
            %   DPFeedbackRegister REG with address ADDR
            %
            %   REG = DPFEEDBACKREGISTER(ADDR,CONN) creates an instance
            %   with address ADDR and associated connection CONN
            self.setAddr(addr);
            self.value = uint32(0);
            if nargin>1
                self.setConn(conn);
            end
        end
    
        function setAddr(self,addr)
            %SETADDR Sets the register address
            %
            %   SETADDR(ADDR) Sets the register address to ADDR
            if ischar(addr)
                addr = hex2dec(addr);
            end

            if addr<0 || addr>self.MAX_ADDR
                error('Address is out of range [%08x,%08x]',0,self.MAX_ADDR);
            else
                self.addr = uint32(addr);
            end
        end
        
        function setConn(self,conn)
            %SETCONN Sets the connection property
            %
            %   SETCONN(CONN) Sets the connection property to CONN if CONN
            %   is an instance of DPFeedbackClient
            if isa(conn,'DPFeedbackClient')
                self.conn = conn;
            else
                error('Input must be an instance of DPFeedbackClient!');
            end
        end
        
        function self = set(self,v,bits)
            %SET Sets a specified bit range to a given value
            %
            %   SET(V,BITS) sets the zero-indexed bit range BITS to the
            %   value given by V
            tmp = self.value;
            mask = intmax('uint32');
            mask = bitshift(bitshift(mask,bits(2)-bits(1)+1-32),bits(1));
            v = bitshift(uint32(v),bits(1));
            self.value = bitor(bitand(tmp,bitcmp(mask)),v);
        end
        
        function v = get(self,bits)
            %GET Returns the value specified by a given bit range
            %
            %   GET(BITS) returns the value represented by the zero-indexed
            %   bit range BITS
            mask = intmax('uint32');
            mask = bitshift(bitshift(mask,bits(2)-bits(1)+1-32),bits(1));
            v = bitshift(bitand(self.value,mask),-bits(1));
        end
        
        function self = write(self)
            %WRITE Writes the register value to the device via the
            %socket connection. Returns the object.
            if numel(self) == 1
                data = [self.addr,self.value];
                self.conn.write(data,'mode','write');
            else
                for nn=1:numel(self)
                    self(nn).write;
                end
            end
        end
        
        function self = read(self)
            %READ Reads the register value from the device via the socket
            %connection. Returns the object
            if numel(self) == 1
                self.conn.write(self.addr,'mode','read');
                self.value = self.conn.recvMessage;
            else
                for nn=1:numel(self)
                    self(nn).read;
                end
            end
        end
        
        function makeString(self,label,width)
            %MAKESTRING Prints a string giving the current register status
            %
            %   MAKESTRING(LABEL,WIDTH) prints a string with the label
            %   LABEL and total width WIDTH
            if numel(self) == 1
                labelWidth = length(label);
                numSpaces = width-8-2-labelWidth;
                if numSpaces == 0
                    padding = '';
                else
                    padding = repmat(' ',1,numSpaces);
                end
                fprintf(1,'\t\t%s%s: %08x\n',padding,label,self.value);
            else
                for nn=1:numel(self)
                    labelNew = sprintf('%s(%d)',label,nn-1);
                    self(nn).makeString(labelNew,width);
                end
            end
        end
    
    end
    
end