% function calculateNSensitivity
clear;

r = linspace(0,1000e-6,1e3);
carrierOffset = -3e9;
% fmod = 3e9;
T = 15e-6;
N = linspace(0,50e6,50);
detuning = [0.5e9,1e9,1.5e9,2e9,3e9];
fmod = abs(carrierOffset)+detuning;

Pc0 = 100e-6;
% Pc = Pc0*ones(size(detuning));
% sbfrac = 0.05*ones(size(detuning));

Pc = Pc0*(detuning/min(detuning)).^2;
Psb = 5e-6;
sbfrac = Psb./Pc;

freq = 2*pi*160;
s = sqrt(const.kb*T./(const.mRb*freq.^2));
waist = 32e-6;

for nn=1:numel(detuning)
    for mm=1:numel(N)
        n = N(mm)./(2*pi*s.^2).*exp(-r.^2./(2*s^2));
        dp = dispersivemod(waist,Pc(nn),2*pi*fmod(nn),sbfrac(nn),2*pi*detuning(nn),2*pi*6e6,780e-9,1e-3);
        S(mm,nn) = dp.signal(r,n);
        Psc(mm,nn) = dp.scattpower(r,n);
        dS(mm,nn) = dp.sensN(r,n,N(mm));
        dT(mm,nn) = (Psc(mm,nn)*const.hbar*dp.k/(const.mRb*const.c))./(3*N(mm)*const.kb);
        ph(mm,nn) = dp.prepOverlap(r(1),n(1),0).*dp.k/2;
    end
    str{nn} = sprintf('%.2f GHz, %.1e uW',detuning(nn)/1e9,Pc(nn)*1e6);
end


%%
% figure(128);clf;
% plot(N/1e6,S*1e6,'.-');
% plot_format('N [x10^6]','Signal power [uW]','',10);
% 
% % Prf = (S*1250).^2/50*1e4;
% % Vdemod = sqrt(Prf/(1e-3*10^-.88))*150e-3;
% % plot(N/1e6,Vdemod,'.-');
% % plot_format('N [x10^6]','Signal voltage [V]','',10);
% 
% grid on
% set(gca,'xminorgrid','on','yminorgrid','on')
% % set(gca,'xscale','log','yscale','log');
% legend(str,'location','northwest');

%%
% figure(129);clf;
% for nn=1:numel(detuning)
%     plot(abs(real(ph(:,nn)/pi)),S(:,nn)*1e6,'.-');
%     hold on;
% end
% plot_format('Central phase shift [\pi]','Signal power [uW]','',10);
% grid on
% set(gca,'xminorgrid','on','yminorgrid','on')
% % set(gca,'xscale','log','yscale','log');
% legend(str,'location','northwest');

%%
figure(130);clf;
% plot(N/1e6,dT,'.-');
% plot_format('N [x10^6]','Heating Rate [uK/us]','',10);
plot(detuning/1e9,mean(dT(2:end,:),1),'.-');
plot_format('\Delta [GHz]','Heating Rate [uK/us]','',10);

grid on
set(gca,'xminorgrid','on','yminorgrid','on')
set(gca,'xscale','lin','yscale','log');
% legend(str,'location','northwest');

%%
figure(100);clf;
h = gcf;
% set(h,'units','centimeters','position',[h.Position(1:2),23.2,11.2]);
ax = axes('position',[0.05,0.125,0.43,.85]);
plot(N/1e6,S*1e6,'.-');
plot_format('N [x10^6]','Signal power [uW]','',10);
grid on
set(gca,'xminorgrid','on','yminorgrid','on')
legend(str,'location','northwest');

ax2 = axes('position',[0.05+0.07+0.43,0.125,0.43,.85]);
for nn=1:numel(detuning)
    plot(abs(real(ph(:,nn)/pi)),S(:,nn)*1e6,'.-');
    hold on;
end
plot_format('Central phase shift [\pi]','Signal power [uW]','',10);
grid on
set(gca,'xminorgrid','on','yminorgrid','on')

