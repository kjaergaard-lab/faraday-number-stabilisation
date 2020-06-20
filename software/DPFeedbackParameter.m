classdef DPFeedbackParameter < handle
    properties
        bits
        upperLimit  %Upper limit on value
        lowerLimit  %Lower limit on value
    end
    
    properties(SetAccess = protected)
        reg
        value               %Human-readable value in real units
        intValue            %Integer value written for FPGA
        toIntegerFunction   %Function converting real values to integer values
        fromIntegerFunction %Function converting integer values to real values
    end
    
    methods
        function self = DPFeedbackParameter(bits,regIn)
            self.bits = bits;
            self.reg = regIn;
        end
        
        function set.bits(self,bits)
            if numel(bits)~=2 || any(bits<0) || any(bits>31)
                error('Bits must be a 2-element vector with values in [0,31]');
            else
                self.bits = bits;
            end  
        end
        
        function self = setFunctions(self,varargin)
            %SETFUNCTIONS Sets the toInteger and fromInteger functions for
            %converting physical values to integer values
            
            %Check register inputs
            if mod(numel(varargin),2)~=0
                error('You must specify functions as name/value pairs!');
            end
            
            for nn=1:2:numel(varargin)
                if ~isa(varargin{nn+1},'function_handle')
                    error('Functions must be passed as function handles!');
                end
                s = lower(varargin{nn});
                switch s
                    case 'to'
                        self.toIntegerFunction = varargin{nn+1};
                    case 'from'
                        self.fromIntegerFunction = varargin{nn+1};
                end
            end
        end
        
        function self = setLimits(self,varargin)
            %SETLIMITS Sets the upper and lower limits on the physical
            %value
            
            %Check register inputs
            if mod(numel(varargin),2)~=0
                error('You must specify functions as name/value pairs!');
            end
            
            for nn=1:2:numel(varargin)
                s = lower(varargin{nn});
                switch s
                    case 'lower'
                        self.lowerLimit = varargin{nn+1};
                    case 'upper'
                        self.upperLimit = varargin{nn+1};
                end
            end
        end
        
        function r = toInteger(obj,varargin)
            %TOINTEGER Converts the arguments to an integer
            r = obj.toIntegerFunction(varargin{:});
            try
                r = round(r);
            catch
                
            end
        end
        
        function r = fromInteger(obj,varargin)
            %FROMINTEGER Converts the arguments from an integer
            r = obj.fromIntegerFunction(varargin{:});
        end
        
        function self = checkLimits(self,v)
            %CHECKLIMITS Checks the limits on the set value
            if ~isempty(self.lowerLimit) && isnumeric(self.lowerLimit) && (v < self.lowerLimit)
                error('Value is lower than the lower limit!');
            end
            
            if ~isempty(self.upperLimit) && isnumeric(self.upperLimit) && (v > self.upperLimit)
                error('Value is higher than the upper limit!');
            end
            
            if log2(v) > abs(diff(self.bits)+1)
                error('Value will not fit in bit-range [%d,%d]',self.bits(1),self.bits(1));
            end
            
        end
        
        function self = set(self,v,varargin)
            %SET Sets the physical value of the parameter and converts it
            %to an integer as well
            self.checkLimits(v);
            tmp = self.toInteger(v,varargin{:});
            if tmp > 2^(abs(diff(self.bits)+1))
                error('Value will not fit in bit-range [%d,%d]',self.bits(1),self.bits(1));
            end
            self.value = v;
            self.intValue = tmp;
            if islogical(self.intValue)
                self.intValue = uint32(self.intValue);
            end
            self.reg.set(self.intValue,self.bits);
        end
        
        function r = get(self,varargin)
            %GET Gets the physical value of the parameter from the integer
            %value
            self.intValue = self.reg.get(self.bits);
            self.value = self.fromInteger(double(self.intValue),varargin{:});
            r = self.value;
        end
        
        function self = read(self)
            self.reg.read;
            self.get;
        end
        
        function self = write(self)
            self.reg.write;
        end
        
        function disp(self)
            fprintf(1,'\t DBFeedbackParameter with properties:\n');
            fprintf(1,'\t\t            Bit range: [%d,%d]\n',self.bits(1),self.bits(2));
            if isnumeric(self.value) && numel(self.value)==1
                fprintf(1,'\t\t       Physical value: %.4g\n',self.value);
            elseif isnumeric(self.value) && numel(self.value)<=10
                fprintf(1,'\t\t       Physical value: [%s]\n',strtrim(sprintf('%.4g ',self.value)));
            elseif isnumeric(self.value) && numel(self.value)>10
                fprintf(1,'\t\t       Physical value: [%dx%d %s]\n',size(self.value),class(self.value));
            elseif ischar(self.value)
                fprintf(1,'\t\t       Physical value: %s\n',self.value);
            end
            if numel(self.intValue)==1
                fprintf(1,'\t\t        Integer value: %d\n',self.intValue);
            elseif numel(self.value)<=10
                fprintf(1,'\t\t        Integer value: [%s]\n',strtrim(sprintf('%d ',self.intValue)));
            elseif numel(self.value)>10
                fprintf(1,'\t\t        Integer value: [%dx%d %s]\n',size(self.value),class(self.value));
            end
            if ~isempty(self.lowerLimit) && isnumeric(self.lowerLimit)
                fprintf(1,'\t\t          Lower limit: %.4g\n',self.lowerLimit);
            end
            if ~isempty(self.upperLimit) && isnumeric(self.upperLimit)
                fprintf(1,'\t\t          Upper limit: %.4g\n',self.upperLimit);
            end
            
            if ~isempty(self.toIntegerFunction)
                fprintf(1,'\t\t   toInteger Function: %s\n',func2str(self.toIntegerFunction));
            end
            if ~isempty(self.fromIntegerFunction)
                fprintf(1,'\t\t fromInteger Function: %s\n',func2str(self.fromIntegerFunction));
            end
        end
        
    end
    
end