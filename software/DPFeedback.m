classdef DPFeedback < handle
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
        TCP_PORT = 6666;
        CLK = 125e6;
    end
    
    methods
        function self = DPFeedback(varargin)
            if numel(varargin)==1
                self.conn = tcpclient(varargin{1},self.TCP_PORT);
            else
                self.conn = tcpclient('rp-f01ec3.px.otago.ac.nz',self.TCP_PORT);
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
                .setFunctions('to',@(x) x,'from',@(x) x);
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
            self.numpulses.set(500);
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
            self.pulseReg0.read;
            self.pulseReg1.read;
            self.avgReg0.read;
            self.integrateReg0.read;
        end
        
        function self = start(self)
            self.trigReg0.set(1,[0,0]).write;
            self.trigReg0.set(0,[0,0]);
        end
        
        
    end
    
end