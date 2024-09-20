function hSI = get_hSI_from_base
    % Get the hSI ScanImage object from the base workspace
    %
    % hSI = SIBT.get_hSI_from_base
    %
    % Purpose
    % Return hSI from the base workspace as an output argument.
    % used by the SIBT class to interact with ScanImage.
    %
    % Rob Campbell - SWC 2024


    hSI = [];
    scanimageObjectName='hSI';
    W = evalin('base','whos');
    SIexists = ismember(scanimageObjectName,{W.name});

    if ~SIexists
        fprintf('ScanImage not started. Can not connect to scanner.\n')
        return
    end

    hSI = evalin('base',scanimageObjectName); % get hSI from the base workspace

    if ~isa(hSI,'scanimage.SI')
        fprintf('%s -- hSI is not a ScanImage object.\n', mfilename)
        hSI = [];
    end
