import types
import subprocess
import warnings

MEM_ADDR = 0x40000000;

#######################################################################################################
#####################################  Parameter Class  ###############################################
#######################################################################################################

class Parameter:
    
    def __init__(self,addr,bitRange):
        self.addr = addr
        self.bitRange = bitRange
        self.__value = 0
        
    def reset(self):
        self.__value = 0
        
    def format(self,radix):
        if radix == 2:
            fmt = '{:0>' + format(self.length) + 'b}'
            s= fmt.format(self.value)
        elif radix == 16:
            fmt = '{:0>' + format(round(self.length/4)) + 'x}'
            s = fmt.format(self.value)
        elif radix == 10:
            s = format(self.value)
        return s
    
    def globalAddress(self):
        globalAddress = MEM_ADDR + self.addr
        return '0x' + '{:0>8x}'.format(globalAddress)
        
    @property
    def length(self):
        return self.bitRange[1] - self.bitRange[0] + 1
    
    @property
    def addr(self):
        return self.__addr
    
    @addr.setter
    def addr(self,a):
        if a < 0 or a > 0x7FFFFFFF:
            raise ValueError("Address must be between 0 and 0x7FFFFFFF")
        else:
            self.__addr = a
            
    @property
    def bitRange(self):
        return self.__bitRange
    
    @bitRange.setter
    def bitRange(self,b):
        if type(b) != list or len(b) != 2:
            raise ValueError("Bit range must be a two element list!")
        else:
            self.__bitRange = b
    
    def get(self,bitRange):
        self.read()
        length = bitRange[1] - bitRange[0] + 1
        mask = ((1 << length) - 1) << bitRange[0]
        return (self.__value & mask) >> bitRange[0]
    
    @property
    def value(self):
        self.read()
        length = self.bitRange[1] - self.bitRange[0] + 1
        mask = ((1 << length) - 1) << self.bitRange[0]
        return (self.__value & mask) >> self.bitRange[0]
    
    @value.setter
    def value(self,v):
        self.read()
        length = self.bitRange[1] - self.bitRange[0] + 1
        mask = ((1 << length) - 1) << self.bitRange[0]
        
        v = round(abs(v))
        if v > (2**length - 1):
            warnings.warn("Value exceeds the allocated bit range of the register")
        
        self.__value &= ~mask
        self.__value |= ((v << self.bitRange[0]) & mask)
        self.write()
        
    
    def write(self):
        result = subprocess.run(['monitor',self.globalAddress(),'0x' + '{:0>8x}'.format(self.__value)],stdout=subprocess.PIPE)
        if result.returncode != 0:
            raise ValueError("Monitor code returned error!")
        return result
        
    def read(self):
        result = subprocess.run(['monitor',self.globalAddress()],stdout=subprocess.PIPE)
        if result.returncode != 0:
            raise ValueError("Monitor code returned error!")
        self.__value = int(result.stdout.decode('ascii').rstrip(),16)
        return result
    
    def display(self,name,value=None,units=""):
        fmt = '{:0>8x}'
        addrString = fmt.format(self.addr)
        self.read()
        if value != None:
            if isinstance(value,int):
                valueString = "{:d}".format(value) + " " + units
            else:
                valueString = "{:.2f}".format(value) + " " + units
            print(name + "\n  " + "Address: 0x" + addrString + ", Bits: " + format(self.bitRange))
            print("  Value:   " + valueString)
        else:
            valueString = fmt.format(self.__value)
            print(name + "\n  " + "Address: 0x" + addrString)
            print("  Value:   0x" + valueString)
            
        
#######################################################################################################
#####################################  Configuration Class  ###########################################
#######################################################################################################

class Configuration:
    CLK = 125000000
    
    def __init__(self):
        ## Triggers
        self.__pulseTrig = Parameter(0x0,[0,0])
        self.__sampleTrig = Parameter(0x0,[1,1])
        self.__startTrig = Parameter(0x0,[31,31])
        self.__rampTrig = Parameter(0x0,[2,2])
        self.__ddsSerialReset = Parameter(0x0,[3,3])
        self.__ddsReset = Parameter(0x0,[4,4])
        self.__ddsTrig = Parameter(0x0,[5,5])
        self.__clearStatus = Parameter(0x0,[30,30])
        
        ## Pulse Generation
        self.__pulsePeriod = Parameter(0x4,[0,16])        
        self.__pulseWidth = Parameter(0x4,[17,31])
        self.__numPulses = Parameter(0x8,[0,8])
        
        ## Initial Data Processing
        self.__delay = Parameter(0x10,[0,13])
        self.__samplesPerPulse = Parameter(0x10,[14,27])
        self.__log2Avgs = Parameter(0x10,[28,31])       
        self.__lastSample = Parameter(0x14,[0,14])
        
        ## Secondary Data Processing
        self.__sumStart = Parameter(0x18,[0,7])
        self.__subStart = Parameter(0x18,[8,15])
        self.__width = Parameter(0x18,[16,23])
        
        ## DDS Control
        self.__rampStart = Parameter(0x1c,[0,31])
        self.__rampStepMagnitude = Parameter(0x20,[0,30])
        self.__rampStepSign = Parameter(0x20,[31,31])
        self.__numSteps = Parameter(0x24,[0,31])
        self.__stepTime = Parameter(0x28,[0,31])
        self.__ftw = Parameter(0x2c,[0,31])
        self.__useRamp = Parameter(0x30,[31,31])
        self.__rampAmp = Parameter(0x30,[0,13])
        self.__manAmp = Parameter(0x30,[14,27])
        
        ## Status
        self.__pulsesDone = Parameter(0x34,[0,0])
        
        
    def setDefaults(self):
        self.pulsePeriod = 5e-6
        self.pulseWidth = 1e-6
        self.numPulses = 500
        
        self.delay = 100e-9
        self.samplesPerPulse = 31
        self.log2Avgs = 3
        
        self.sumStart = 5
        self.subStart = 15
        self.width = 5
        
        self.rampStart = 300e6
        self.rampStep = 0.01e6
        self.numSteps = 1000
        self.stepTime = 10e-3
        self.rampAmp = 1
        
        self.ftw = 300e6
        self.manAmp = 1
        self.useRamp = 0
        
    def display(self):
        ## Full registers
        print("~~~~  Full Registers  ~~~~")
        self.__pulsePeriod.display("Pulse Register 1")
        self.__numPulses.display("Pulse Register 2")
        self.__delay.display("Initial Data Processing")
        self.__sumStart.display("Secondary Data Processing")
        self.__rampStart.display("DDS Ramp Start")
        self.__rampStepMagnitude.display("DDS Ramp Step")
        self.__numSteps.display("DDS Ramp Number of Steps")
        self.__stepTime.display("DDS Ramp Step Time")
        self.__ftw.display("Manual FTW")
        self.__useRamp.display("Auxilliary ramp register")
        self.__pulsesDone.display("Status Register")
        
        ## Individual parameters
        print("~~~~  Parameters  ~~~~")
        self.__pulsePeriod.display("Pulse period",self.pulsePeriod*1e6,"us")
        self.__pulseWidth.display("Pulse width",self.pulseWidth*1e6,"us")
        self.__numPulses.display("Num pulses",self.numPulses)
        
        self.__delay.display("Trigger delay",self.delay*1e6,"us")
        self.__samplesPerPulse.display("Samples per pulse",self.samplesPerPulse)
        self.__samplesPerPulse.display("Time per pulse",self.timePerPulse*1e6,"us")
        self.__log2Avgs.display("log2(Number of averages)",self.log2Avgs)
        
        self.__lastSample.display("Number of acquired samples",self.lastSample)
        
        self.__sumStart.display("Start of summation window",self.sumStart)
        self.__subStart.display("Start of subtraction window",self.subStart)
        self.__width.display("Width of summation and subtraction windows",self.width)
        
        self.__rampStart.display("DDS start frequency",self.rampStart/1e6,"MHz")
        self.__rampStepMagnitude.display("DDS ramp step",self.rampStep/1e3,"kHz")
        self.__numSteps.display("DDS ramp number of steps",self.numSteps)
        self.__stepTime.display("DDS ramp step time",self.stepTime*1e3,"ms")
        self.__rampAmp.display("DDS ramp amplitude",self.rampAmp)
        
        self.__ftw.display("Manual Frequency",self.ftw/1e6,"MHz")
        self.__manAmp.display("Manual DDS amplitude",self.manAmp)
        self.__useRamp.display("Use DDS ramp",self.useRamp)

    ## Triggers
    def pulseTrig(self):
        self.__pulseTrig.value = 1
    
    def sampleTrig(self):
        self.__sampleTrig.value = 1
        
    def startTrig(self):
        self.__startTrig.value = 1
        
    def rampTrig(self):
        self.__rampTrig.value = 1
        
    def ddsSerialReset(self):
        self.__ddsSerialReset.value = 1
        
    def ddsReset(self):
        self.__ddsReset.value = 1
        
    def ddsTrig(self):
        self.__ddsTrig.value = 1
        
    def clearStatus(self):
        self.__clearStatus.value = 1
        
    def begin(self):
        self.startTrig()
        result = subprocess.run(['./checkStatus'],stdout=subprocess.PIPE)
        if result.returncode != 0:
            raise ValueError("Monitor code returned error!")
        else:
            print(result.stdout.decode('ascii').rstrip())
        
        
    ## Pulse Generation
    @property
    def pulsePeriod(self):
        return self.__pulsePeriod.value/self.CLK
    
    @pulsePeriod.setter
    def pulsePeriod(self,v):
        self.__pulsePeriod.value = v*self.CLK
        
    @property
    def pulseWidth(self):
        return self.__pulseWidth.value/self.CLK
    
    @pulseWidth.setter
    def pulseWidth(self,v):
        self.__pulseWidth.value = v*self.CLK
    
    @property
    def numPulses(self):
        return self.__numPulses.value
    
    @numPulses.setter
    def numPulses(self,v):
        if v > 512:
            raise ValueError("Number of pulses cannot be larger than 512!")
        self.__numPulses.value = v
        
    ## Memory                      
    @property
    def lastSample(self):
        return self.__lastSample.value + 1
    
    def saveData(self):
        result = subprocess.run(['./saveData',format(self.lastSample)],stdout=subprocess.PIPE)
        if result.returncode != 0:
            raise ValueError("Monitor code returned error!")
        else:
            print(result.stdout.decode('ascii').rstrip())
            
        result = subprocess.run(['./saveProcessedData',format(self.numPulses)],stdout=subprocess.PIPE)
        if result.returncode != 0:
            raise ValueError("Monitor code returned error!")
        else:
            print(result.stdout.decode('ascii').rstrip())

        
    ## Initial Data Processing
    @property
    def delay(self):
        return self.__delay.value/self.CLK
    
    @delay.setter
    def delay(self,v):
        self.__delay.value = v*self.CLK
        
    @property
    def samplesPerPulse(self):
        return self.__samplesPerPulse.value
    
    @samplesPerPulse.setter
    def samplesPerPulse(self,v):
        if v < (self.subStart + self.width):
            warnings.warn("Number of samples per pulse is smaller than the subtraction window!")
        self.__samplesPerPulse.value = v
        
    @property
    def timePerPulse(self):
        return self.samplesPerPulse/self.CLK*2**self.log2Avgs
    
    @timePerPulse.setter
    def timePerPulse(self,v):
        self.samplesPerPulse = v*self.CLK/(2**self.log2Avgs)
        
    @property
    def log2Avgs(self):
        return self.__log2Avgs.value
    
    @log2Avgs.setter
    def log2Avgs(self,v):
        self.__log2Avgs.value = v
        
    
    ## Secondary Data Processing
    @property
    def sumStart(self):
        return self.__sumStart.value
    
    @sumStart.setter
    def sumStart(self,v):
        if (v + self.width) >= self.samplesPerPulse:
            warnings.warn("Summation window is larger than the number of samples per pulse!")
        self.__sumStart.value = v
        
    @property
    def subStart(self):
        return self.__subStart.value
    
    @subStart.setter
    def subStart(self,v):
        if v < self.sumStart:
            warnings.warn("Start of subtraction window must be after the summation window")
        if v < (self.sumStart + self.width):
            warnings.warn("Start of subtraction window must be after the summation window")
        if (v + self.width) >= self.samplesPerPulse:
            warnings.warn("Subtraction window is larger than the number of samples per pulse!")
            
        self.__subStart.value = v
        
    @property
    def width(self):
        return self.__width.value
    
    @width.setter
    def width(self,v):
        if (self.sumStart + v) > self.subStart:
            warnings.warn("Start of subtraction window must be after the summation window")
        if (self.subStart + v) >= self.samplesPerPulse:
            warnings.warn("Subtraction window must end before sampling does!")
        self.__width.value = v
        

    ## DDS Frequency Ramp
    @property
    def rampStart(self):
        return self.__rampStart.value/2**32*1e9
    
    @rampStart.setter
    def rampStart(self,v):
        self.__rampStart.value = v/1e9*2**32
        
    @property
    def rampStep(self):
        rampSign = self.__rampStepSign.value
        v = self.__rampStepMagnitude.value/2**32*1e9
        return v if rampSign == 0 else -v
    
    @rampStep.setter
    def rampStep(self,v):
        self.__rampStepMagnitude.value = abs(v)/1e9*2**32
        self.__rampStepSign.value = 0 if v >= 0 else 1
        
    @property
    def numSteps(self):
        return self.__numSteps.value
    
    @numSteps.setter
    def numSteps(self,v):
        self.__numSteps.value = v
        
    @property
    def stepTime(self):
        return self.__stepTime.value/self.CLK
    
    @stepTime.setter
    def stepTime(self,v):
        self.__stepTime.value = v*self.CLK
        
    def rampSetup(self,rampStart,rampEnd,stepTime,duration):
        self.stepTime = stepTime
        self.numSteps = duration/stepTime
        self.rampStep = (rampEnd-rampStart)/self.numSteps
        self.rampStart = rampStart
        
    @property
    def rampAmp(self):
        return self.__rampAmp.value/(2**14-1)
    
    @rampAmp.setter
    def rampAmp(self,v):
        self.__rampAmp.value = v*(2**14-1)
        
    
    @property
    def ftw(self):
        return self.__ftw.value/2**32*1e9
    
    @ftw.setter
    def ftw(self,v):
        self.__ftw.value = v/1e9*2**32
        self.ddsTrig()
        
    @property
    def manAmp(self):
        return self.__manAmp.value/(2**14-1)
    
    @manAmp.setter
    def manAmp(self,v):
        self.__manAmp.value = v*(2**14-1)
        self.ddsTrig()
        
    @property
    def useRamp(self):
        return self.__useRamp.value
    
    @useRamp.setter
    def useRamp(self,v):
        self.__useRamp.value = v
        
    

    ## Status
    @property
    def pulsesDone(self):
        return self.__pulsesDone.value
    




