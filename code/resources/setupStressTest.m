classdef setupStressTest < handle

   
    properties
        API %scanimage API attaches here
        U %user-function definition structure
        UserFcnName='BT_SI_simpleTest' %user function file name
        acqsPerLoop=80
        numLoops=10
        defaultShutterIDs

        listeners
    end %properties


    methods
        function obj=setupStressTest
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
            %get the scanimage object from the base workspace
            scanimageObjectName='hSI';
            W = evalin('base','whos');
            SIexists = ismember(scanimageObjectName,{W.name});
            
            if ~SIexists
                disp('No ScanImage API hook in base workspace')
                return
            end


            obj.API = evalin('base',scanimageObjectName); % get hSI from the base workspace
            if ~isa(obj.API,'scanimage.SI')
                disp('No ScanImage API hook in base workspace')
                return
            end

            if ~strcmpi(obj.API.acqState,'idle');
                disp('ScanImage is occupied')
                return
            end


            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
            %Set up a user function hooks
            n=1;
            obj.U(n).EventName='acqDone';
            obj.U(n).UserFcnName='BT_SI_simpleTest';
            obj.U(n).Arguments={};
            obj.U(n).Enable=0;

            n=n+1;
            obj.U(n).EventName='acqModeStart';
            obj.U(n).UserFcnName='BT_SI_simpleTest';
            obj.U(n).Arguments={};
            obj.U(n).Enable=0;

            n=n+1;
            obj.U(n).EventName='acqModeDone';
            obj.U(n).UserFcnName='BT_SI_simpleTest';
            obj.U(n).Arguments={};
            obj.U(n).Enable=0;

            n=n+1;
            obj.U(n).EventName='frameAcquired';
            obj.U(n).UserFcnName='BT_SI_simpleTest';
            obj.U(n).Arguments={};
            obj.U(n).Enable=0;
            obj.API.hUserFunctions.userFunctionsCfg=obj.U; %This will wipe the existing user functions!

           
            obj.listeners{1}=addlistener(obj.API.hStackManager, 'stackSlicesDone', 'PostSet', @obj.listenerFunc ); %

        end %constructor

        function delete(obj)
            obj.disarmScanner
            cellfun(@delete,obj.listeners)
            obj.API=[];
        end


        function armScanner(obj)
            %activate the user-functions


            obj.toggleUserFunction(true); 

            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
            % Set up scan parameters

            %Enable an external trigger
            switch lower(obj.API.hScan2D.scannerType)
                case 'resonant'
                    obj.API.hScan2D.trigAcqInTerm='PFI1';
                case 'linear'
                    obj.API.hScan2D.trigAcqInTerm='PFI0';
            end

            %Set imaging parameters for linear scanners
            if strcmpi(obj.API.hScan2D.scannerType,'linear')
                obj.API.hScan2D.pixelBinFactor = 4;
                obj.API.hScan2D.sampleRate = 1.25E6;
                obj.API.hRoiManager.pixelsPerLine=200;
                obj.API.hRoiManager.linesPerFrame=200;
            end

            % Fast z
            obj.API.hFastZ.waveformType='step';
            obj.API.hFastZ.numVolumes=1; %Always
            obj.API.hFastZ.enable=1;
            obj.API.hStackManager.framesPerSlice=1; %number of frames per grab per layer
            obj.API.hStackManager.stackZStepSize = 25; %step size in microns
            obj.API.hStackManager.numSlices = 3;
            obj.API.hStackManager.stackReturnHome = 1;
            obj.API.hFastZ.flybackTime = 50/1000;

            obj.API.hBeams.pzAdjust=true;
            obj.API.hBeams.lengthConstants=180;
            
            %We typically run acquisitions with these set:
            obj.API.hBeams.flybackBlanking=false;
            obj.API.hScan2D.mdfData.stripingMaxRate=1; 
            obj.API.hDisplay.volumeDisplayStyle='Current';
            obj.API.hScan2D.logFilePerChannel = true;

            
            obj.API.acqsPerLoop=obj.acqsPerLoop; % This many z-stacks per loop
            obj.API.extTrigEnable=1; % So we acuire z-stacks on a trigger
            obj.defaultShutterIDs = obj.API.hScan2D.mdfData.shutterIDs;
            obj.API.hScan2D.mdfData.shutterIDs=[]; %Disable shutters
        end %armScanner

        function disarmScanner(obj)
            % Tidy a little
            %Disable fast z
            obj.API.hStackManager.numSlices = 1;
            obj.API.hStackManager.stackZStepSize = 0;
            obj.API.hFastZ.enable=0;
            obj.API.extTrigEnable=0; 

            %De-activate the user functions
            obj.toggleUserFunction(false); %activate the user-functions
            obj.API.hScan2D.mdfData.shutterIDs=obj.defaultShutterIDs;
        end %disarmScannerde
       



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        function toggleUserFunction(obj,toggleStateTo)
            %find userfunction with UserFcnName and toggle its Enable state to toggleStateTo
               names={obj.API.hUserFunctions.userFunctionsCfg.UserFcnName};
            ind=strmatch(obj.UserFcnName,names,'exact');

            for ii=1:length(ind)
                obj.API.hUserFunctions.userFunctionsCfg(ind(ii)).Enable=toggleStateTo;
            end
            success=true;
        end %toggleUserFunction


        function runStressTest(obj)
            obj.armScanner

            for ii=1:obj.numLoops %do a bunch of rounds of these z-stacks
                fprintf('Doing zstack series %d/%d\n',ii,obj.numLoops)

                obj.API.startLoop;
                obj.API.hScan2D.trigIssueSoftwareAcq; %next z-stack initiated in user-function

                pause(0.5)

                %Wait until it's done
                while 1
                    if obj.API.active
                        pause(0.5)
                    else
                        break
                    end                
                end
            end
            obj.disarmScanner
        end %runStressTest
    
        function listenerFunc(obj,~,~)
            %Does nothing
        end
    end %methods

end %classdef