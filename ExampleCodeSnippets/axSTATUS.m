function axSTATUS
% Print to screen status of the Axon laser -- Temporary function
%
% axSTATUS
%
% Inputs
% none
%
% Outputs
% none
%
% Rob Campbell - SWC 2026

hBT=BakingTray.getObject(true);

if isempty(hBT)
    fprintf('BakingTray not started\n')
    return
end

if length(hBT.lasers)==1
    fprintf('No Axon connected\n')
    return
end

if ~strcmp(hBT.lasers(2).type,'Axon')
    fprintf('Second laser is not an Axon\n')
    return
end


msg=hBT.lasers(2).returnLaserStats;

fprintf('%s\n',msg)


