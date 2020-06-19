% function calculateNSensitivity

[x,y] = deal(linspace(-1000e-6,1000e-6,5e2));
[X,Y] = meshgrid(x,y);
% N = 1e6*linspace(0,50,1e2);
% N = logspace(4,8,1e2);

N = logspace(4,7,1e2);
T = 1e-6;

freq = 2*pi*[160,160];
s = sqrt(const.kb*T./(const.mRb*freq.^2));

waists = [400,200,100,50,25]*1e-6;
clear dp S dS str Psc
for nn=1:numel(waists)
    dp(nn) = dispersive(waists(nn),1e-6,0.05,2*pi*400e6,2*pi*6e6,780e-9,1000e-6);
    for mm=1:numel(N)
        n = N(mm)./(2*pi*prod(s)).*exp(-X.^2./(2*s(1)^2)-Y.^2./(2*s(2)^2));
        S(mm,nn) = dp(nn).signal(x,y,n);
        dS(mm,nn) = dp(nn).sensN(x,y,n,N(mm));
        Psc(mm,nn) = dp(nn).scattpower(x,y,n);
    end
    str{nn} = sprintf('%d um',round(waists(nn)*1e6));
end

%% Approximate heating rate
dT = (Psc*const.hbar*dp(1).k/(const.mRb*const.c))./(3*repmat(N(:),1,size(Psc,2))*const.kb);

%%
figure(128);clf;
plot(N,S*1e6,'.-');
% plot(N,S./dT,'.-')
set(gca,'xscale','log','yscale','log');
plot_format('Number of atoms [x10^6]','Signal power [uW]','',10);
legend(str,'location','northwest');

%%
figure(129);clf;
Ipeak = 2*sqrt(0.05)*1e-6./(pi*waists.^2);

plot(N/1e6,abs(dS)./Psc*1e6,'.-');
% plot(N,abs(dS),'.-');
set(gca,'xscale','log','yscale','log');
plot_format('Number of atoms [x10^6]','Sensitivity [uW signal/10^6 atoms/uW absorbed]','',10);
legend(str,'location','northwest');