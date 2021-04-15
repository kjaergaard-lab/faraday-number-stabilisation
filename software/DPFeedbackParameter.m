classdef DPFeedbackParameter < handle
    %DPFEEDBACKPARAMETER Defines a class representing a feedback parameter.
    %Has limit checking abilities, can convert between physical values and
    %integer values, and parameters can span multiple registers.
    properties
        bits                %Bit range that parameter occupies
        upperLimit          %Upper limit on value
        lowerLimit          %Lower limit on value
    end
    
    properties(SetAccess = protected)
        regs                %Registers that the parameter spans
        value               %Human-readable value in real units
        intValue            %Integer value written for FPGA
        toIntegerFunction   %Function converting real values to integer values
        fromIntegerFunction %Function converting integer values to real values
    end
    
    methods
        function self = DPFeedbackParameter(bits,regIn)
            %DPFEEDBACKPARAMETER Creates an instance of the
            %DPFeedbackParameter class.
            %
            %   P = DPFEEDBACKPARAMETER(BITS,REGIN) Creates an instance P
            %   with bit range BITS and registers REGIN.
            %
            %   If numel(REGIN) > 1, then the size of BITS is size(BITS) =
            %   [numel(REGIN),2]
            %
            %   The default integer conversion functions are just a
            %   straight mapping @(x) x
            self.bits = bits;
            self.regs = regIn;
            if size(self.bits,1) ~= numel(self.regs)
                error('Number of registers must be the same as the number of bit ranges');
            end
            
            self.toIntegerFunction = @(x) x;
            self.fromIntegerFunction = @(x) x;
        end
        
        function set.bits(self,bits)
            %SET.BITS Sets the bit ranges
            %
            %   SET.BITS(BITS) sets the bit range to BITS where BITS must
            %   be an Nx2 matrix where N is the number of registers. Any
            %   value of BITS must be in the range [0,31]
            if mod(numel(bits),2)~=0 || any(bits(:)<0) || any(bits(:)>31) || size(bits,2)>2
                error('Bits must be a 2-element vector with values in [0,31] or an Nx2 matrix with values in [0,31]');
            else
                if numel(bits)==2
                    self.bits = bits(:)';
                else
                    self.bits = bits;
                end
            end  
        end
        
        function N = numbits(self)
            %NUMBITS Returns the total number of bits occupied by this
            %parameter
            %
            %   N = P.NUMBITS() returns the total number of bits N
            N = sum(abs(diff(self.bits,1,2)),1)+1;
        end
        
        function self = setFunctions(self,varargin)
            %SETFUNCTIONS Sets the toInteger and fromInteger functions for
            %converting physical values to integer values
            %
            %   P = P.SETFUNCTIONS(TYPE,FUNC,<TYPE2,FUNC2>) sets the
            %   integer conversion functions with TYPE or optional TYPE2
            %   are either 'to' or 'from'.  FUNC and optional FUNC2 are the
            %   conversion functions converting a physical value TO an
            %   integer value (for TYPE 'to') or FROM an integer value to a
            %   physical value (for TYPE 'from')
            
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
            %
            %   P = P.SETLIMITS(TYPE,LIMIT,<TYPE2,LIMIT2>) sets the limits
            %   for parameter P.  TYPE and optional TYPE2 are one of
            %   'upper' or 'lower', and LIMIT and optional LIMIT2 are the
            %   upper and lower limits for their respective TYPE arguments
            
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
            %
            %   R = P.toInteger(varargin) invokes the toIntegerFunction for
            %   parameter P to convert a physical value to an integer with
            %   possible variable arguments.
            r = obj.toIntegerFunction(varargin{:});
            try
                r = round(r);
            catch
                
            end
        end
        
        function r = fromInteger(obj,varargin)
            %FROMINTEGER Converts the arguments from an integer
            %
            %   R = P.FROMINTEGER(varargin) invokes the fromIntegerFunction
            %   for parameter P to convert an integer value to a physical
            %   value with possible variable arguments.
            r = obj.fromIntegerFunction(varargin{:});
        end
        
        function self = checkLimits(self,v)
            %CHECKLIMITS Checks the limits on the set value
            %
            %   P = P.CHECKLIMITS(V) checks if value V is within the limits
            %   of the parameter P
            if ~isempty(self.lowerLimit) && isnumeric(self.lowerLimit) && (v < self.lowerLimit)
                error('Value is lower than the lower limit!');
            end
            
            if ~isempty(self.upperLimit) && isnumeric(self.upperLimit) && (v > self.upperLimit)
                error('Value is higher than the upper limit!');
            end
            
        end
        
        function self = set(self,v,varargin)
            %SET Sets the physical value of the parameter and converts it
            %to an integer as well. Also sets the value of associated
            %registers according to the associated bit ranges
            %
            %   P = P.SET(V,VARARGIN) sets the value of parameter P to V
            %   with possible variable arguments VARARGIN for the
            %   TOINTEGERFUNCTION function. Register values are also set in
            %   this call
            self.checkLimits(v);
            tmp = self.toInteger(v,varargin{:});
            if log2(double(tmp)) > self.numbits
                error('Value will not fit in bit range with %d bits',self.numbits);
            end
            self.value = v;
            self.intValue = tmp;
            if islogical(self.intValue)
                self.intValue = uint32(self.intValue);
            end
            
            if numel(self.regs) == 1
                self.regs.set(self.intValue,self.bits);
            else
                tmp = uint64(self.intValue);
                for nn=1:numel(self.regs)
                    self.regs(nn).set(tmp,self.bits(nn,:));
                    tmp = bitshift(tmp,-abs(diff(self.bits(nn,:)))-1);
                end
            end
        end
        
        function r = get(self,varargin)
            %GET Gets the physical value of the parameter from the integer
            %value
            %
            %   R = P.GET(VARARGIN) Retrieves the physical value R from the
            %   value contained in the stored registers using possible
            %   variable arguments VARARGIN for FROMINTEGERFUNCTION.
            if numel(self.regs) == 1
                self.intValue = self.regs.get(self.bits);
            else
                tmp = uint64(0);
                for nn=numel(self.regs):-1:2
                    tmp = tmp+bitshift(uint64(self.regs(nn).get(self.bits(nn,:))),abs(diff(self.bits(nn-1,:)))+1);
                end
                tmp = tmp+uint64(self.regs(1).get(self.bits(1,:)));
                self.intValue = tmp;
            end
            self.value = self.fromInteger(double(self.intValue),varargin{:});
            r = self.value;
        end
        
        function self = read(self)
            %READ Reads the parameter from the device
            %
            %   P = P.READ() Reads the value of parameter P from the device
            %   via the register READ() functions
            if numel(self) == 1
                self.regs.read;
                self.get;
            else
                for nn=1:numel(self)
                    self(nn).read;
                end
            end
        end
        
        function self = write(self)
            %WRITE Writes the parameter to the device
            %
            %   P = P.WRITE() Writes the current value of the parameter
            %   to the device via the register WRITE() functions
            if numel(self) == 1
                self.regs.write;
            else
                for nn=1:numel(self)
                    self(nn).write;
                end
            end
        end
        
        function disp(self)
            %DISP Displays information about the current
            %DPFeedbackParameter instance
            if numel(self) == 1
                fprintf(1,'\t DBFeedbackParameter with properties:\n');
                if size(self.bits,1) == 1
                    fprintf(1,'\t\t            Bit range: [%d,%d]\n',self.bits(1),self.bits(2));
                else
                    for nn=1:size(self.bits,1)
                        fprintf(1,'\t\t  Bit range for reg %d: [%d,%d]\n',nn-1,self.bits(nn,1),self.bits(nn,2)); 
                    end
                end
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
            else
                for nn=1:numel(self)
                    self(nn).disp();
                    fprintf(1,'\n');
                end
            end
        end
        
    end
    
end