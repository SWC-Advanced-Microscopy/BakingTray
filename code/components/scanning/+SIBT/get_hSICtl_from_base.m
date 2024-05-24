function hSICtl = get_hSICtl_from_base
    % Get the hSICtl ScanImage object from the base workspace
    %
    % hSICtl = SIBT.get_hSICtl_from_base
    %
    % Purpose
    % Return hSICtl from the base workspace as an output argument.
    % used by the SIBT class to interact with ScanImage.
    %
    % Rob Campbell - SWC 2024


    hSICtl = [];
    scanimageObjectName='hSICtl';
    W = evalin('base','whos');
    SIexists = ismember(scanimageObjectName,{W.name});

    if ~SIexists
        fprintf('ScanImage not started. Can not connect to scanner.\n')
        return
    end

    hSICtl = evalin('base',scanimageObjectName); % get hSICtl from the base workspace

    if ~isa(hSICtl,'scanimage.SIController')
        fprintf('%s -- hSICtl is not a scanimage.SIController object.\n', mfilename)
        hSICtl = [];
    end
