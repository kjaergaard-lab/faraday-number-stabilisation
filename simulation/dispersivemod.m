classdef dispersivemod < handle
    properties
        waist
        power
        fmod
        detuning
        gamma
        k
        sbfrac
        aperture
    end
    
    methods
        function self = dispersivemod(waist,power,fmod,sbfrac,detuning,gamma,wavelength,aperture)
            self.waist = waist;
            self.power = power;
            self.fmod = fmod;
            self.sbfrac = sbfrac;
            self.detuning = detuning;
            self.gamma = gamma;
            self.k = 2*pi/wavelength;
            if nargin<8
                self.aperture = Inf;
            else
                self.aperture  = aperture;
            end
        end
        
        function I = intensity(self,r)
            I = 2*self.power/(pi*self.waist^2).*exp(-2*(r.^2)/self.waist^2);
        end
        
        function s = saturation(self,r)
            s = self.intensity(r)/self.gamma*12*pi/(const.hbar*const.c*self.k^3);
        end
        
        function pop = excitedpop(self,r)
            s = self.saturation(r);
            sb = self.sbfrac*s;
%             pop = 0.5*s./(1+4*self.detuning^2/self.gamma^2+s);
            pop = 0.5*sb./(1+sb*0)./(1+4*self.detuning^2/self.gamma^2+sb*0)...
                +0.5*s./(1+s*0)./(1+4*(self.detuning+self.fmod)^2/self.gamma^2+s*0)...
                +0.5*sb./(1+sb*0)./(1+4*(self.detuning+2*self.fmod)^2/self.gamma^2+sb*0);
        end
        
        function p = scattphotons(self,r,dt)
            p = self.excitedpop(r)*self.gamma*dt;
        end
        
        function [susc,mask] = prepOverlap(self,r,n,order)
            susc = -n*(3*pi./self.k^3*self.gamma)./(self.detuning+order*self.fmod+1i*self.gamma/2);
            mask = r<self.aperture;
        end
        
        
        function varargout = signal(self,r,n)
            [suscR,mask] = self.prepOverlap(r,n,0);
            suscC = self.prepOverlap(r,n,1);
            suscB = self.prepOverlap(r,n,2);
            dr = r(2)-r(1);
            Sred = sqrt(self.sbfrac)*2*pi*dr*trapz(r.*exp(1i*self.k/2.*(suscR+suscC)).*self.intensity(r).*mask);
            Sblue = sqrt(self.sbfrac)*2*pi*dr*trapz(r.*exp(1i*self.k/2.*(suscB+suscC)).*self.intensity(r).*mask);
            
            I = abs(Sred).*cos(angle(Sred))-abs(Sblue).*cos(angle(Sblue));
            Q = -abs(Sred).*sin(angle(Sred))+abs(Sblue).*sin(angle(Sblue));
            if nargout < 2
                varargout{1} = abs(Sred-Sblue);
            else
                varargout = {I,Q};
            end
        end
        
        function dS = sensN(self,r,n,N)
            [suscR,mask] = self.prepOverlap(r,n,0);
            suscC = self.prepOverlap(r,n,1);
            suscB = self.prepOverlap(r,n,2);
            dr = r(2)-r(1);
            Sred = sqrt(self.sbfrac)*2*pi*dr*trapz(r.*exp(1i*self.k/2.*(suscR+suscC)).*self.intensity(r).*mask);
            Sblue = sqrt(self.sbfrac)*2*pi*dr*trapz(r.*exp(1i*self.k/2.*(suscB+suscC)).*self.intensity(r).*mask);
            
            dSred = sqrt(self.sbfrac)*2*pi*dr*trapz(r.*1i*self.k/2.*(suscR+suscC)/N.*exp(1i*self.k/2*(suscR+suscC)).*self.intensity(r).*mask);
            dSblue = sqrt(self.sbfrac)*2*pi*dr*trapz(r.*1i*self.k/2.*(suscB+suscC)/N.*exp(1i*self.k/2*(suscB+suscC)).*self.intensity(r).*mask);
            
            
            S = abs(Sred-Sblue);
            dS2 = 2*real(dSred.*conj(Sred-Sblue)-dSblue.*conj(Sred-Sblue));
            dS = dS2./(2*S);
        end
        
        function P = scattpower(self,r,n)
            dr = r(2)-r(1);
%             P = const.hbar*const.c*self.k*self.gamma*2*pi*dr*trapz(r.*self.excitedpop(r).*n);
            suscR = self.prepOverlap(r,n,0);
            suscC = self.prepOverlap(r,n,1);
            suscB = self.prepOverlap(r,n,2);
            
            P = 2*pi*dr.*(trapz(r.*(self.sbfrac*exp(real(1i*self.k/2*suscR))+exp(real(1i*self.k/2*suscC))+self.sbfrac*exp(real(1i*self.k/2*suscB))).*self.intensity(r)))...
                -2*pi*dr.*trapz(r.*(1+2*self.sbfrac).*self.intensity(r));
            
            P = -P;
        end
        
        
    end
    
end