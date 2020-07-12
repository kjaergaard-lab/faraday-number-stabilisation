% function calculateNSensitivity

r = linspace(0,1000e-6,1e3);
% N = 1e6*linspace(0,50,1e2);
% N = logspace(4,8,1e2);

fmod = 3.5e9;
N = 30e6;
T = 15e-6;
% detuning = 1e6*linspace(-4e3,4e3,1e2);
detuning = 1e6*logspace(2,5,1e2);

freq = 2*pi*160;
s = sqrt(const.kb*T./(const.mRb*freq.^2));
n = N./(2*pi*s.^2).*exp(-r.^2./(2*s^2));

% waists = [400,200,100,50,25]*1e-6;
waists = [100,75,50,25]*1e-6;
clear dp S dS str Psc
for nn=1:numel(waists)
    dp(nn) = dispersivemod(waists(nn),120e-6,2*pi*fmod,0.05,2*pi*2e9,2*pi*6e6,780e-9,1000e-6);
    for mm=1:numel(detuning)
        dp(nn).detuning = 2*pi*detuning(mm);
        S(mm,nn) = dp(nn).signal(r,n);
        dS(mm,nn) = dp(nn).sensN(r,n,N);
        Psc(mm,nn) = dp(nn).scattpower(r,n);
    end
    str{nn} = sprintf('%d um',round(waists(nn)*1e6));
end

%% Approximate heating rate
dT = (Psc*const.hbar*dp(1).k/(const.mRb*const.c))./(3*N*const.kb);

%%
figure(128);clf;
% plot(detuning/1e6,S*1e6,'.-');
% plot_format('\Delta [MHz]','Signal power [uW]','',10);
% plot(detuning/1e6,S*1e6./(dT*1e6),'.-');
% plot_format('\Delta [MHz]','Signal power to heating rate [uW signal/(uK/s) heating]','',10);

Prf = (S*1250).^2/50*1e4;
Vdemod = sqrt(Prf/(1e-3*10^-.88))*150e-3;
plot(detuning/1e6,Vdemod,'.-');
plot_format('\Delta [MHz]','Signal voltage [V]','',10);

grid on
set(gca,'xminorgrid','on','yminorgrid','on')
set(gca,'xscale','log','yscale','log');
legend(str,'location','northwest');

return;

%%
figure(129);clf;

% plot(detuning/1e6,abs(dS)*1e6./(dT*1e6)*1e3,'.-');
% plot_format('\Delta [MHz]','Sensitivity [uW signal/10^3 atoms/(uK/s) heating]','',10);

plot(detuning/1e6,abs(dS./S)*1e3,'.-');
plot_format('\Delta [MHz]','Relative sensitivity [Fraction change/10^3 atoms]','',10);

grid on
set(gca,'xminorgrid','on','yminorgrid','on')
set(gca,'xscale','log','yscale','log');
legend(str,'location','northwest');