classdef evapdata < handle
    properties
        Nsave
        atoms
        t
        r
        v
        N
        T
    end
    
    methods
        function self = evapdata(Nsave,atoms)
            self.Nsave = Nsave;
            self.atoms = atoms;
            self.t = zeros(Nsave,1);
            self.r = cell(Nsave,1);
            self.v = cell(Nsave,1);
            self.N = zeros(Nsave,1);
            self.T = zeros(Nsave,3);
        end
        
        function self = set(self,idx,varargin)
            for nn=1:numel(varargin)
                switch nn
                    case 1
                        self.t(idx) = varargin{nn};
                    case 2
                        self.N(idx) = varargin{nn};
                    case 3
                        self.T(idx,:) = varargin{nn};
                    case 4
                        self.r{idx} = varargin{nn};
                    case 5
                        self.v{idx} = varargin{nn};
                end
            end
        end
        
        function self = truncate(self,idx)
            if numel(idx)==1
                idx = 1:idx;
            end
            self.Nsave = numel(idx);
            self.t = self.t(idx);
            self.r = self.r(idx);
            self.v = self.v(idx);
            self.N = self.N(idx);
            self.T = self.T(idx,:);
        end
        
        function n = peakDensity(self)
            s = sqrt(const.kb*self.T./(self.atoms.mass.*self.atoms.trapFreq.^2));
            n = self.N./((2*pi)^1.5*prod(s,2));
        end
        
        function psd = PSD(self)
            LambdaT = sqrt(2*pi*const.hbar^2./(self.atoms.mass.*const.kb.*mean(self.T,2)));
            psd = self.peakDensity.*LambdaT.^3;
        end
        
        function plot(self,varargin)
            
            clr = '';
            lspc = '.-';
            for nn=1:2:numel(varargin)
                switch varargin{nn}
                    case 'clr'
                        clr = varargin{nn+1};
                    case 'linespec'
                        lspc = varargin{nn+1};
                    otherwise
                        error('Option %s unsupported',varargin{nn});
                end
            end
            
            if isempty(clr)
                args = {lspc};
            else
                args = {lspc,'color',clr};
            end
            
            subplot(2,2,1);
            plot(self.t,self.N,args{:});
            hold on;
            plot_format('Time [s]','Number of atoms','',10);
            
            subplot(2,2,2);
            plot(self.t,mean(self.T,2)*1e6,args{:});
            hold on;
            plot_format('Time [s]','Temperature [uK]','',10);
            
            subplot(2,2,3);
            plot(self.t,self.peakDensity,args{:});
            hold on;
            plot_format('Time [s]','Peak Density [m^{-3}]','',10);
            
            subplot(2,2,4);
            semilogy(self.t,self.PSD,args{:});
            hold on;
            plot_format('Time [s]','PSD','',10);
        end
        
        function [n,x,y] = bin2D(self,dr,dispBounds,binIdx)
            for nn=1:self.Nsave
                if nn==1
                    [tmp,x,y] = atomState.bin2D(self.r{nn},dr,dispBounds,binIdx);
                    C = zeros([size(tmp),self.Nsave]);
                else
                    tmp = atomState.bin2D(self.r{nn},dr,dispBounds,binIdx);
                end
                C(:,:,nn) = self.N(nn)/size(self.r{nn},1)*tmp;
            end
            dx = x(2)-x(1);
            n = C/dx^2;
        end
        
    end
    
end