classdef DPFeedback < handle
    properties
        rawI
        rawQ
        tSample
        signal
        tPulse
    end
    
    properties(SetAccess = immutable)
        conn
        
        width
        numpulses
        period
        
        delay
        samplesPerPulse
        log2Avgs
        samplesCollected
        
        sumStart
        subStart
        sumWidth
    end
    
    properties(SetAccess = protected)
        trigReg0
        pulseReg0
        pulseReg1
        avgReg0
        sampleReg0
        integrateReg0
    end
    
    properties(Constant)
        CLK = 125e6;
    end
    
    methods
        function self = DPFeedback(varargin)
            if numel(varargin)==1
                self.conn = DPFeedbackClient;
            else
                self.conn = DPFeedbackClient;
            end
            
            self.trigReg0 = DPFeedbackRegister('0',self.conn);
            self.pulseReg0 = DPFeedbackRegister('4',self.conn);
            self.pulseReg1 = DPFeedbackRegister('8',self.conn);
            self.avgReg0 = DPFeedbackRegister('c',self.conn);
            self.sampleReg0 = DPFeedbackRegister('10',self.conn);
            self.integrateReg0 = DPFeedbackRegister('14',self.conn);
            
            % Pulse generation
            self.width = DPFeedbackParameter([0,15],self.pulseReg0)...
                .setLimits('lower',100e-9,'upper',10e-3)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            self.numpulses = DPFeedbackParameter([16,31],self.pulseReg0)...
                .setLimits('lower',0,'upper',2^16-1)...
                .setFunctions('to',@(x) round(x),'from',@(x) x);
            self.period = DPFeedbackParameter([0,31],self.pulseReg1)...
                .setLimits('lower',500e-9,'upper',10)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            
            %Initial processing
            self.delay = DPFeedbackParameter([0,13],self.avgReg0)...
                .setLimits('lower',0,'upper',1e-6)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            self.samplesPerPulse = DPFeedbackParameter([14,27],self.avgReg0)...
                .setLimits('lower',0,'upper',2^14-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.log2Avgs = DPFeedbackParameter([28,31],self.avgReg0)...
                .setLimits('lower',0,'upper',2^4-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.samplesCollected = DPFeedbackParameter([0,14],self.sampleReg0)...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            
            %Secondary processing
            self.sumStart = DPFeedbackParameter([0,7],self.integrateReg0)...
                .setLimits('lower',0,'upper',2^8-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.subStart = DPFeedbackParameter([8,15],self.integrateReg0)...
                .setLimits('lower',0,'upper',2^8-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.sumWidth = DPFeedbackParameter([16,23],self.integrateReg0)...
                .setLimits('lower',0,'upper',2^8-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
        end
        
        function self = setDefaults(self,varargin)
            self.width.set(1e-6);
            self.numpulses.set(50);
            self.period.set(5e-6);
            
            self.delay.set(0);
            self.samplesPerPulse.set(250);
            self.log2Avgs.set(0);
            
            self.sumStart.set(10);
            self.subStart.set(150);
            self.sumWidth.set(50);
        end
        
        function self = upload(self)
            self.pulseReg0.write;
            self.pulseReg1.write;
            self.avgReg0.write;
            self.integrateReg0.write;
        end
        
        function self = fetch(self)
            %Read registers
            self.pulseReg0.read;
            self.pulseReg1.read;
            self.avgReg0.read;
            self.integrateReg0.read;
            self.sampleReg0.read;
            
            %Read parameters
            self.width.get;
            self.numpulses.get;
            self.period.get;
            
            self.delay.get;
            self.samplesPerPulse.get;
            self.log2Avgs.get;
            
            self.sumStart.get;
            self.subStart.get;
            self.sumWidth.get;
            
            %Get number of collected samples
            self.samplesCollected.read;
        end
        
        function self = start(self)
            self.trigReg0.set(1,[0,0]).write;
            self.trigReg0.set(0,[0,0]);
        end
        
        function self = getRaw(self)
            self.samplesCollected.read;
            self.conn.write(0,'mode','fetch raw','numFetch',self.samplesCollected.get);
            data = typecast(self.conn.recvMessage,'uint8');
            [dataI,dataQ] = deal(zeros(self.samplesCollected.value,1));

            mm = 1;
            for nn=1:4:numel(data)
                dataI(mm) = double(typecast(uint8(data(nn+(0:1))),'int16'));
                dataQ(mm) = double(typecast(uint8(data(nn+(2:3))),'int16'));
                mm = mm+1;
            end
            
            self.rawI = reshape(dataI,self.samplesPerPulse.get,self.numpulses.get);
            self.rawQ = reshape(dataQ,self.samplesPerPulse.get,self.numpulses.get);
            
            self.tSample = 2^self.log2Avgs.get/self.CLK*(0:(self.samplesPerPulse.get-1))';
        end
        
        function self = getProcessed(self)
            self.samplesCollected.read;
            self.conn.write(0,'mode','fetch processed','numFetch',self.numpulses.get);
            raw = typecast(self.conn.recvMessage,'uint8');
            
            self.signal = zeros(self.numpulses.get,1);
            mm = 1;
            for nn=1:4:numel(raw)
                self.signal(mm) = double(typecast(uint8(raw(nn+(0:3))),'uint32'));
                mm = mm+1;
            end
            
            self.tPulse = self.period.value*(0:(self.numpulses.get-1))';
        end
        
        function disp(self)
            fprintf(1,'DPFeedback object with properties:\n');
            fprintf(1,'\t Registers\n');
            fprintf(1,'\t\t     pulseReg0: %08x\n',self.pulseReg0.value);
            fprintf(1,'\t\t     pulseReg1: %08x\n',self.pulseReg1.value);
            fprintf(1,'\t\t       avgReg0: %08x\n',self.avgReg0.value);
            fprintf(1,'\t\t    sampleReg0: %08x\n',self.sampleReg0.value);
            fprintf(1,'\t\t integrateReg0: %08x\n',self.integrateReg0.value);
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Pulse Parameters\n');
            fprintf(1,'\t\t       Pulse Width: %.2e s\n',self.width.value);
            fprintf(1,'\t\t      Pulse Period: %.2e s\n',self.period.value);
            fprintf(1,'\t\t  Number of pulses: %d\n',self.numpulses.value);
            fprintf(1,'\t ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
            fprintf(1,'\t Averaging Parameters\n');
            fprintf(1,'\t\t             Delay: %.2e s\n',self.delay.value);
            fprintf(1,'\t\t Samples per pulse: %d\n',self.samplesPerPulse.value);
            fprintf(1,'\t\t   log2(# of avgs): %d\n',self.log2Avgs.value);
            fprintf(1,'\t ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
            fprintf(1,'\t Integration Parameters\n');
            fprintf(1,'\t\t   Start of summation window: %d\n',self.sumStart.value);
            fprintf(1,'\t\t Start of subtraction window: %d\n',self.subStart.value);
            fprintf(1,'\t\t Width of integration window: %d\n',self.sumWidth.value);
            fprintf(1,'\t\t Number of samples collected: %d\n',self.samplesCollected.value);
            
        end
        
        
    end
    
end