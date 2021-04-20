classdef DPFeedback < handle
    %DPFEEDBACK Defines a class for handling control of the dispersive
    %feedback design
    properties
        signal              %An instance of DPFeedbackData representing signal data
        aux                 %An instance of DPFeedbackData representing auxiliary data
        
        gains               %DEPRECATED
        sum                 %Calculated SxSy' - Sx'Sy data
        diff                %Calculated SxSy' + Sx'Sy data
        ratio               %Retrieved ratio data
        t                   %Time data for the ratio data
    end
    
    properties(SetAccess = immutable)
        conn                %Instance of DPFeedbackClient used for communication with socket server
        
        enableDP            %Enables dispersive pulses
        enableFB            %Enables number feedback using microwaves
        useFixedGain        %DEPRECATED
        enableManualMW      %Enables the use of manual microwave pulses
        dpOnShutterOff      %Keeps the signal AOM on when the shutter closes
        auxOnShutterOff     %Keeps the auxiliary AOM on when the shutter closes
        
        width               %Dispersive pulse width
        numpulses           %Number of dispersive pulses
        period              %Dispersive pulse period
        shutterDelay        %Delay between when the trigger is registered and signal pulses start
        auxDelay            %Delay between when the trigger is registered and auxiliary pulses start
        
        delaySignal         %Delay between when a signal pulse is generated and data is acquired
        delayAux            %Delay between when an auxiliary pulse is generated and data is acquired
        samplesPerPulse     %Number of samples to acquire per pulse
        log2Avgs            %Log2(number of averages to use in quickly averaging signals)
        
        sumStart            %Sample at which to start summing data
        subStart            %Sample at which to start subtracting data
        sumWidth            %Number of samples to use for summation/subtraction
        offsets             %Offset values to use instead of using the data
        usePresetOffsets    %Use present offests (above) or subtract offsets using data when no light is present?
        
        auxMultipliers      %DEPRECATED
        presetGains         %DEPRECATED
        
        maxMWPulses         %Maximum number of microwave pulses to use for each round of feedback
        target              %Target ratio value for feedback
        tol                 %Tolerance value below which feedback stops
        
        mwNumPulses         %Manual number of microwave pulses
        mwPulseWidth        %Pulse width for microwave pulses
        mwPulsePeriod       %Pulse period for microwave pulses
        
        samplesCollected    %Read-only parameter indicating number of raw samples collected. Array of 2 elements
        pulsesCollected     %Read-only parameter indicating number of pulses collected. Array of 3 elements
        
        manualFlag          %Enables manual control for testing
        pulseDPMan          %Turns the signal pulse on/off
        shutterDPMan        %Turns the shutter on/off
        pulseMWMan          %Turns the microwave pulse on/off
        auxMan              %Turns the auxiliary pulse on/off
    end
    
    properties(SetAccess = protected)
        trigReg             %Register for software trigger signals
        sharedReg           %Register for shared top-level parameters
        pulseRegs           %Registers for pulse parameters
        avgRegs             %Registers for computing quick averages
        integrateRegs       %Registers for integrating data
        gainComputeReg      %DEPRECATED
        signalComputeRegs   %Register for computing ratio value
        fbComputeRegs       %Register for handling feedback computation
        fbPulseRegs         %Register for microwave feedback pulse parameters
        
        sampleRegs          %Registers for determining number of raw samples collected
        pulsesRegs          %Registers for determining number of pulses collected
    end
    
    properties(Constant)
        CLK = 125e6;                    %Clock frequency of the board
        MAX_SUM_RANGE = 2^11-1;         %Maximum number of points for integration
        HOST_ADDRESS = '172.22.250.94'; %Default socket server address
    end
    
    methods
        function self = DPFeedback(varargin)
            %DPFEEDBACK Creates an instance of a DPFeedback object.  Sets
            %up the registers and parameters as instances of the correct
            %classes with the necessary
            %addressses/registers/limits/functions
            %
            %   FB = DPFEEDBACK(HOST) creates an instance with socket
            %   server host address HOST
            if numel(varargin)==1
                self.conn = DPFeedbackClient(varargin{1});
            else
                self.conn = DPFeedbackClient(self.HOST_ADDRESS);
            end
            
            self.signal = DPFeedbackData;
            self.aux = DPFeedbackData;
            self.sum = [];
            self.diff = [];
            
            % R/W registers
            self.trigReg = DPFeedbackRegister('0',self.conn);
            self.sharedReg = DPFeedbackRegister('4',self.conn);
            self.pulseRegs = DPFeedbackRegister('8',self.conn);
            self.pulseRegs(2) = DPFeedbackRegister('C',self.conn);
            self.pulseRegs(3) = DPFeedbackRegister('10',self.conn);
            self.pulseRegs(4) = DPFeedbackRegister('14',self.conn);
            self.avgRegs = DPFeedbackRegister('18',self.conn);
            self.avgRegs(2) = DPFeedbackRegister('1C',self.conn);
            self.integrateRegs = DPFeedbackRegister('20',self.conn);
            self.integrateRegs(2) = DPFeedbackRegister('24',self.conn);
            self.gainComputeReg = DPFeedbackRegister('28',self.conn);
            self.signalComputeRegs = DPFeedbackRegister('2C',self.conn);
            self.signalComputeRegs(2) = DPFeedbackRegister('30',self.conn);
            self.fbComputeRegs = DPFeedbackRegister('34',self.conn);
            self.fbComputeRegs(2) = DPFeedbackRegister('38',self.conn);
            self.fbPulseRegs = DPFeedbackRegister('3C',self.conn);
            self.fbPulseRegs(2) = DPFeedbackRegister('40',self.conn);
            
            % Read-only registers
            self.sampleRegs = DPFeedbackRegister('01000000',self.conn);
            self.pulsesRegs = DPFeedbackRegister('01000004',self.conn);
            self.sampleRegs(2) = DPFeedbackRegister('01000008',self.conn);
            self.pulsesRegs(2) = DPFeedbackRegister('0100000C',self.conn);
            self.pulsesRegs(3) = DPFeedbackRegister('01000010',self.conn);
            
            %Shared registers
            self.enableDP = DPFeedbackParameter([0,0],self.sharedReg)...
                .setLimits('lower',0,'upper',1);
            self.enableFB = DPFeedbackParameter([1,1],self.sharedReg)...
                .setLimits('lower',0,'upper',1);
            self.useFixedGain = DPFeedbackParameter([2,2],self.sharedReg)...
                .setLimits('lower',0,'upper',1);
            self.enableManualMW = DPFeedbackParameter([3,3],self.sharedReg)...
                .setLimits('lower',0,'upper',1);
            self.dpOnShutterOff = DPFeedbackParameter([4,4],self.sharedReg)...
                .setLimits('lower',0,'upper',1);
            self.auxOnShutterOff = DPFeedbackParameter([5,5],self.sharedReg)...
                .setLimits('lower',0,'upper',1);

            %Pulse generation
            self.width = DPFeedbackParameter([0,15],self.pulseRegs(1))...
                .setLimits('lower',100e-9,'upper',10e-3)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            self.numpulses = DPFeedbackParameter([16,31],self.pulseRegs(1))...
                .setLimits('lower',0,'upper',2^16-1)...
                .setFunctions('to',@(x) round(x),'from',@(x) x);
            self.period = DPFeedbackParameter([0,31],self.pulseRegs(2))...
                .setLimits('lower',500e-9,'upper',10)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            self.shutterDelay = DPFeedbackParameter([0,31],self.pulseRegs(3))...
                .setLimits('lower',0,'upper',10)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            self.auxDelay = DPFeedbackParameter([0,31],self.pulseRegs(4))...
                .setLimits('lower',0,'upper',10)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            
            %Initial processing
            self.delaySignal = DPFeedbackParameter([0,13],self.avgRegs(1))...
                .setLimits('lower',0,'upper',100e-6)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            self.delayAux = DPFeedbackParameter([0,13],self.avgRegs(2))...
                .setLimits('lower',0,'upper',100e-6)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            self.samplesPerPulse = DPFeedbackParameter([14,27],self.avgRegs(1))...
                .setLimits('lower',0,'upper',2^14-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.log2Avgs = DPFeedbackParameter([28,31],self.avgRegs(1))...
                .setLimits('lower',0,'upper',2^4-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            
            %Secondary processing
            self.sumStart = DPFeedbackParameter([0,10],self.integrateRegs(1))...
                .setLimits('lower',0,'upper',2^11-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.subStart = DPFeedbackParameter([11,21],self.integrateRegs(1))...
                .setLimits('lower',0,'upper',2^11-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.sumWidth = DPFeedbackParameter([22,31],self.integrateRegs(1))...
                .setLimits('lower',0,'upper',2^10-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.offsets = DPFeedbackParameter([0,13],self.integrateRegs(2))...
                .setLimits('lower',-2^13,'upper',2^13)...
                .setFunctions('to',@(x) typecast(int32(round(x)),'uint32'),'from',@(x) double(typecast(uint32(x),'int32')));
            self.offsets(2) = DPFeedbackParameter([27,14],self.integrateRegs(2))...
                .setLimits('lower',-2^13,'upper',2^13)...
                .setFunctions('to',@(x) typecast(int32(round(x)),'uint32'),'from',@(x) double(typecast(uint32(x),'int32')));
            self.usePresetOffsets = DPFeedbackParameter([28,28],self.integrateRegs(2))...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            
            %Gain and signal computation
            self.auxMultipliers = DPFeedbackParameter([0,7],self.gainComputeReg)...
                .setLimits('lower',1,'upper',255)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.auxMultipliers(2) = DPFeedbackParameter([8,15],self.gainComputeReg)...
                .setLimits('lower',1,'upper',255)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.presetGains = DPFeedbackParameter([0,31],self.signalComputeRegs(1))...
                .setLimits('lower',1,'upper',2^32-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.presetGains(2) = DPFeedbackParameter([0,31],self.signalComputeRegs(2))...
                .setLimits('lower',1,'upper',2^32-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            
            %Feedback registers
            self.maxMWPulses = DPFeedbackParameter([0,15],self.fbComputeRegs(1))...
                .setLimits('lower',0,'upper',2^16-1);
            self.target = DPFeedbackParameter([16,31],self.fbComputeRegs(1))...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x*(2^16-1),'from',@(x) x/(2^16-1));
            self.tol = DPFeedbackParameter([0,15],self.fbComputeRegs(2))...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) (1+x)*self.target.get*(2^16-1),'from',@(x) x/((2^16-1)*self.target.get)-1);
            
            self.mwNumPulses = DPFeedbackParameter([16,31],self.fbPulseRegs(1))...
                .setLimits('lower',0,'upper',2^16-1);
            self.mwPulseWidth = DPFeedbackParameter([0,15],self.fbPulseRegs(1))...
                .setLimits('lower',0,'upper',(2^16-1)/self.CLK)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            self.mwPulsePeriod = DPFeedbackParameter([0,31],self.fbPulseRegs(2))...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            
            %Read-only
            self.samplesCollected = DPFeedbackParameter([0,14],self.sampleRegs(1))...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.samplesCollected(2) = DPFeedbackParameter([0,14],self.sampleRegs(2))...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.pulsesCollected = DPFeedbackParameter([0,14],self.pulsesRegs(1))...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) round(x/2));
            self.pulsesCollected(2) = DPFeedbackParameter([0,14],self.pulsesRegs(2))...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) round(x/2));
            self.pulsesCollected(3) = DPFeedbackParameter([0,14],self.pulsesRegs(3))...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            
            % Manual settings
            self.manualFlag = DPFeedbackParameter([31,31],self.sharedReg)...
                .setLimits('lower',0,'upper',1);
            self.pulseDPMan = DPFeedbackParameter([30,30],self.sharedReg)...
                .setLimits('lower',0,'upper',1);
            self.shutterDPMan = DPFeedbackParameter([29,29],self.sharedReg)...
                .setLimits('lower',0,'upper',1);
            self.pulseMWMan = DPFeedbackParameter([28,28],self.sharedReg)...
                .setLimits('lower',0,'upper',1);
            self.auxMan = DPFeedbackParameter([27,27],self.sharedReg)...
                .setLimits('lower',0,'upper',1);
        end
        
        function self = setDefaults(self,varargin)
            %SETDEFAULTS Sets parameter values to their defaults
            %
            %   FB = FB.SETDEFAULTS() sets default values for FB
            self.enableDP.set(1);
            self.enableFB.set(0);
            self.useFixedGain.set(0);
            self.enableManualMW.set(0);
            self.dpOnShutterOff.set(0);
            self.auxOnShutterOff.set(0);
            
            self.width.set(1e-6);
            self.numpulses.set(50);
            self.period.set(5e-6);
            self.shutterDelay.set(2.5e-3);
            self.auxDelay.set(2.5e-3);
            
            self.delaySignal.set(500e-9);
            self.delayAux.set(1.75e-6);
            self.samplesPerPulse.set(250);
            self.log2Avgs.set(0);
            
            self.sumStart.set(10);
            self.subStart.set(150);
            self.sumWidth.set(50);
            self.offsets(1).set(0);
            self.offsets(2).set(0);
            self.usePresetOffsets.set(0);
            
            self.auxMultipliers(1).set(255);
            self.auxMultipliers(2).set(255);
            self.presetGains(1).set(1);
            self.presetGains(2).set(1);
            
            self.maxMWPulses.set(1e4*0.5);
            self.target.set(.1);
            self.tol.set(0.05);
            
            self.mwNumPulses.set(1e3);
            self.mwPulseWidth.set(2e-6);
            self.mwPulsePeriod.set(50e-6);
            
            self.samplesCollected(1).set(0);
            self.samplesCollected(2).set(0);
            self.pulsesCollected(1).set(0);
            self.pulsesCollected(2).set(0);
            self.pulsesCollected(3).set(0);
            
            self.manualFlag.set(0);
            self.pulseDPMan.set(0);
            self.shutterDPMan.set(0);
            self.pulseMWMan.set(0);
            self.auxMan.set(0);
        end
        
        function self = check(self)
            %CHECK Checks parameter values and makes sure that they are
            %within acceptable ranges.  Throws errors if they are not
            if self.width.get >= self.period.get
                error('Dispersive pulse width should be less than dispersive pulse period');
            end
            
            if self.sumStart.get+self.sumWidth.get > self.MAX_SUM_RANGE
                error('End of summation range is larger than %d',self.MAX_SUM_RANGE);
            elseif self.subStart.get+self.sumWidth.get > self.MAX_SUM_RANGE
                error('End of subtraction range is larger than %d',self.MAX_SUM_RANGE);
            end
            
            if self.sumStart.get >= self.subStart.get
                error('Start of summation interval is after subtraction interval');
            elseif self.sumStart.get+self.sumWidth.get >= self.subStart.get
                error('Summation interval overlaps with subtraction interval');
            elseif ~self.usePresetOffsets.value && (self.subStart.get >= self.samplesPerPulse.get || self.subStart.get+self.sumWidth.get >= self.samplesPerPulse.get)
                error('Subtraction interval is outside of number sample collection range')
            end
            
            if self.mwPulseWidth.get >= self.mwPulsePeriod.get
                error('Microwave pulse width should be less than microwave pulse period');
            end

        end
        
        function self = upload(self)
            %UPLOAD Uploads register values to the device
            %
            %   FB = FB.UPLOAD() uploads register values associated with
            %   object FB
            self.check;
            self.sharedReg.write;
            self.pulseRegs.write;
            self.avgRegs.write;
            self.integrateRegs.write;
%             self.gainComputeReg.write;
            self.signalComputeRegs.write;
            self.fbComputeRegs.write;
            self.fbPulseRegs.write;
        end
        
        function self = fetch(self)
            %FETCH Retrieves parameter values from the device
            %
            %   FB = FB.FETCH() retrieves values and stores them in object
            %   FB
            %Read registers
            self.sharedReg.read;
            self.pulseRegs.read;
            self.avgRegs.read;
            self.integrateRegs.read;
%             self.gainComputeReg.read;
            self.signalComputeRegs.read;
            self.fbComputeRegs.read;
            self.fbPulseRegs.read;
            
            %Read parameters
            self.enableDP.get;
            self.enableFB.get;
            self.useFixedGain.get;
            self.enableManualMW.get;
            self.dpOnShutterOff.get;
            self.auxOnShutterOff.get;
            
            self.width.get;
            self.numpulses.get;
            self.period.get;
            self.shutterDelay.get;
            self.auxDelay.get;
            
            self.delaySignal.get;
            self.delayAux.get;
            self.samplesPerPulse.get;
            self.log2Avgs.get;
            
            self.sumStart.get;
            self.subStart.get;
            self.sumWidth.get;
            for nn=1:numel(self.offsets)
                self.offsets(nn).get;
            end
            self.usePresetOffsets.get;
            
            for nn=1:numel(self.auxMultipliers)
                self.auxMultipliers(nn).get;
            end
            for nn=1:numel(self.presetGains)
                self.presetGains(nn).get;
            end
            
            self.maxMWPulses.get;
            self.target.get;
            self.tol.get;
            
            self.mwNumPulses.get;
            self.mwPulseWidth.get;
            self.mwPulsePeriod.get;
            
            %Get number of collected samples
            self.samplesCollected.read;
            self.pulsesCollected.read;
            
            %Manual signals
            self.manualFlag.get;
            self.pulseDPMan.get;
            self.shutterDPMan.get;
            self.pulseMWMan.get;
            self.auxMan.get;
            
        end
        
        function self = start(self)
            %START Sends a software-based start trigger to the device
            %
            %   FB = FB.START() sends a start trigger associated with
            %   object FB
            self.trigReg.set(1,[0,0]).write;
            self.trigReg.set(0,[0,0]);
        end
        
        function self = reset(self)
            %RESET Resets the device
            %
            %   FB = FB.RESET() resets the device associated with object FB
            self.trigReg.set(0,[0,0]).write;
        end
        
        function self = getRaw(self,qq)
            %GETRAW Retrieves raw data from device
            %
            %   FB = FB.GETRAW() retrieves raw data from both signal and
            %   auxiliary paths
            %
            %   FB = FB.GETRAW(Q) retrieves raw data from either signal (Q
            %   = 1) or auxiliary (Q = 2) paths
            if nargin == 1
                self.getRaw(1);
                self.getRaw(2);
            elseif nargin == 2
                self.samplesCollected(qq).read;
                self.pulsesCollected(qq).read;
                self.conn.write(0,'mode','fetch data','fetchType',2*(qq-1),'numFetch',self.samplesCollected(qq).get);
                rawData = typecast(self.conn.recvMessage,'uint8');
                [dataI,dataQ] = deal(zeros(self.samplesCollected(qq).value,1));

                mm = 1;
                for nn=1:4:numel(rawData)
                    dataI(mm) = double(typecast(uint8(rawData(nn+(0:1))),'int16'));
                    dataQ(mm) = double(typecast(uint8(rawData(nn+(2:3))),'int16'));
                    mm = mm+1;
                end
                
                if self.samplesPerPulse.value*self.pulsesCollected(qq).value > numel(dataI)
                    maxpulses = floor(numel(dataI)/self.samplesPerPulse.get);
                else
                    maxpulses = self.pulsesCollected(qq).value;
                end
                idx = 1:(maxpulses*self.samplesPerPulse.get);
                if qq == 1
                    self.signal.rawX = reshape(dataI(idx),self.samplesPerPulse.get,maxpulses);
                    self.signal.rawY = reshape(dataQ(idx),self.samplesPerPulse.get,maxpulses);
                    self.signal.tSample = 2^self.log2Avgs.get/self.CLK*(0:(self.samplesPerPulse.get-1))';
                elseif qq == 2
                    self.aux.rawX = reshape(dataI(idx),self.samplesPerPulse.get,maxpulses);
                    self.aux.rawY = reshape(dataQ(idx),self.samplesPerPulse.get,maxpulses);
                    self.aux.tSample = 2^self.log2Avgs.get/self.CLK*(0:(self.samplesPerPulse.get-1))';
                end
            end
        end
        
        function self = getProcessed(self,qq)
            %GETPROCESSED Retrieves processed (integrated) data from device
            %
            %   FB = FB.GETPROCESSED() retrieves processed data from both
            %   signal and auxiliary paths
            %
            %   FB = FB.GETPROCESSED(Q) retrieves processed data from
            %   either signal (Q = 1) or auxiliary (Q = 2) paths
            if nargin == 1
                self.getProcessed(1);
                self.getProcessed(2);
            elseif nargin == 2
                self.pulsesCollected(qq).read;
                self.conn.write(0,'mode','fetch data','fetchType',2*qq-1,'numFetch',2*self.pulsesCollected(qq).value);
                rawData = typecast(self.conn.recvMessage,'uint8');
                
                data = zeros(self.pulsesCollected(qq).value,2);

                mm = 1;
                for nn=1:8:numel(rawData)
                    data(mm,1) = double(typecast(uint8(rawData(nn+(0:3))),'int32'));
                    data(mm,2) = double(typecast(uint8(rawData(nn+(4:7))),'int32'));
                    mm = mm+1;
                end
                if qq == 1
                    self.signal.data = data/self.sumWidth.value;
                    self.signal.t = self.period.value*(0:(self.pulsesCollected(qq).value-1))';
                elseif qq == 2
                    self.aux.data = data/self.sumWidth.value;
                    self.aux.t = self.period.value*(0:(self.pulsesCollected(qq).value-1))';
                end
            end
        end
        
        function self = calcRatio(self,method)
            %CALCRATIO Calculates the ratio value from the processed data
            %
            %   FB = FB.CALCRATIO() Calculates the ratio value from
            %   processed data by converting data to floating point values
            %
            %   FB = FB.CALCRATIO(METHOD) calculates the ratio value from
            %   the processed data using METHOD, which is either "float" or
            %   "int"
            if nargin == 1
                method = 'float';
            elseif ~strcmpi(method,'int') && ~strcmpi(method,'float')
                error('Method can only be ''int'' or ''float''');
            end
            if self.useFixedGain.value
                self.gains = fix(repmat([self.presetGains.value],numel(self.signal.t),1));
            else
                if strcmpi(method,'int')
                    self.gains = fix(self.aux.data.*self.sumWidth.value);
                    self.gains = fix(self.gains);
                elseif strcmpi(method,'float')
                    self.gains = self.aux.data.*self.sumWidth.value;
                    self.gains = self.gains;
                end 
            end
            
            if strcmpi(method,'int')
                sx = self.gains(:,2).*fix(self.signal.data(:,1)*self.sumWidth.value);
                sy = self.gains(:,1).*fix(self.signal.data(:,2)*self.sumWidth.value);
                self.sum = sx+sy;
                self.diff = sx-sy;                
                self.ratio = self.diff./self.sum;
            elseif strcmpi(method,'float')
                sx = self.gains(:,2).*self.signal.data(:,1);
                sy = self.gains(:,1).*self.signal.data(:,2);
                self.sum = sx+sy;
                self.diff = sx-sy;
                self.ratio = self.diff./self.sum;
            end
            self.t = self.signal.t;
        end
        
        function self = getRatio(self)
            %GETRATIO Retrieves ratio values from the device
            %
            %   FB = FB.GETRATIO() retrieves the ratio values from the
            %   device associated with FB
            self.pulsesCollected(3).read;
            self.conn.write(0,'mode','fetch data','fetchType',4,'numFetch',self.pulsesCollected(3).value);
            rawData = typecast(self.conn.recvMessage,'uint8');

            data = zeros(self.pulsesCollected(3).value,1);

            mm = 1;
            for nn=1:4:numel(rawData)
                data(mm,1) = double(typecast(uint8(rawData(nn+(0:1))),'int16'));
                mm = mm+1;
            end
            
            self.ratio = data/2^15;
            self.t = self.period.value*(0:(self.pulsesCollected(3).value-1))';
        end
        
        function disp(self)
            %DISP Displays information about the object
            strwidth = 36;
            fprintf(1,'DPFeedback object with properties:\n');
            fprintf(1,'\t Registers\n');
            self.sharedReg.makeString('sharedReg',strwidth);
            self.pulseRegs.makeString('pulseRegs',strwidth);
            self.avgRegs.makeString('avgReg',strwidth);
            self.integrateRegs.makeString('integrateRegs',strwidth);
            self.gainComputeReg.makeString('gainComputeReg',strwidth);
            self.signalComputeRegs.makeString('signalComputeRegs',strwidth);
            self.fbComputeRegs.makeString('fbComputeRegs',strwidth);
            self.fbPulseRegs.makeString('fbPulseRegs',strwidth);
            self.sampleRegs.makeString('sampleRegs',strwidth);
            self.pulsesRegs.makeString('pulsesRegs',strwidth);
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Auxiliary Parameters\n');
            fprintf(1,'\t\t          Enable DP: %d\n',self.enableDP.value);
            fprintf(1,'\t\t          Enable FB: %d\n',self.enableFB.value);
            fprintf(1,'\t\t    Use Fixed Gains: %d\n',self.useFixedGain.value);
            fprintf(1,'\t\t   Manual MW Pulses: %d\n',self.enableManualMW.value);
            fprintf(1,'\t\t  DP on Shutter off: %d\n',self.dpOnShutterOff.value);
            fprintf(1,'\t\t Aux on Shutter off: %d\n',self.auxOnShutterOff.value);
            fprintf(1,'\t ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
            fprintf(1,'\t Pulse Parameters\n');
            fprintf(1,'\t\t       Pulse Width: %.2e s\n',self.width.value);
            fprintf(1,'\t\t      Pulse Period: %.2e s\n',self.period.value);
            fprintf(1,'\t\t     Shutter Delay: %.2e s\n',self.shutterDelay.value);
            fprintf(1,'\t\t         Aux Delay: %.2e s\n',self.auxDelay.value);
            fprintf(1,'\t\t  Number of pulses: %d\n',self.numpulses.value);
            fprintf(1,'\t ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
            fprintf(1,'\t Averaging Parameters\n');
            fprintf(1,'\t\t       Signal Delay: %.2e s\n',self.delaySignal.value);
            fprintf(1,'\t\t          Aux Delay: %.2e s\n',self.delayAux.value);
            fprintf(1,'\t\t  Samples per pulse: %d\n',self.samplesPerPulse.value);
            fprintf(1,'\t\t    log2(# of avgs): %d\n',self.log2Avgs.value);
            fprintf(1,'\t ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
            fprintf(1,'\t Integration Parameters\n');
            fprintf(1,'\t\t   Start of summation window: %d\n',self.sumStart.value);
            fprintf(1,'\t\t Start of subtraction window: %d\n',self.subStart.value);
            fprintf(1,'\t\t Width of integration window: %d\n',self.sumWidth.value);
            fprintf(1,'\t\t                   Offset(1): %d\n',self.offsets(1).value);
            fprintf(1,'\t\t                   Offset(2): %d\n',self.offsets(2).value);
            fprintf(1,'\t\t          Use Preset Offsets: %d\n',self.usePresetOffsets.value);
            fprintf(1,'\t ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
            fprintf(1,'\t Collection Results\n');
            fprintf(1,'\t\t Number of signal samples collected: %d\n',self.samplesCollected(1).value);
            fprintf(1,'\t\t  Number of signal pulses collected: %d\n',self.pulsesCollected(1).value);
            fprintf(1,'\t\t    Number of aux samples collected: %d\n',self.samplesCollected(2).value);
            fprintf(1,'\t\t     Number of aux pulses collected: %d\n',self.pulsesCollected(2).value);
            fprintf(1,'\t\t         Number of ratios collected: %d\n',self.pulsesCollected(3).value);
            fprintf(1,'\t ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
            fprintf(1,'\t Feedback Parameters\n');
            fprintf(1,'\t\t             Max # MW pulses: %d\n',self.maxMWPulses.value);
            fprintf(1,'\t\t                Ratio target: %.3g\n',self.target.value);
            fprintf(1,'\t\t             Ratio tolerance: %.3f\n',self.tol.value);
            fprintf(1,'\t\t          Manual # MW pulses: %d\n',self.mwNumPulses.value);
            fprintf(1,'\t\t              MW pulse width: %.2e s\n',self.mwPulseWidth.value);
            fprintf(1,'\t\t             MW pulse period: %.2e s\n',self.mwPulsePeriod.value);
        end
        
        
    end
    
end