function minimalBakeWithGUI(nSections)
    % Run a minimal bake. No saving but with the GUI. 
    %
    % function minimalBakeWithGUI(nSections)
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

    doPlots = false;

    % Get hBT and hBTview
    hBT = getObject('hBT');
    hBTview = getObject('hBTview');


    % Opens the acqisition view
    hBTview.startPreviewSampleGUI

    % Run setUpBT then this script
    hBTview.view_acquire.removeOverlays
    hBT.currentSectionNumber=1;
    hBT.takeRapidPreview;

    if strcmp('tiled: auto-ROI',hBT.recipe.mosaic.scanmode)
        hBT.getThreshold;
        z=hBT.recipe.tilePattern(false,false,hBT.autoROI.stats.roiStats.BoundingBoxDetails);
        hBTview.view_acquire.overlayTileGridOnImage(z)
        hBT.getNextROIs
    end

    if doPlots
        fig=figure(3492);
        clf
        colormap gray
    end

    hBTview.view_acquire.removeOverlays


    fprintf('Doing %d section mini-bake\n', nSections)
    for ii=1:nSections
        fprintf('\n\n****** STARTING SECTION %d  *****\n', ii)
        hBT.currentSectionNumber=ii;
        imageSection
        if doPlots
            plotLast
        end
        fprintf('\n****** FINISHED SECTION %d  *****\n', ii)
        %disp('PRESS RETURN'), pause
    end




    % Internal functions
    function imageSection

        if isa(hBT.scanner,'dummyScanner')
            % Just in case
            hBT.scanner.skipSaving=true;
        end
        hBTview.view_acquire.removeOverlays
        hBT.acquisitionInProgress=true; % This is needed to populate the last section preview image
        hBT.scanner.armScanner;
        hBT.runTileScan;
        hBT.scanner.disarmScanner;
        hBT.acquisitionInProgress=false;

        if strcmp('tiled: auto-ROI',hBT.recipe.mosaic.scanmode)
            hBTview.view_acquire.overlayLastBoundingBoxes
        end

        if strcmp('tiled: auto-ROI',hBT.recipe.mosaic.scanmode)
            hBT.getNextROIs
        end
        if isa(hBT.scanner,'dummyScanner')
            hBT.scanner.skipSaving=false;
        end

    end % imageSection

    function plotLast
        imagesc(hBT.lastPreviewImageStack(:,:,1,1),'parent',fig); % Plots first channel and first depth
        title(sprintf('Section %d',hBT.currentSectionNumber))
        axis equal tight
        drawnow
    end

end


function obj = getObject(objName)
    W = evalin('base','whos');

    if ~ismember(objName,{W.name});
        fprintf('No %s found in base workspace\n',objName)
        obj=[];
        return
    end

    obj = evalin('base',objName);
end
