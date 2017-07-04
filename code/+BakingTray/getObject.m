function hBT = getObject(quiet)
% Returns the BakingTray object from the base workspace regardless of its name
%
% Purpose
% Used by methods to import BakingTray without requiring it to be passed as an input argument.
%
% Inputs
% quiet - false by default. If true, print no messages to screen. 
%
% Outputs
% hBT - the BakingTray object. Returns empty if BT could not be found. 
%
%
% Rob Campbell - Basel 2016

    if nargin<1
        quiet=false;
    end

    W=evalin('base','whos');

    varClasses = {W.class};

    ind=strmatch('BT',varClasses);

    if isempty(ind)
        if ~quiet
            fprintf('No BakingTray object in base workspace\n')
        end
        hBT=[];
        return
    end

    if length(ind)>1
        if ~quiet
            fprintf('More than one BakingTray object in base workspace\n')
        end
        hBT=[];
        return
    end


    hBT=evalin('base',W(ind).name);