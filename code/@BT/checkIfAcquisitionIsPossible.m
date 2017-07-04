function [acquisitionPossible,msg] = checkIfAcquisitionIsPossible(obj)
    % Check if acquisition is possible 
    %
    % [acquisitionPossible,msg] = BT.checkIfAcquisitionIsPossible(obj)
    %
    % Purpose
    % This method determines whether it is possible to begin an acquisiton. 
    % e.g. does the cutting position seem plausible, is the scanner ready
    % and conncted, etc. 
    % 
    % Behavior
    % The method returns true if acquisition is possible and false otherwise.
    % If it returns false and a second output argument is requested then 
    % this is a string that decribes why acquisition can not proceed. This 
    % string can be sent to a warning dialog box, etc, if there is a GUI. 



    msg='';

    % An acquisition must not already be in progress
    if obj.acquisitionInProgress
        acquisitionPossible=false;
        msg=sprintf('%sAcquisition already in progress\n', msg);
    end


    % We need a recipe connected and it must indicate that acquisition is possible
    if ~obj.isRecipeConnected
        msg=sprintf('%sNo recipe.\n',msg);
    end

    if obj.isRecipeConnected && ~obj.recipe.acquisitionPossible
        msg=sprintf(['%sAcquisition is not currently possible.\n', ...
            'Did you define the cutting position and front/left positions?\n'], msg);
    end


    % We need a scanner connected and it must be ready to acquire data
    if ~obj.isScannerConnected
        msg=sprintf('%sNo scanner is connected.\n',msg);
    end

    if obj.isScannerConnected && ~obj.scanner.isReady
        msg=sprintf('Scanner is not ready to acquire data\n');
    end

    %If a laser is connected, check it is ready
    if obj.isLaserConnected
        [isReady,msgLaser]=obj.laser.isReady;
        if ~isReady
            msg = sprintf('%sThe laser is not ready: %s\n', msg, msgLaser);
        end
    end

    %Check the axes are conncted
    if ~obj.isXaxisConnected
        msg=sprintf('%sNo xAxis is connected.\n',msg);
    end
    if ~obj.isYaxisConnected
        msg=sprintf('%sNo yAxis is connected.\n',msg);
    end

    %Only raise an error about the z axis and cutter if we have more than one section    
    if ~obj.isZaxisConnected
        if obj.isRecipeConnected && obj.recipe.mosaic.numSections>1
            msg=sprintf('%sNo zAxis is connected.\n',msg);
        end
    end
    if ~obj.isCutterConnected
        if obj.isRecipeConnected && obj.recipe.mosaic.numSections>1
            msg=sprintf('%sNo cutter is connected.\n',msg);
        end
    end


    % Ensure we have enough travel on the Z-stage to acquire all the sections
    if obj.isRecipeConnected && obj.isZaxisConnected
        distanceAvailable = obj.zAxis.getMaxPos - obj.zAxis.axisPosition;  %more positive is a more raised Z platform
        distanceRequested = obj.recipe.mosaic.numSections * obj.recipe.mosaic.sliceThickness;

        if distanceRequested>distanceAvailable
            numSlicesPossible = floor(distanceAvailable/obj.recipe.mosaic.sliceThickness)-1;
            fprintf(['\n%sRequested %d slices: this is %0.2f mm of tissue but only %0.2f mm is possible.\n',...
                'You can safely cut a maximum of %d slices.\n',...
                'Change your settings or sample position and try again.\n\n'], ...
             msg,...
             obj.recipe.mosaic.numSections,...
             distanceRequested, ...
             distanceAvailable,...
             numSlicesPossible);
        end
    end


    % Check if we will end up writing into existing directories
    if obj.isRecipeConnected
        n=0;
        for ii=1:obj.recipe.mosaic.numSections
            obj.currentSectionNumber=ii+obj.recipe.mosaic.sectionStartNum-1;
            %TODO: abstract the following line somewhere. It also appears in BT.defineSavePath
            saveDir = sprintf('%s-%04d', obj.recipe.sample.ID, obj.currentSectionNumber);
            if exist(saveDir,'dir')
                n=n+1;
            end
        end
        if n>0
            if n==1
                nDirStr='y';
            else
                nDirStr='ies';
            end
            msg=sprintf(['%sConducting acquisition in this directory would write data into %d existing section directory%s.\n',...
                'Acquisition will not proceed.\nSolutions:\n\t* Start a new directory.\n\t* Change the sample ID name.\n',...
                '\t* Change the section start number.\n'],msg,n,nDirStr);
        end
    end


    % Ensure that we will display only one channel. This is potentially important for speed reasons
    % TODO: maybe make this a setting?
    if  obj.isScannerConnected && strcmpi(obj.scanner.scannerType,'linear')
        n=length(obj.scanner.channelsToDisplay);
        if n>1
            msg=sprintf(['%sScanImage is currently configured to display %d channels\n',...
                    'Acquisition may be faster with just one channel selected for display.\n', ...
                    'Please go to the CHANNELS window in ScanImage and leave only one channel checked in the "Display" column\n'],msg,n);
        end
    end


    % Is there a valid path to which we can save data?
    if isempty(obj.sampleSavePath)
        msg=sprintf(['%sNo save path has been defined for this sample.\n'],msg);
    end


    % -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  
    %Set the acquisitionPossible boolean based on whether a message exists
    if isempty(msg)
        acquisitionPossible=true;
    else
        acquisitionPossible=false;
    end


    %Print the message to screen if the user requested no output arguments. 
    if acquisitionPossible==false && nargout<2
        fprintf(msg)
    end

