classdef DPFeedbackData < handle
    properties
        rawX
        rawY
        tSample
        
        data
        t
    end
    
    methods
        function s = struct(self)
            %STRUCT Returns a structure representing the data
            %
            %   S = STRUCT(SELF) Returns structure S from current
            %   object SELF
            s.rawX = self.rawX;
            s.rawY = self.rawY;
            s.tSample = self.tSample;
            s.data = self.data;
            s.t = self.t;
        end

        function s = saveobj(self)
            %SAVEOBJ Returns a structure used for saving data
            %
            %   S = SAVEOBJ(SELF) Returns structure S used for saving
            %   data representing object SELF
            s = self.struct;
        end
    end

    methods(Static)
        function self = loadobj(s)
            %LOADOBJ Creates a DPFEEDBACKDATA object using input structure
            %
            %   SELF = LOADOBJ(S) uses structure S to create new DPFEEDBACKDATA
            %   object SELF
            self = DPFeedbackData;
            self.rawX = s.rawX;
            self.rawY = s.rawY;
            self.tSample = s.tSample;
            self.data = s.data;
            self.t = s.t;
        end
    end
end