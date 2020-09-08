classdef DPFeedback < handle
    properties
        raw
        tSample

        signal
        aux
        tPulse
    end
    
    properties(SetAccess = immutable)
        conn
        
        enableDP
        enableFB
        useFixedGain
        enableManualMW
        dpOnShutterOff
        auxOnShutterOff
        
        width
        numpulses
        period
        shutterDelay
        auxDelay
        
        delay
        samplesPerPulse
        log2Avgs
        
        sumStart
        subStart
        sumWidth
        offsets
        usePresetOffsets
        
        maxMWPulses
        target
        tol
        
        mwNumPulses
        mwPulseWidth
        mwPulsePeriod
        
        samplesCollected
        pulsesCollected
        
        manualFlag
        pulseDPMan
        shutterDPMan
        pulseMWMan
        auxMan
    end
    
    properties(SetAccess = protected)
        trigReg
        sharedReg
        pulseRegs
        avgReg
        integrateRegs
        fbComputeRegs
        fbPulseRegs
        
        sampleRegs
        pulsesRegs
    end
    
    properties(Constant)
        CLK = 125e6;
        MAX_SUM_RANGE = 2^11-1;
        HOST_ADDRESS = '172.22.250.94';
    end
    
    methods
        function self = DPFeedback(varargin)
            if numel(varargin)==1
                self.conn = DPFeedbackClient(varargin{1});
            else
                self.conn = DPFeedbackClient(self.HOST_ADDRESS);
            end
            
            % R/W registers
            self.trigReg = DPFeedbackRegister('0',self.conn);
            self.sharedReg = DPFeedbackRegister('4',self.conn);
            self.pulseRegs(1) = DPFeedbackRegister('8',self.conn);
            self.pulseRegs(2) = DPFeedbackRegister('C',self.conn);
            self.pulseRegs(3) = DPFeedbackRegister('10',self.conn);
            self.pulseRegs(4) = DPFeedbackRegister('14',self.conn);
            self.avgReg = DPFeedbackRegister('18',self.conn);
            self.integrateRegs(1) = DPFeedbackRegister('1C',self.conn);
            self.integrateRegs(2) = DPFeedbackRegister('20',self.conn);
            self.fbComputeRegs(1) = DPFeedbackRegister('24',self.conn);
            self.fbComputeRegs(2) = DPFeedbackRegister('28',self.conn);
            self.fbPulseRegs(1) = DPFeedbackRegister('2C',self.conn);
            self.fbPulseRegs(2) = DPFeedbackRegister('30',self.conn);
            
            % Read-only registers
            self.sampleReg(1) = DPFeedbackRegister('01000000',self.conn);
            self.pulsesReg(1) = DPFeedbackRegister('01000004',self.conn);
            self.sampleReg(2) = DPFeedbackRegister('01000008',self.conn);
            self.pulsesReg(2) = DPFeedbackRegister('0100000C',self.conn);
            
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
            self.delay = DPFeedbackParameter([0,13],self.avgReg)...
                .setLimits('lower',0,'upper',1e-6)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            self.samplesPerPulse = DPFeedbackParameter([14,27],self.avgReg)...
                .setLimits('lower',0,'upper',2^14-1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.log2Avgs = DPFeedbackParameter([28,31],self.avgReg)...
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
            self.offsets(1) = DPFeedbackParameter([0,13],self.integrateRegs(2))...
                .setLimits('lower',-2^13,'upper',2^13)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.offsets(2) = DPFeedbackParameter([27,14],self.integrateRegs(2))...
                .setLimits('lower',-2^13,'upper',2^13)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.usePresetOffsets = DPFeedbackParameter([28,28],self.integrateRegs(2))...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            
            %Feedback registers
            self.maxMWPulses = DPFeedbackParameter([0,15],self.fbComputeRegs(1))...
                .setLimits('lower',0,'upper',2^16-1);
            self.target = DPFeedbackParameter([16,31;0,7],[self.fbComputeRegs(1),self.fbComputeRegs(2)])...
                .setLimits('lower',0,'upper',2^24-1)...
                .setFunctions('to',@(x) x*2^16,'from',@(x) x*2^(-16));
            self.tol = DPFeedbackParameter([8,31],self.fbComputeRegs(2))...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) (1+x)*self.target.get*2^16,'from',@(x) x/(2^16*self.target.get)-1);
            
            self.mwNumPulses = DPFeedbackParameter([16,31],self.fbPulseRegs(1))...
                .setLimits('lower',0,'upper',2^16-1);
            self.mwPulseWidth = DPFeedbackParameter([0,15],self.fbPulseRegs(1))...
                .setLimits('lower',0,'upper',(2^16-1)/self.CLK)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            self.mwPulsePeriod = DPFeedbackParameter([0,31],self.fbPulseRegs(2))...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x*self.CLK,'from',@(x) x/self.CLK);
            
            %Read-only
            self.samplesCollected(1) = DPFeedbackParameter([0,14],self.sampleRegs(1))...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.samplesCollected(2) = DPFeedbackParameter([0,14],self.sampleRegs(2))...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.pulsesCollected(1) = DPFeedbackParameter([0,14],self.pulsesRegs(1))...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) round(x/2));
            self.pulsesCollected(2) = DPFeedbackParameter([0,14],self.pulsesRegs(2))...
                .setLimits('lower',0,'upper',2^14)...
                .setFunctions('to',@(x) x,'from',@(x) round(x/2));
            
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
            
            self.enableDP.set(1);
            self.enableFB.set(0);
            self.enableManualMW.set(0);
            self.normalise.set(0);
            self.dpOnShutterOff.set(0);
            self.auxOnShutterOff.set(0);
            
            self.width.set(1e-6);
            self.numpulses.set(50);
            self.period.set(5e-6);
            self.shutterDelay.set(2.5e-3);
            self.auxDelay.set(2.5e-3);
            
            self.delay.set(0);
            self.samplesPerPulse.set(250);
            self.log2Avgs.set(0);
            
            self.sumStart.set(10);
            self.subStart.set(150);
            self.sumWidth.set(50);
            self.offsets(1).set(0);
            self.offsets(2).set(0);
            self.usePresetOffsets.set(0);
            
            self.maxMWPulses.set(1e4*0.5);
            self.target.set(1);
            self.tol.set(0.05);
            
            self.mwNumPulses.set(1e3);
            self.mwPulseWidth.set(2e-6);
            self.mwPulsePeriod.set(50e-6);
            
            % self.samplesCollected.set(0);
            % self.pulsesCollected.set(0);
            
            self.manualFlag.set(0);
            self.pulseDPMan.set(0);
            self.shutterDPMan.set(0);
            self.pulseMWMan.set(0);
            self.auxMan.set(0);
        end
        
        function self = check(self)
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
            elseif self.subStart.get >= self.samplesPerPulse.get || self.subStart.get+self.sumWidth.get >= self.samplesPerPulse.get
                error('Subtraction interval is outside of number sample collection range')
            end
            
            if self.mwPulseWidth.get >= self.mwPulsePeriod.get
                error('Microwave pulse width should be less than microwave pulse period');
%             elseif self.quadTol.value <= self.quadTarget.value
%                 error('Target signal times the FB number of pulses should be larger than the quad tolerance');
            end

        end
        
        function self = upload(self)
            self.check;
            self.sharedReg.write;

            for nn=1:numel(self.pulseRegs)
                self.pulseRegs(nn).write;
            end

            self.avgReg.write;

            for nn=1:numel(self.integrateRegs)
                self.integrateRegs(nn).write;
            end

            for nn=1:numel(self.fbComputeRegs)
                self.fbComputeRegs(nn).write;
            end

            for nn=1:numel(self.fbPulseRegs)
                self.fbPulseRegs(nn).write;
            end

        end
        
        function self = fetch(self)
            %Read registers
            self.sharedReg.read;

            for nn=1:numel(self.pulseRegs)
                self.pulseRegs(nn).read;
            end

            self.avgReg.read;

            for nn=1:numel(self.integrateRegs)
                self.integrateRegs(nn).read;
            end

            for nn=1:numel(self.fbComputeRegs)
                self.fbComputeRegs(nn).read;
            end

            for nn=1:numel(self.fbPulseRegs)
                self.fbPulseRegs(nn).read;
            end
            
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
            
            self.delay.get;
            self.samplesPerPulse.get;
            self.log2Avgs.get;
            
            self.sumStart.get;
            self.subStart.get;
            self.sumWidth.get;
            for nn=1:numel(self.offsets)
                self.offsets(nn).get;
            end
            self.usePresetOffsets.get;
            
            self.maxMWPulses.get;
            self.target.get;
            self.tol.get;
            
            self.mwNumPulses.get;
            self.mwPulseWidth.get;
            self.mwPulsePeriod.get;
            
            %Get number of collected samples
            for nn=1:numel(self.samplesCollected)
                self.samplesCollected(nn).read;
                self.pulsesCollected(nn).read;
            end
            
            %Manual signals
            self.manualFlag.get;
            self.pulseDPMan.get;
            self.shutterDPMan.get;
            self.pulseMWMan.get;
            self.auxMan.get;
            
        end
        
        function self = start(self)
            self.trigReg.set(1,[0,0]).write;
            self.trigReg.set(0,[0,0]);
        end
        
        function self = reset(self)
            self.trigReg.set(0,[0,0]).write;
        end
        
        function self = getRaw(self,qq)
            if nargin == 2
                self.getRaw(1);
                self.getRaw(2);
            elseif nargin == 1
                self.samplesCollected(qq).read;
                self.pulsesCollected(qq).read;
                self.conn.write(0,'mode','fetch raw','numFetch',self.samplesCollected(qq).get);
                raw = typecast(self.conn.recvMessage,'uint8');
                [dataI,dataQ] = deal(zeros(self.samplesCollected(qq).value,1));

                mm = 1;
                for nn=1:4:numel(raw)
                    dataI(mm) = double(typecast(uint8(raw(nn+(0:1))),'int16'));
                    dataQ(mm) = double(typecast(uint8(raw(nn+(2:3))),'int16'));
                    mm = mm+1;
                end
                
                if self.samplesPerPulse.value*self.pulsesCollected(qq).value > numel(dataI)
                    maxpulses = floor(numel(dataI)/self.samplesPerPulse.get);
                else
                    maxpulses = self.pulsesCollected(qq).value;
                end
                idx = 1:(maxpulses*self.samplesPerPulse.get);
                self.raw(qq).y = reshape(dataI(idx),self.samplesPerPulse.get,maxpulses);
                self.raw(qq).x = reshape(dataQ(idx),self.samplesPerPulse.get,maxpulses);
                
                self.tSample = 2^self.log2Avgs.get/self.CLK*(0:(self.samplesPerPulse.get-1))';
            end
        end
        
        function self = getProcessed(self,qq)
            if nargin == 2
                self.getProcessed(1);
                self.getProcessed(2);
            elseif nargin == 1
                self.pulsesCollected(qq).read;
                self.conn.write(0,'mode','fetch processed','numFetch',2*self.pulsesCollected(qq).value);
                raw = typecast(self.conn.recvMessage,'uint8');
                
                data = zeros(self.pulsesCollected(qq).value,2);

                mm = 1;
                for nn=1:8:numel(raw)
                    data(mm,1) = double(typecast(uint8(raw(nn+(0:3))),'int32'));
                    data(mm,2) = double(typecast(uint8(raw(nn+(4:7))),'int32'));
                    mm = mm+1;
                end
                if qq == 1
                    self.signal = data/self.sumWidth.value;
                elseif qq == 2
                    self.aux = data/self.sumWidth.value;
                end

                self.tPulse = self.period.value*(0:(self.pulsesCollected(qq).value-1))';
            end
        end
        
        function v = integrate(self)
            sumidx = (self.sumStart.get):(self.sumStart.get+self.sumWidth.get);
            subidx = (self.subStart.get):(self.subStart.get+self.sumWidth.get);
            v(:,1) = sum(self.rawI(sumidx,:),1)'-sum(self.rawI(subidx,:),1)';
            v(:,2) = sum(self.rawQ(sumidx,:),1)'-sum(self.rawQ(subidx,:),1)';
        end
        
        function disp(self)
            fprintf(1,'DPFeedback object with properties:\n');
            fprintf(1,'\t Registers\n');
            fprintf(1,'\t\t     sharedReg: %08x\n',self.sharedReg.value);
            fprintf(1,'\t\t     pulseReg0: %08x\n',self.pulseReg0.value);
            fprintf(1,'\t\t     pulseReg1: %08x\n',self.pulseReg1.value);
            fprintf(1,'\t\t     pulseReg2: %08x\n',self.pulseReg2.value);
            fprintf(1,'\t\t     pulseReg3: %08x\n',self.pulseReg3.value);
            fprintf(1,'\t\t     pulseReg4: %08x\n',self.pulseReg4.value);
            fprintf(1,'\t\t       avgReg0: %08x\n',self.avgReg0.value);
            fprintf(1,'\t\t integrateReg0: %08x\n',self.integrateReg0.value);
            fprintf(1,'\t\t fbComputeReg0: %08x\n',self.fbComputeReg0.value);
            fprintf(1,'\t\t fbComputeReg1: %08x\n',self.fbComputeReg1.value);
            fprintf(1,'\t\t fbComputeReg2: %08x\n',self.fbComputeReg2.value);
            fprintf(1,'\t\t fbComputeReg3: %08x\n',self.fbComputeReg3.value);
            fprintf(1,'\t\t   fbPulseReg0: %08x\n',self.fbPulseReg0.value);
            fprintf(1,'\t\t   fbPulseReg1: %08x\n',self.fbPulseReg1.value);
            fprintf(1,'\t\t    sampleReg0: %08x\n',self.sampleReg0.value);
            fprintf(1,'\t\t    pulsesReg0: %08x\n',self.pulsesReg0.value);
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Auxiliary Parameters\n');
            fprintf(1,'\t\t         Enable DP: %d\n',self.enableDP.value);
            fprintf(1,'\t\t         Enable FB: %d\n',self.enableFB.value);
            fprintf(1,'\t\t  Manual MW Pulses: %d\n',self.enableManualMW.value);
            fprintf(1,'\t\t   Power Normalise: %d\n',self.normalise.value);
            fprintf(1,'\t\t DP on Shutter off: %d\n',self.dpOnShutterOff.value);
            fprintf(1,'\t ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
            fprintf(1,'\t Pulse Parameters\n');
            fprintf(1,'\t\t       Pulse Width: %.2e s\n',self.width.value);
            fprintf(1,'\t\t      Pulse Period: %.2e s\n',self.period.value);
            fprintf(1,'\t\t     Shutter Delay: %.2e s\n',self.shutterDelay.value);
            fprintf(1,'\t\t         EOM Delay: %.2e s\n',self.eomDelay.value);
            fprintf(1,'\t\t         EOM Width: %.2e s\n',self.eomWidth.value);
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
            fprintf(1,'\t\t  Number of pulses collected: %d\n',self.pulsesCollected.value);
            fprintf(1,'\t ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
            fprintf(1,'\t Feedback Parameters\n');
            fprintf(1,'\t\t             Max # MW pulses: %d\n',self.maxMWPulses.value);
            fprintf(1,'\t\t    Quadrature signal target: %.3g\n',self.quadTarget.value);
            fprintf(1,'\t\t Quadrature signal tolerance: %.3f\n',self.quadTol.value);
            fprintf(1,'\t\t          Manual # MW pulses: %d\n',self.mwNumPulses.value);
            fprintf(1,'\t\t              MW pulse width: %.2e s\n',self.mwPulseWidth.value);
            fprintf(1,'\t\t             MW pulse period: %.2e s\n',self.mwPulsePeriod.value);
        end
        
        
    end
    
end