classdef dispersive < handle
    properties
        waist
        power
        detuning
        gamma
        k
        sbfrac
        aperture
    end
    
    methods
        function self = dispersive(waist,power,sbfrac,detuning,gamma,wavelength,aperture)
            self.waist = waist;
            self.power = power;
            self.sbfrac = sbfrac;
            self.detuning = detuning;
            self.gamma = gamma;
            self.k = 2*pi/wavelength;
            if nargin<7
                self.aperture = Inf;
            else
                self.aperture  = aperture;
            end
        end
        
        function I = intensity(self,x,y)
            I = 2*self.power/(pi*self.waist^2).*exp(-2*(x.^2+y.^2)/self.waist^2);
        end
        
        function s = saturation(self,x,y)
            s = self.sbfrac*self.intensity(x,y)/self.gamma*12*pi/(const.hbar*const.c*self.k^3);
        end
        
        function pop = excitedpop(self,x,y)
            s = self.saturation(x,y);
            pop = 0.5*s./(1+4*self.detuning^2/self.gamma^2+s);
        end
        
        function p = scattphotons(self,x,y,dt)
            p = self.excitedpop(x,y)*self.gamma*dt;
        end
        
        function [X,Y,susc,mask] = prepOverlap(self,x,y,n)
            [X,Y] = meshgrid(x,y);
            susc = -n*(3*pi./self.k^3*self.gamma)./(self.detuning+1i*self.gamma/2);
            mask = sqrt(X.^2+Y.^2)<self.aperture;
        end
        
        function [Sred,Sblue] = getOverlap(self,X,Y,dx,susc,mask)
            Sred = sqrt(self.sbfrac)*dx^2*trapz(trapz(exp(1i*self.k/2*susc).*self.intensity(X,Y).*mask));
            Sblue = sqrt(self.sbfrac)*dx^2*trapz(trapz(self.intensity(X,Y).*mask));
        end
        
        function varargout = signal(self,x,y,n)
            [X,Y,susc,mask] = self.prepOverlap(x,y,n);
            dx = x(2)-x(1);
            [Sred,Sblue] = self.getOverlap(X,Y,dx,susc,mask);
            
            I = abs(Sred).*cos(angle(Sred))-abs(Sblue).*cos(angle(Sblue));
            Q = -abs(Sred).*sin(angle(Sred))+abs(Sblue).*sin(angle(Sblue));
            if nargout == 1
%                 varargout{1} = sqrt(I.^2+Q.^2);
                varargout{1} = abs(Sred-Sblue);
            else
                varargout = {I,Q};
            end
        end
        
        function dS = sensN(self,x,y,n,N)
            [X,Y,susc,mask] = self.prepOverlap(x,y,n);
            dx = x(2)-x(1);
            [Sred,Sblue] = self.getOverlap(X,Y,dx,susc,mask);
            
            dSred = sqrt(self.sbfrac)*dx^2*trapz(trapz(1i*self.k/2*susc/N.*exp(1i*self.k/2*susc).*self.intensity(X,Y).*mask));
            
            S = abs(Sred-Sblue);
            dS2 = 2*real(dSred.*conj(Sred-Sblue));
            dS = dS2./(2*S);
        end
        
        function P = scattpower(self,x,y,n)
            [X,Y,susc,~] = self.prepOverlap(x,y,n);
            dx = x(2)-x(1);
%             P = self.sbfrac*self.power-self.sbfrac*dx^2*trapz(trapz(real(exp(1i*self.k/2*susc)).*self.intensity(X,Y)));
            P = self.sbfrac*(dx^2*trapz(trapz(self.intensity(X,Y)))...
                -dx^2*trapz(trapz(exp(real(1i*self.k/2*susc)).*self.intensity(X,Y))));
        end
        
        
    end
    
end