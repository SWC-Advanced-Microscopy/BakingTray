function out = estimateTimeRemaining(obj,scnSet,numTilesPerOpticalSection)
    % Estimate time an acquisition will take
    %
    % function out = BT.estimateTimeRemaining(scnSet,numTilesPerOpticalSection)
    %
    % Purpose
    % Uses BT.sectionCompletionTimes to estimate how much time is left assuming we acquire
    % all sections. If no sections have been completed, BT.sectionCompletion times will be
    % empty. In this case we estimate how long it will take from the scan settings. If data
    % have already been acquired, then the projected completion time is just the average
    % section time multiplied by the number of remaining sections.
    %
    % Optional input arguments used to speed up this method
    % scnSet - the output of obj.scanner.returnScanSettings
    % numTilesPerOpticalSection - output of obj.recipe.NumTiles.X * obj.recipe.NumTiles.Y
    %
    % Returns a structure containing information about when the recording will finish
    %
    % Rob Campbell

    out=[];

    if ~obj.isRecipeConnected
        return
    end


    if ~isempty(obj.sectionCompletionTimes) && obj.acquisitionInProgress
        %If we determine how long the acquisition will take using observed section times.
        mu=mean(obj.sectionCompletionTimes);
        sectionsRemaining = obj.recipe.mosaic.numSections-obj.currentSectionNumber;
        out.timePerSectionInSeconds = mu;
        out.timeLeftInSeconds = sectionsRemaining * mu;

    elseif obj.isScannerConnected
        if nargin<2
            scnSet = obj.scanner.returnScanSettings;
        end
        if nargin<3
            numTilesPerOpticalSection = obj.recipe.NumTiles.X * obj.recipe.NumTiles.Y;
        end

        approxTimePerSection = scnSet.framePeriodInSeconds * ...
                            (obj.recipe.mosaic.numOpticalPlanes + ...
                            obj.recipe.mosaic.numOverlapZPlanes ) * ...
                            numTilesPerOpticalSection * ...
                            scnSet.averageEveryNframes;

        % Guesstimate 375 ms per X/Y move plus something added on for buffering time.
        motionTime = numTilesPerOpticalSection*0.375;
        approxTimePerSection = round(approxTimePerSection + motionTime);
        out.motionTime = motionTime;

        %Estimate cut time
        out.cutTime = (obj.recipe.mosaic.cutSize/obj.recipe.mosaic.cuttingSpeed) + 12;
        out.timePerSectionInSeconds = approxTimePerSection+out.cutTime;
        %Use all sections because nothing would have been imaged
        out.timeLeftInSeconds = out.timePerSectionInSeconds * obj.recipe.mosaic.numSections;
    else
        fprintf('Failed to calculate sample completion time\n')
        return
    end

    out.timePerSectionString = prettyTime(out.timePerSectionInSeconds);
    out.timeForSampleString = prettyTime(out.timeLeftInSeconds);
    timeToConvertToString = now+(out.timeLeftInSeconds/(24*60^2));
    if ~isnan(timeToConvertToString)
        out.expectedFinishTimeString = ...
        datestr(now+(out.timeLeftInSeconds/(24*60^2)), 'dd-mm-yyyy, HH:MM');
    end


end %estimateTimeRemaining
