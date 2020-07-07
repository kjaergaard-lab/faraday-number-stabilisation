% function calculateNSensitivity

r = linspace(0,1000e-6,1e3);

fmod = 4e9;
N = logspace(4,7,1e2);
T = 1e-6;

freq = 2*pi*160;
s = sqrt(const.kb*T./(const.mRb*freq.^2));
n0 = 1./(2*pi*s.^2).*exp(-r.^2./(2*s^2));

waists = [400,200,100,50,25]*1e-6;
clear dp S dS str Psc
for nn=1:numel(waists)
    dp(nn) = dispersivemod(waists(nn),100e-6,2*pi*fmod,0.05,2*pi*2000e6,2*pi*6e6,780e-9,1000e-6);
    for mm=1:numel(N)
        n = N(mm)*n0;
        S(mm,nn) = dp(nn).signal(r,n);
        dS(mm,nn) = dp(nn).sensN(r,n,N(mm));
        Psc(mm,nn) = dp(nn).scattpower(r,n);
    end
    str{nn} = sprintf('%d um',round(waists(nn)*1e6));
end

%% Approximate heating rate
dT = (Psc*const.hbar*dp(1).k/(const.mRb*const.c))./(3*repmat(N',1,numel(waists))*const.kb);

%%
figure(128);clf;
plot(N,S*1e6,'.-');
% plot(N,S./dT,'.-')
set(gca,'xscale','log','yscale','log');
plot_format('Number of atoms [x10^6]','Signal power [uW]','',10);
legend(str,'location','northwest');

return
%%
figure(129);clf;
Ipeak = 2*sqrt(0.05)*1e-6./(pi*waists.^2);

plot(N,abs(dS)./Psc*1e6,'.-');
% plot(N,abs(dS),'.-');
set(gca,'xscale','log','yscale','log');
plot_format('Number of atoms','Sensitivity [uW signal/10^6 atoms/uW absorbed]','',10);
legend(str,'location','northwest');