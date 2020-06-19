%% Setup
addpath('..')

Ntest = 1e4;
Nphysical = 27e6;
T = 16e-6;

%% Setup atom properties
atoms = atomProperties(const.mRb,T);
atoms.trapFreq = 2*pi*[160,160,16];
atoms.calcWidth.calcVelocityWidth;
atoms.becFrac = 0;
atoms.scatteringLength = 100*const.aBohr;

atoms.initPosition = zeros(Ntest,3);
atoms.initVelocity = zeros(Ntest,3);

%% Setup scattering properties
maxEnergy = 200e-6*const.kb;
dE = 0.1e-6*const.kb;
E = 0:dE:maxEnergy;
k = sqrt(atoms.mass*E/const.hbar^2);
si = scatteringInfo(atoms.mass/2,dE,maxEnergy);
si.addT(0,0:dE:maxEnergy,exp(2*1i*-k*atoms.scatteringLength)-1,'phase');
si.calcCrossSec('same').calcNormalization.calcMaxVrelCrossSec(3*T);

%% Set up DSMC state
state = atomState(atoms.initPosition,atoms.initVelocity,zeros(Ntest,1),atoms.mass*ones(Ntest,1));
state.simBounds = [5e-3,5e-3,8e-3];
state.F = Nphysical/Ntest;
state.sInfo = si;
state.useCollLog = false;
state.finalTime = 5;

%% Set up dispersive probe
% dp = dispersive(100e-6,1e-6,0.05,2*pi*400e6,2*pi*6e6,780e-9);

%% Run
waists = 1e-6*[200,100,50,25];
targetIntensity = 2*1e-6/(pi*200e-6^2);
powers = targetIntensity*pi*waists.^2/2;
for nn=1:numel(waists)
    dp(nn) = dispersive(waists(nn),powers(nn),0.05,2*pi*400e6,2*pi*6e6,780e-9);
    data(nn) = EvapSim(atoms,copy(state),dp(nn));
end

%% Process
[I,Q,S] = deal(cell(numel(waists),1));
for mm=1:numel(waists)
    [n,x,y] = data(mm).bin2D(2e-6,500e-6*[1,1],3);
    
    for nn=1:size(n,3)
        [I{mm}(nn,1),Q{mm}(nn,1)] = dp(mm).signal(x,y,n(:,:,nn));
    end
    S{mm} = sqrt(I{mm}.^2+Q{mm}.^2);
    plot(data(mm).t,S{mm},'.-');
    hold on;
end
grid on;