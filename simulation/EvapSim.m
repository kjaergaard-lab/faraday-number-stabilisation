function data = EvapSim(atoms,state,dp)
% DSMC simulation of collisions between potassium atoms in the optical
% trap.  DSMC method based on G. A. Bird, from "Molecular Gas Dynamics
% and the Direct Simulation of Gas Flows."  

%% Initialize variables
rng('shuffle');

%% Initial collision rate calculation for cell and time step size
vAvg = zeros(numel(atoms),1);
peakDensity = vAvg;
trapPeriod = vAvg;
for nn=1:numel(atoms)
    vAvg(nn) = atoms(nn).calcAvgSpeed;
    peakDensity(nn) = state.F*state.Ntest/((2*pi)^1.5*prod(atoms(nn).initWidth));
    trapPeriod(nn,1) = min(1./atoms(nn).trapFreq);
end

col_rate = 0.5*max(vAvg)*max([state.sInfo.maxCrossSec])*max(peakDensity);

dt_scale = 1e-2;
CellOccupancy = 1;
state.CG(1) = CellOccupancy*state.F./max(peakDensity);
state.CG(2:4) = state.CG(1)^(1/3).*[1,1,1];
state.numCells = 2*ceil(state.simBounds./state.CG(2:4))+1;

dt = min(dt_scale/(CellOccupancy*col_rate),min(trapPeriod));
% dt = dt_scale*1/(CellOccupancy*col_rate);

%% Generate randomized atom positions and velocities
state.r = state.r+atoms.getDistPos(state.Ntest,state.Ntest*state.F);
state.v = state.v+atoms.getDistVel(state.Ntest,state.Ntest*state.F);

w_mat = repmat(atoms.trapFreq(:)',state.Ntest,1);
g_offset = 0;

%% Define evaporation ramp
rampStart = 3;
rampEnd = 2;
rampTime = 5;
rampFunc = @(x) rampEnd+(x<=rampTime).*(x-rampTime).*(rampEnd-rampStart)./rampTime;
B0 = 2.8571;    %in G

%% Other Stuff
%To prevent data loss from computer problems, we save the data 10 times
%during the simulation and then recombine it at the end
Nsave = 100;
TimeSaveStep = state.finalTime/Nsave;
data = evapdata(Nsave,atoms);
% time_save = zeros(Nsave,1);
% r_save = zeros(state.Ntest,3,Nsave,'single');
% v_save = zeros(state.Ntest,3,Nsave,'single');
countSameCollSave = zeros(state.Ntest,Nsave,'uint16');
countDiffCollSave = zeros(state.Ntest,Nsave,'uint16');
CollTime = 0;
MoveTime = 0;

%% Main Program Loop
time = 0;
ss = 0;
nn = [0,0];
TimerOverall = tic;
while time<state.finalTime
    nn(2)=nn(2)+1;  
    %% Calculate positions and velocities of the atoms.
    TimerMove=tic;
    state.harmonicMovement(dt,w_mat,g_offset);
    MoveTime = MoveTime+toc(TimerMove);
    
    %% Index atoms and perform collisions
    TimerColl = tic;
    numCollisions = state.indexAtoms.calcCollisions(dt,time);
    CollTime = CollTime+toc(TimerColl);
    
    %% Apply dispersive probe
    % There are two vnew's because there is an absorption and emission
    % event
    theta = acos(2*rand(state.Ntest,1)-1);
    phi = 2*pi*rand(state.Ntest,1);
    vnew = repmat(dp.scattphotons(state.r(:,1),state.r(:,2),dt),1,3).*const.hbar/atoms.mass*dp.k.*[sin(theta).*cos(phi),sin(theta).*sin(phi),cos(theta)];
    theta = acos(2*rand(state.Ntest,1)-1);
    phi = 2*pi*rand(state.Ntest,1);
    vnew2 = repmat(dp.scattphotons(state.r(:,1),state.r(:,2),dt),1,3).*const.hbar/atoms.mass*dp.k.*[sin(theta).*cos(phi),sin(theta).*sin(phi),cos(theta)];
    state.v = state.v+vnew-vnew2;
    
    %% Remove atoms
    U = 0.5*state.mass.*sum(w_mat.^2.*state.r.^2,2);
    Bfield = U/const.muB+B0*1e-4;   %[T]
    rfFreq = 0.5*const.muB*Bfield/const.h/1e6;  %[MHz]
    keepAtoms = rfFreq<rampFunc(time);
    
    state.removeAtoms(keepAtoms);
    w_mat = w_mat(keepAtoms,:);
    
%     if state.Ntest == 0
%         break;
%     end
       
    %% Save data for later analysis and in case of computer crashes
    if floor(time/TimeSaveStep)==ss || state.Ntest==0
        ss = ss+1;
%         countSameCollSave(:,ss) = state.countSameColl;
%         countDiffCollSave(:,ss) = state.countDiffColl;
        state.resetCounters;
        data.set(ss,time,state.Ntest*state.F,atoms.mass/const.kb*mean(state.v.^2,1),state.r,state.v);
        
        fprintf('Save Point\nSimulation Time: %.3f ms (%.1f%% Complete)\nAverage Collision Calculation Time: %.1f ms\nAverage move time: %.1f us\ndt = %.2e s\n',time*1e3,time/state.finalTime*1e2,CollTime/(nn(2)-nn(1))*1e3,MoveTime/(nn(2)-nn(1))*1e6,dt);
%         fprintf('Total collisions: %d\n',sum(countSameCollSave(:,ss)+countDiffCollSave(:,ss)));
        nn(1) = nn(2);
        MoveTime = 0;
        CollTime = 0;
        
        if state.Ntest == 0
            break;
        end

    end
    ColRateEst = sum(numCollisions)/(dt*state.Ntest);
    dt = min([dt_scale./ColRateEst,min(trapPeriod)]);
    time = time+dt;
end
OverallTime = toc(TimerOverall);
fprintf('Total Time for simulation: %.3f s\n',OverallTime);

state.collLog.truncate;
data.truncate(ss);
% save(filename);
end




