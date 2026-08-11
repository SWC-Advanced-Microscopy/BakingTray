function axOFF
% Turn off the Axon laser -- Temporary function
%
% axOFF
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


hBT.lasers(2).turnOff;
