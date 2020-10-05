classdef DPPower < handle
    properties
        signal
        aux
        
        period
        t
    end
    
    properties(SetAccess = immutable)
        conn
        
        delaySignal
        delayAux
        samplesPerPulse
        log2Avgs
        
        sumStart
        subStart
        sumWidth
        offsets
        usePresetOffsets

        samplesCollected
        pulsesCollected

    end
    
    properties(SetAccess = protected)
        trigReg
        sharedReg
        avgRegs
        integrateRegs
        
        sampleRegs
        pulsesRegs
    end
    
    properties(Constant)
        CLK = 125e6;
        MAX_SUM_RANGE = 2^11-1;
        HOST_ADDRESS = '172.22.250.189';
    end
    
    methods
        function self = DPPower(varargin)
            if numel(varargin)==1
                self.conn = DPFeedbackClient(varargin{1});
            else
                self.conn = DPFeedbackClient(self.HOST_ADDRESS);
            end
            
            self.signal = DPFeedbackData;
            self.aux = DPFeedbackData;
            
            % R/W registers
            self.trigReg = DPFeedbackRegister('0',self.conn);
            self.sharedReg = DPFeedbackRegister('4',self.conn);
            self.avgRegs = DPFeedbackRegister('18',self.conn);
            self.avgRegs(2) = DPFeedbackRegister('1C',self.conn);
            self.integrateRegs = DPFeedbackRegister('20',self.conn);
            self.integrateRegs(2) = DPFeedbackRegister('24',self.conn);
            
            % Read-only registers
            self.sampleRegs = DPFeedbackRegister('01000000',self.conn);
            self.pulsesRegs = DPFeedbackRegister('01000004',self.conn);
            self.sampleRegs(2) = DPFeedbackRegister('01000008',self.conn);
            self.pulsesRegs(2) = DPFeedbackRegister('0100000C',self.conn);
            
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
            
        end
        
        function self = setDefaults(self,varargin)
            
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
            
            self.samplesCollected(1).set(0);
            self.samplesCollected(2).set(0);
            self.pulsesCollected(1).set(0);
            self.pulsesCollected(2).set(0);
        end
        
        function self = check(self)
            
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

        end
        
        function self = copyfb(self,fb)
            self.period = fb.period.get;
            
            self.delaySignal.set(fb.delaySignal.get);
            self.delayAux.set(fb.delayAux.get);
            self.samplesPerPulse.set(fb.samplesPerPulse.get);
            self.log2Avgs.set(fb.log2Avgs.get);
            
            self.sumStart.set(fb.sumStart.get);
            self.subStart.set(fb.subStart.get);
            self.sumWidth.set(fb.sumWidth.get);
            
            self.offsets(1).set(fb.offsets(1).get);
            self.offsets(2).set(fb.offsets(2).get);
            self.usePresetOffsets.set(fb.usePresetOffsets.get);
            
        end
        
        function self = upload(self)
            self.check;
            self.sharedReg.write;

            self.avgRegs.write;
            self.integrateRegs.write;

        end
        
        function self = fetch(self)
            %Read registers
            self.sharedReg.read;

            self.avgRegs.read;
            self.integrateRegs.read;

            
            %Read parameters         
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
            
            %Get number of collected samples
            self.samplesCollected.read;
            self.pulsesCollected.read;
            
        end
        
        function self = start(self)
            self.trigReg.set(1,[0,0]).write;
            self.trigReg.set(0,[0,0]);
        end
        
        function self = reset(self)
            self.trigReg.set(0,[0,0]).write;
        end
        
        function self = getRaw(self,qq)
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
                    self.signal.t = self.period*(0:(self.pulsesCollected(qq).value-1))';
                elseif qq == 2
                    self.aux.data = data/self.sumWidth.value;
                    self.aux.t = self.period*(0:(self.pulsesCollected(qq).value-1))';
                end
            end
        end
        
%         function v = integrate(self)
%             sumidx = (self.sumStart.get):(self.sumStart.get+self.sumWidth.get);
%             subidx = (self.subStart.get):(self.subStart.get+self.sumWidth.get);
%             v(:,1) = sum(self.rawI(sumidx,:),1)'-sum(self.rawI(subidx,:),1)';
%             v(:,2) = sum(self.rawQ(sumidx,:),1)'-sum(self.rawQ(subidx,:),1)';
%         end
        
        function disp(self)
            strwidth = 36;
            fprintf(1,'DPPower object with properties:\n');
            fprintf(1,'\t Registers\n');
            self.sharedReg.makeString('sharedReg',strwidth);
            self.avgRegs.makeString('avgReg',strwidth);
            self.integrateRegs.makeString('integrateRegs',strwidth);
            self.sampleRegs.makeString('sampleRegs',strwidth);
            self.pulsesRegs.makeString('pulsesRegs',strwidth);
            fprintf(1,'\t ----------------------------------\n');
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
        end
        
        
    end
    
end