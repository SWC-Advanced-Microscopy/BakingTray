classdef trigViaAPI_test < handle

    properties
        % If true you get debug messages printed during scanning and when listener callbacks are hit
        verbose=false;
        listeners={}
        hC % scanner connected here
    end


    methods %This is the main methods block. These methods are declared in the scanner abstract class

        %constructor
        function obj=trigViaAPI_test
            obj.connect;
        end %constructor


        %destructor
        function delete(obj)
            cellfun(@delete,obj.listeners)
            obj.hC=[];
        end %destructor

         function success = connect(obj,API)
            %TODO: why the hell isn't this in the constructor?
            success=false;

            scanimageObjectName='hSI';
            W = evalin('base','whos');
            SIexists = ismember(scanimageObjectName,{W.name});
            if ~SIexists
                obj.logMessage(inputname(1),dbstack,7,'ScanImage not started. Can not connect to scanner.')
                return
            end

            API = evalin('base',scanimageObjectName); % get hSI from the base workspace
            obj.hC=API;

            fprintf('\n\nStarting SIBT interface for ScanImage\n')

            % Add ScanImage-specific listeners
            obj.listeners{end+1}=addlistener(obj.hC.hUserFunctions, 'acqDone', @obj.tileAcqDone);

            success=true;
        end %connect


        function tileAcqDone(obj,~,~)
            % This callback function is run once an image is acquired
            if obj.verbose
                fprintf('In tileAcqDone\n')
            end
            pause(0.9)
            obj.initiateTileScan  % start another scan

        end


        function success = armScanner(obj)
            %Arm scanner and tell it to acquire a fixed number of frames (as defined below)
            success=false;


            % We'll need to enable external triggering on the correct terminal line. 
            % Safest to instruct ScanImage of this each time. 
           trigLine='PFI1';

            if ~strcmp(obj.hC.hScan2D.trigAcqInTerm, trigLine)
                obj.hC.hScan2D.trigAcqInTerm=trigLine;
            end


            if obj.hC.hDisplay.displayRollingAverageFactor ~=1
                obj.hC.hDisplay.displayRollingAverageFactor=1; % We don't want to take rolling averages
            end


            % Set the system to display just the first depth in ScanImage. 
            % Should run a little faster this way, especially if we have 
            % multiple channels being displayed.
            if obj.hC.hStackManager.numSlices>1 && isempty(obj.hC.hDisplay.selectedZs)
            fprintf('Displaying only first depth in ScanImage for speed reasons.\n');
                obj.hC.hDisplay.volumeDisplayStyle='Current';
                obj.hC.hDisplay.selectedZs=0;
            end

            try
                obj.hC.acqsPerLoop=15; % This is the number of images to acquire
                obj.hC.extTrigEnable=1;
                %Put it into acquisition mode but it won't proceed because it's waiting for a trigger
                obj.hC.startLoop;
            catch ME1
                rethrow(ME1)
                return
            end
            success=true;

            fprintf('Armed scanner: %s\n', datestr(now))
        end %armScanner


        function initiateTileScan(obj)
            % If tile-scanning we initiate the next tile simply by issuing a software trigger.
            % If ribbon-scanning it is triggered from the stage itself when it starts move
            % and so comes in through the defined PFI line in ScanImage, thus initiateTileScan
            % must start a stage motion rather than send a trigger

            if obj.verbose
                fprintf('In initiateTileScan\n')
            end

            triggerType='soft';

            switch triggerType
                case 'soft'

                    if obj.verbose
                        fprintf('Initiating a soft-trigger to acquire next image \n')
                    end
                    obj.hC.hScan2D.trigIssueSoftwareAcq;
                case 'fromStage'
                    %DOES NOTHING RIGHT NOW
            end
        end %initiateTileScan

    end % Methods

end
