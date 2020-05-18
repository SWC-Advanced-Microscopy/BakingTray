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

    doPlots = true;

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
        hBT.getNextROIs
    end

    if doPlots
        figure(3492)
        clf
        colormap gray
    end

    for ii=1:nSections
        hBT.currentSectionNumber=ii;
        imageSection
        if doPlots
            plotLast
        end

    end




    % Internal functions
    function imageSection

        if isa(hBT.scanner,'dummyScanner')
            % Just in case
            hBT.scanner.skipSaving=true;
        end

        hBT.acquisitionInProgress=true; % This is needed to populate the last section preview image
        hBT.scanner.armScanner;
        hBT.runTileScan;
        hBT.scanner.disarmScanner;
        hBT.acquisitionInProgress=false;

        if strcmp('tiled: auto-ROI',hBT.recipe.mosaic.scanmode)
            hBT.getNextROIs
        end
        if isa(hBT.scanner,'dummyScanner')
            hBT.scanner.skipSaving=false;
        end

    end % % imageSection

    function plotLast
        imagesc(hBT.lastPreviewImageStack(:,:,1,1)); % Plots first channel and first depth
        title(sprintf('Section %d',hBT.currentSectionNumber))
        axis equal tight
        drawnow
    end

end

