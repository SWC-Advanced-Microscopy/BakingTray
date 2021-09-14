function [acquisitionPossible,msg] = checkIfAcquisitionIsPossible(obj,isBake)
    % Check if acquisition is possible 
    %
    % [acquisitionPossible,msg] = BT.checkIfAcquisitionIsPossible(obj,isBake)
    %
    % Purpose
    % This method determines whether it is possible to begin an acquisiton. 
    % e.g. does the cutting position seem plausible, is the scanner ready
    % and conncted, are the axes connected, is there a recipe, is there 
    % enough disk space, etc. 
    %
    % Inputs
    % isBake - The method is run when the user initiates a bake or a previewScan.
    %       The isBake input is false by default. If true, more extensive checks
    %       are taken. 
    % 
    %
    % 
    % Behavior
    % The method returns true if acquisition is possible and false otherwise.
    % If it returns false and a second output argument is requested then 
    % this is a string that decribes why acquisition can not proceed. This 
    % string can be sent to a warning dialog box, etc, if there is a GUI. 


    if nargin<2
        isBake = false;
    end

    msg='';
    msgNumber=1;

    % An acquisition must not already be in progress
    if obj.acquisitionInProgress
        acquisitionPossible=false;
        msg=sprintf('%s%d) Acquisition already in progress\n', msg, msgNumber);
        msgNumber=msgNumber+1;
    end


    % We need a recipe connected and it must indicate that acquisition is possible
    if ~obj.isRecipeConnected
        msg=sprintf('%s%d) No recipe.\n', msg, msgNumber);
        msgNumber=msgNumber+1;
    end

    % We need a recipe connected and it must indicate that acquisition is possible
    if obj.isRecipeConnected && isempty(obj.recipe.tilePattern)
        msg=sprintf('%s%d) Tile pattern is empty. Likely you asked for pattern that has out of bounds positions.\n', msg, msgNumber);
        msgNumber=msgNumber+1;
    end

    % We need a scanner connected and it must be ready to acquire data
    if ~obj.isScannerConnected
        msg=sprintf('%s%d) No scanner is connected.\n' ,msg, msgNumber);
        msgNumber=msgNumber+1;
    end

    if obj.isScannerConnected && ~obj.scanner.isReady
        msg=sprintf('%s%d) Scanner is not ready to acquire data\n', msg, msgNumber);
        msgNumber=msgNumber+1;
    end


    if obj.isRecipeConnected && ~obj.recipe.acquisitionPossible
        msg=sprintf(['%s%d) Did you define the cutting position and front/left positions?\n'], msg, msgNumber);
        msgNumber=msgNumber+1;
    end

    % Check if PMT auto power on is selected. Try to turn it off but if
    % this fails we make the user do it. 
    if obj.scanner.disablePMTautoPower == false
        msgPMT = 'Uncheck PMT auto-on. PMTs will be turned off automatically when Bake completes.';
        msg = sprintf('%s%d) %s\n', msg, msgNumber, msgPMT);
        msgNumber=msgNumber+1;
    end
    
    %If a laser is connected, check it is ready
    if obj.isLaserConnected
        obj.laser.isPoweredOn %Sometimes laser claims it is off when it is not. This sesms to reset it.
        [isReady,msgLaser]=obj.laser.isReady;
        if ~isReady
            msg = sprintf('%s%d) The laser is not ready: %s\n', msg, msgNumber, msgLaser);
            msgNumber=msgNumber+1;
        end
    end

    %Check the axes are conncted
    if ~obj.isXaxisConnected
        msg=sprintf('%s%d) No xAxis is connected.\n', msg, msgNumber);
        msgNumber=msgNumber+1;
    end
    if ~obj.isYaxisConnected
        msg=sprintf('%s%d) No yAxis is connected.\n', msg, msgNumber);
        msgNumber=msgNumber+1;
    end

    %Only raise an error about the z axis and cutter if we have more than one section    
    if ~obj.isZaxisConnected
        if obj.isRecipeConnected && obj.recipe.mosaic.numSections>1
            msg=sprintf('%s%d) No zAxis is connected.\n', msg, msgNumber);
            msgNumber=msgNumber+1;
        end
    end
    if ~obj.isCutterConnected
        if obj.isRecipeConnected && obj.recipe.mosaic.numSections>1
            msg=sprintf('%s%d) No cutter is connected.\n', msg, msgNumber);
            msgNumber=msgNumber+1;
        end
    end


    % If this is a bake in autoROI mode and no stats are available, then do not proceed
    if isBake && strcmp(obj.recipe.mosaic.scanmode,'tiled: auto-ROI')
        if isempty(obj.autoROI) || ~isfield(obj.autoROI,'stats')
            msg=sprintf('%s%d) You must run Auto-Thresh before Baking.\n', msg, msgNumber);
            msgNumber=msgNumber+1;
        end
    end
    % END HACK
    

    % Ensure we have enough travel on the Z-stage to acquire all the sections. If not, just set to the maximum possible
    % This is also checked in the recipe. The only way this could happen is if:
    % 1) The user entrered the number of sections required whilst the z-stage was lowered then raised the z-stage.
    %    This could well happen.
    % 2 The z-stage was not connected when the recipe value was set, because then the distance available would not 
    %   have been checked in the recipe. This is wildly improbable, however. 
    % So the following will not stop anything from proceeding
    if obj.isRecipeConnected && obj.isZaxisConnected
        distanceAvailable = obj.zAxis.getMaxPos - obj.zAxis.axisPosition;  %more positive is a more raised Z platform
        distanceRequested = obj.recipe.mosaic.numSections * obj.recipe.mosaic.sliceThickness;

        if distanceRequested>distanceAvailable
            obj.recipe.mosaic.numSections = obj.recipe.mosaic.numSections+1;
        end
    end


    % Check if we will end up writing into existing directories
    if obj.isRecipeConnected && isBake
        n=0;
        origCurrentSectionNum = obj.currentSectionNumber; % store the current section number because it's going to be modified here
        for ii=1:obj.recipe.mosaic.numSections
            obj.currentSectionNumber = ii+obj.recipe.mosaic.sectionStartNum-1; % Sets obj.thisSectionDir
            if exist(obj.thisSectionDir,'dir')
                n=n+1;
            end
        end
        if n>0
            if n==1
                nDirStr='y';
            else
                nDirStr='ies';
            end
            msg=sprintf(['%s%d) Conducting acquisition in this directory would write data into %d existing section director%s.\n',...
                'Acquisition will not proceed.\nSolutions:\n\t* Start a new directory.\n\t* Change the sample ID name.\n',...
                '\t* Change the section start number.\n'], msg, msgNumber, n, nDirStr);
            msgNumber=msgNumber+1;
        end
        obj.currentSectionNumber = origCurrentSectionNum; % revert it
    end


    % If we are in auto-ROI mode, there must be ROI stats before a bake can proceed
    if strcmp(obj.recipe.mosaic.scanmode,'tiled: auto-ROI') && isBake && isempty(obj.autoROI)
        msg=sprintf('%s%d) You are in auto-ROI mode but have not obtained initial ROIs via Auto-Thresh.\n', msg, msgNumber);
        msgNumber=msgNumber+1;
    end

    % Stop the user baking an auto-ROI with different channels to those used for the preview
    if strcmp(obj.recipe.mosaic.scanmode,'tiled: auto-ROI') && isBake && ~isempty(obj.autoROI) && isfield(obj.autoROI,'stats')
        if ~isequal(obj.scanner.getChannelsToAcquire, obj.autoROI.stats.channelsToSave)
            msg=sprintf(['%s%d) You are trying to bake an auto-ROI with different channels to those used for obtaining the threshold. ', ...
                'To use these channels you must repeat preview scan and Auto-Thresh'], msg, msgNumber);
            msgNumber=msgNumber+1;
        end
    end

    % Is there a valid path to which we can save data?
    if isempty(obj.sampleSavePath)
        msg=sprintf('%s%d) No save path has been defined for this sample.\n', msg, msgNumber);
        msgNumber=msgNumber+1;
    end

    % If using ScanImage, did the user switch on all the PMTs for the channels being saved?
    if isa(obj.scanner,'SIBT') && ~isempty(obj.scanner.hC.hPmts.gains) && ...
        ~isequal(obj.scanner.getChannelsToAcquire,obj.scanner.getEnabledPMTs)
        msg=sprintf('%s%d) Check you have enabled the correct PMTs and try again.\n', msg,msgNumber);
        msgNumber=msgNumber+1;
    end

    % Do we have enough disk space for the acquisition to proceed?
    if obj.isRecipeConnected && exist(obj.sampleSavePath,'dir')
        acqInGB = obj.recipe.estimatedSizeOnDisk;
        volumeToWrite = strsplit(obj.sampleSavePath,filesep);
        volumeToWrite = volumeToWrite{1};
        out = BakingTray.utils.returnDiskSpace(volumeToWrite);

        if out.freeGB < acqInGB
            msg=sprintf('%s%d) There is not enough disk space for this acquisition. Free space= %0.1f GB. Required space= %0.1f GB\n',...
                msg, msgNumber, out.freeGB, acqInGB);
            msgNumber=msgNumber+1;
        end
    end



    % -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  
    %Set the acquisitionPossible boolean based on whether a message exists
    if isempty(msg)
        acquisitionPossible=true;
    else
        msg = sprintf('Acquisition is currently not possible\n%s',msg);
        acquisitionPossible=false;
    end

    %Print the message to screen if the user requested no output arguments. 
    if acquisitionPossible==false && nargout<2
        fprintf(msg)
    end

