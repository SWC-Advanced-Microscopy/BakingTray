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
        fprintf('Opening new figure window\n')
        fig=figure;
        ax=cla;
        clf
        colormap gray
    end


    fprintf('Doing %d section mini-bake\n', nSections)
    for ii=1:nSections
        fprintf('****** STARTING SECTION %d  *****\n', ii)
        hBT.currentSectionNumber=ii;
        imageSection

        if doPlots
            imagesc(hBT.lastPreviewImageStack(:,:,1,1)); % Plots first channel and first depth
            title(sprintf('Section %d',hBT.currentSectionNumber))
            axis equal tight
            drawnow
         end

        fprintf('****** FINISHED SECTION %d  *****\n', ii)
        %disp('PRESS RETURN'), pause
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

    end % imageSection


end

