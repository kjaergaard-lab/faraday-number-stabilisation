import types
import subprocess
import warnings

MEM_ADDR = 0x40000000

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
        if a < 0 or a > 0x3FFFFFFF:
            raise ValueError("Address must be between 0 and 0x3FFFFFFF")
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
        
        ## Pulse Generation    
        self.__pulseWidth = Parameter(0x4,[0,15])
        self.__numPulses = Parameter(0x4,[16,31])
        self.__pulsePeriod = Parameter(0x8,[0,31])  
        
        ## Initial Data Processing
        self.__delay = Parameter(0xc,[0,13])
        self.__samplesPerPulse = Parameter(0xc,[14,27])
        self.__log2Avgs = Parameter(0xc,[28,31])       
        self.__lastSample = Parameter(0x10,[0,14])

        ## Secondary Data Processing
        self.__sumStart = Parameter(0x14,[0,7])
        self.__subStart = Parameter(0x14,[8,15])
        self.__width = Parameter(0x14,[16,23])
        
        
        
    def setDefaults(self):
        self.pulsePeriod = 5e-6
        self.pulseWidth = 1e-6
        self.numPulses = 500
        
        self.delay = 0
        self.samplesPerPulse = 31
        self.log2Avgs = 1
        
        self.sumStart = 5
        self.subStart = 15
        self.width = 5

        
    def display(self):
        ## Full registers
        print("~~~~  Full Registers  ~~~~")
        self.__pulseWidth.display("Pulse Register 0")
        self.__pulsePeriod.display("Pulse Register 1")
        self.__delay.display("Initial Data Processing")
        self.__sumStart.display("Secondary Data Processing")
        
        ## Individual parameters
        print("~~~~  Parameters  ~~~~")
        self.__pulseWidth.display("Pulse width",self.pulseWidth*1e6,"us")
        self.__numPulses.display("Num pulses",self.numPulses)
        self.__pulsePeriod.display("Pulse period",self.pulsePeriod*1e6,"us")
        
        self.__delay.display("Trigger delay",self.delay*1e6,"us")
        self.__samplesPerPulse.display("Samples per pulse",self.samplesPerPulse)
        self.__samplesPerPulse.display("Time per pulse",self.timePerPulse*1e6,"us")
        self.__log2Avgs.display("log2(Number of averages)",self.log2Avgs)

        self.__lastSample.display("Number of acquired samples",self.lastSample)

    ## Triggers
    def pulseTrig(self):
        self.__pulseTrig.value = 1
        
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
        return self.__lastSample.value
    
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
        

    def upload(self):
        result = subprocess.run('cat system_wrapper.bit > /dev/xdevcfg',stdout=subprocess.PIPE)
        




