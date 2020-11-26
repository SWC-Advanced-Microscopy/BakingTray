function applyZstackSettingsFromRecipe(obj)
    % applyZstackSettingsFromRecipe
    % This method is (at least for now) specific to ScanImage. 
    % Its main purpose is to set the number of planes and distance between planes.
    % It also sets the the view style to tiled. This method is called by armScanner
    % but also by external classes at certain times in order to set up the correct 
    % Z settings in ScanImage so the user can do a quick Grab and check the
    % illumination correction with depth.


    % Some settings have moved between ScanImage versions. We take this into account here. 
    if obj.versionGreaterThan('5.7')
	    fastZsettingLocation = 'hStackManager';
	else
		fastZsettingLocation = 'hFastZ';
	end

    thisRecipe = obj.parent.recipe;
    if thisRecipe.mosaic.numOpticalPlanes>1
        fprintf('Setting up z-scanning with "step" waveform\n')

        % Only change settings that need changing, otherwise it's slow.
        % The following settings are fixed: they will never change
        if ~strcmp(obj.hC.hFastZ.waveformType,'step') 
            obj.hC.hFastZ.waveformType = 'step'; %Always
        end
        if obj.hC.(fastZsettingLocation).numVolumes ~= 1
            obj.hC.(fastZsettingLocation).numVolumes=1; %Always
        end
        if obj.hC.hFastZ.enable ~=1
            obj.hC.hFastZ.enable=1;
        end
        if obj.hC.hStackManager.stackReturnHome ~= 1
            obj.hC.hStackManager.stackReturnHome = 1;
        end

        % Now set the number of slices and the distance in z over which to image
        sliceThicknessInUM = thisRecipe.mosaic.sliceThickness*1E3;


        if obj.hC.hStackManager.numSlices ~= thisRecipe.mosaic.numOpticalPlanes
            obj.hC.hStackManager.numSlices = thisRecipe.mosaic.numOpticalPlanes + thisRecipe.mosaic.numOverlapZPlanes;
        end

        if obj.hC.hStackManager.stackZStepSize ~= sliceThicknessInUM/thisRecipe.mosaic.numOpticalPlanes;
            obj.hC.hStackManager.stackZStepSize = sliceThicknessInUM/thisRecipe.mosaic.numOpticalPlanes;
        end


        if strcmp(obj.hC.hDisplay.volumeDisplayStyle,'3D')
            fprintf('Setting volume display style from 3D to Tiled\n')
            obj.hC.hDisplay.volumeDisplayStyle='Tiled';
        end

    else % There is no z-stack being performed

        %Ensure we disable z-scanning if this is not being used
        obj.hC.hStackManager.numSlices = 1;
        obj.hC.hStackManager.stackZStepSize = 0;
        obj.hC.hFastZ.enable=false;

    end


    % Apply averaging as needed
    aveFrames = obj.hC.hDisplay.displayRollingAverageFactor;  
    if aveFrames>1
        fprintf('Setting up averaging of %d frames\n', aveFrames)
    end
    obj.hC.hScan2D.logAverageFactor = 1; % To avoid warning
    obj.hC.hStackManager.framesPerSlice = aveFrames;
    if obj.averageSavedFrames
        obj.hC.hScan2D.logAverageFactor = aveFrames;
    else
        obj.hC.hScan2D.logAverageFactor = 1;
    end

end % applyZstackSettingsFromRecipe
