function minimalBake(nSections)
    % Run a minimal bake. No saving. No GUI. 
    %
    % function minimalBake(nSections)
    %
    % Purpose
    % This function can be used as a demo of how to run a minimal 
    % bake. It can be used a skeleton for other testing: copy it and
    % modify it.
    %
    % Inputs [optional]
    % nSections - if not provided only two sections are "imaged"
    %
    % Example
    % BakingTray('dummyMode',true)
    % load('/Volumes/data/previewStacks/stacks/twoBrains/CA_514_A__514_C_previewStack.mat')
    % hBT.scanner.attachPreviewStack(pStack)
    % minimalBake


    if nargin<1
        nSections=2;
    end

    % Get hBT
    scanimageObjectName='hSI';
    W = evalin('base','whos');
    BTexists = ismember('hBT',{W.name});

    if ~BTexists
        fprintf('No hBT found in base workspace\n')
        return
    end

    hBT = evalin('base','hBT');



    % Run setUpBT then this script
    hBT.currentSectionNumber=1;
    hBT.takeRapidPreview;

    if strcmp('tiled: auto-ROI',hBT.recipe.mosaic.scanmode)
        hBT.getThreshold;
    end


    for ii=1:nSections
        imageSection
    end




    % Internal functions
    function imageSection
        hBT.acquisitionInProgress=true; % This is needed to populate the last section preview image
        hBT.scanner.armScanner;
        hBT.runTileScan;
        hBT.scanner.disarmScanner;
        hBT.acquisitionInProgress=false;
    end

end

