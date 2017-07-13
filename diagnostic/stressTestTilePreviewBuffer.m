classdef stressTestTilePreviewBuffer < handle
%% stressTestTilePreviewBuffer
%
% During acquisition we seek to pull in tile data from the ScanImage tile buffer
% and use down-sampled versions of these to build a live preview of the tile #
% scanned sample. We also would like access to these data in order to do things 
% like scan only the sample. It's important to ensure that all images are placed
% in my buffer. This class runs a stress-test using a similar approach to that 
% employed in a full acquisition so that I can narrow down on the problem. 
%
%
% Instructions
% Set up ScanImage using a desired image size, channels, z-steps
% and reps. Then do:
% >> S=stressTestTilePreviewBuffer
% Set S.scannerType to "linear" if using linear scanners. Otherwise leave as "resonant"
% S.startTest
%
%
% Rob Campbell - July 2017


    properties
        loggedBufferData=[] % The (downsampled) images go into here 
        imageDownsampleProp=0.5 % Image data downsampled by this much before logging to loggedBuffferData. 
        verbose=false;
        defaultShutterIDs % The default shutter IDs used by the scanner
        scannerType='resonant' % Set to "linear" if using regular galvo/galvo
    end

    properties (Hidden)
        currentAcquisitionNumber=1
        armedListeners={}
        hC % The ScanImage object attaches here
    end


    methods

        %constructor
        function obj=stressTestTilePreviewBuffer

            W = evalin('base','whos');
            SIexists = ismember('hSI',{W.name});
            if ~SIexists
                fprintf('ScanImage not started. Can not connect to scanner.')
                delete(obj)
                return
            end

            obj.hC = evalin('base','hSI'); % get hSI from the base workspace

            if ~isa(obj.hC,'scanimage.SI')
                fprintf('hSI is not a ScanImage object.')
                delete(obj)
                return
            end

            % Log default state of the shutters because we will disable during acquisition and re-enable when we disarm
            obj.defaultShutterIDs = obj.hC.hScan2D.mdfData.shutterIDs;

            % Add armed listeners. These are listeners that will run during acquisition.
            obj.armedListeners{end+1}=addlistener(obj.hC.hUserFunctions, 'acqDone', @obj.tileAcqDone);
            obj.disableArmedListeners

            % Set some default settings (mainly for Z-stacks) to make the acquisition more similar
            % how we normally acquire data. 
            obj.hC.hFastZ.waveformType = 'step';     fprintf('Setting up z-scanning with "step" waveform\n')
            obj.hC.hFastZ.numVolumes=1;              fprintf('Setting numVolumes to 1\n')
            obj.hC.hFastZ.enable=1;                  fprintf('Enable fast z\n')
            obj.hC.hStackManager.framesPerSlice = 1; fprintf('Set frames per slice to 1\n')            
            obj.hC.hStackManager.stackReturnHome = 1;   fprintf('Set return z to home to true\n')
            obj.hC.hDisplay.volumeDisplayStyle='Tiled'; fprintf('Setting volume display style from 3D to Tiled\n')
        end % constructor


        % destructor
        function delete(obj)
            obj.disarmScanner
            cellfun(@delete,obj.armedListeners)
            obj.hC=[];
        end %destructor


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        function armScanner(obj)
            %Arm scanner and tell it to acquire a fixed number of frames (as defined below)
            % We'll need to enable external triggering on the correct terminal line. 
            % Safest to instruct ScanImage of this each time. 
            switch obj.scannerType
                case 'resonant'
                    %To make it possible to enable the external trigger. PFI0 is reserved for resonant scanning
                    obj.hC.hScan2D.trigAcqInTerm='PFI1';
                case 'linear'
                    obj.hC.hScan2D.trigAcqInTerm='PFI0';
                otherwise
                    fprintf('Failed to set up trigger. The scannerType property should be "linear" or resonant"\n')
            end

            if obj.hC.hDisplay.displayRollingAverageFactor>1
                fprintf('Setting display rolling average to 1\n')
                obj.hC.hDisplay.displayRollingAverageFactor=1;
            end

            obj.enableArmedListeners
            obj.hC.hScan2D.mdfData.shutterIDs=[]; %Disable shutters
            obj.currentAcquisitionNumber=1;

            %Pre-allocate the buffer
            blankImage = zeros([obj.hC.hRoiManager.pixelsPerLine,obj.hC.hRoiManager.linesPerFrame],'int16')-1E3;
            blankImage = imresize(blankImage,obj.imageDownsampleProp);
            % Now expand out to make a 5D array that is: [pixLin,linesFrame,z-depth,chans,acqs]
            obj.loggedBufferData= repmat(blankImage, [1,1, ...
                                        obj.hC.hFastZ.numFramesPerVolume, ...
                                        length(obj.hC.hChannels.channelsActive), ...
                                        obj.hC.acqsPerLoop]);


            %If any of these fail, we leave the function gracefully
            try
                obj.hC.extTrigEnable=1;
                %Put it into acquisition mode but it won't proceed because it's waiting for a trigger
                obj.hC.startLoop;
            catch ME1
                rethrow(ME1)
                return
            end

            fprintf('Scanimage armed\n')

        end %armScanner

        function disarmScanner(obj)
            if obj.hC.active
                fprintf('Scanner still in acquisition mode. Can not disarm.\n')
                return
            end

            obj.hC.extTrigEnable=0;  
            obj.hC.hScan2D.mdfData.shutterIDs=obj.defaultShutterIDs; %re-enable shutters
            obj.disableArmedListeners;

            fprintf('ScanImage disarmed\n')
        end %disarmScanner



        %---------------------------------------------------------------
        % Listener callback functions
        function tileAcqDone(obj,~,~)
            % This callback function constitutes part of an implicit loop that causes it to be
            % run repeatedly until all images have been acquired. It is run each time an acquisition
            % completes. 

            for z=1:length(obj.hC.hDisplay.stripeDataBuffer) %Loop through depths
                % scanimage stores image data in a data structure called 'stripeData'
                %ptr=obj.hC.hDisplay.stripeDataBufferPointer; % get the pointer to the last acquired stripeData (ptr=1 for z-depth 1, ptr=5 for z-depth, etc)
                lastStripe = obj.hC.hDisplay.stripeDataBuffer{z};

                msg='';
                if isempty(lastStripe)
                    msg = sprintf('obj.hC.hDisplay.stripeDataBuffer{%d} is empty. ',z);
                elseif ~isprop(lastStripe,'roiData')
                    msg = sprintf('obj.hC.hDisplay.stripeDataBuffer{%d} has no field "roiData"',z);
                elseif ~iscell(lastStripe.roiData)
                    msg = sprintf('Expected obj.hC.hDisplay.stripeDataBuffer{%d}.roiData to be a cell. It is a %s.',z, class(lastStripe.roiData));
                elseif length(lastStripe.roiData)<1
                    msg = sprintf('Expected obj.hC.hDisplay.stripeDataBuffer{%d}.roiData to be a cell with length >1',z);
                end

                if ~isempty(msg)
                    msg = [msg, 'NOT EXTRACTING TILE DATA IN stressTestTilePreviewBuffer.tileAcqDone\n'];
                    fprintf(msg)
                    break
                end

                for ii = 1:length(lastStripe.roiData{1}.channels) % Loop through channels
                    obj.loggedBufferData(:,:,z,ii,obj.currentAcquisitionNumber) = ...
                        int16( imresize(lastStripe.roiData{1}.imageData{ii}{1}, obj.imageDownsampleProp) );
                end % loop through channels

                if obj.verbose
                    fprintf('Placed data from frameNumberAcq=%d (%d) ; frameTimeStamp=%0.4f\n', ...
                        lastStripe.frameNumberAcq, ...
                        lastStripe.frameNumberAcqMode, ...
                        lastStripe.frameTimestamp)
                end % if verbose
            end % z=1:length...


            fprintf('Completed acquisition %d\n', obj.currentAcquisitionNumber)
            obj.currentAcquisitionNumber = obj.currentAcquisitionNumber+1;

            switch obj.hC.acqState
                case 'loop'
                    obj.hC.hScan2D.trigIssueSoftwareAcq;
                case 'idle'
                    obj.disarmScanner
                otherwise
                    fprintf('ScanImage is in state: %s\n',obj.hC.acqState)
            end % switch

        end % tileAcqDone

    
        function startTest(obj)
            obj.armScanner
            obj.hC.hScan2D.trigIssueSoftwareAcq;
        end        

    end % close methods        


    methods (Hidden)
        function enableArmedListeners(obj)
            % Loop through all armedListeners and enable each
            for ii=1:length(obj.armedListeners)
                obj.armedListeners{ii}.Enabled=true;
            end
        end % enableArmedListeners

        function disableArmedListeners(obj)
            % Loop through all armedListeners and disable each
            for ii=1:length(obj.armedListeners)
                obj.armedListeners{ii}.Enabled=false;
            end
        end % disableArmedListeners
    end % close hidden methods



end % close classdef
