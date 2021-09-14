classdef pos_tester < handle
    % pos_tester
    %
    % 
    % Rob Campbell - SWC 2019



    % The following properties relate to settings the user can modify to alter the behavior of the class
    properties
        cam      % The camera class
        linStage % A fully set up BakingTray linear stage object
        camToStart=2; %Default camera mode start
        pixSize     % Pixel size of camera in microns
    end

    properties (Hidden)
        startTime % time stamp when the acquisition started, so we can calculate average frame rate
    end



    % Constructor and destructor
    methods
        function obj = pos_tester(camToStart,linStage)
            % pos_tester constructor
            %
            % obj = pos_tester(camToStart,linStage)
            %
            % Inputs
            % camToStart - Optional input argument defining which camera is to be connected to on startup
            % linStage - a set up BakingTray linear controller and attached stage
            %
            % Example (connecting to a 100 mm travel range linear stage)
            % tStage = genericStage;
            % tStage.axisName='xaxis'
            % tStage.minPos=0;
            % tStage.maxPos=100;
            %
            % Z=genericZaberController(tStage);
            % Z.connect('com3')
            %
            % p=pos_tester(2,Z);
            %
        

            if nargin<1
                camToStart = obj.camToStart;
            end


            if nargin>1
                obj.linStage = linStage;
            end


            % Connect to the camera and bail out if this fails
            try
                obj.cam = mxy.camera(camToStart);

                % Acquire a strip of pixels so we get a higher frame rate
                obj.cam.src.ROIZoneSize = 500;
                obj.cam.src.ROIZoneOffset = 400;
                obj.cam.src.ROIZoneMode = 'On';

                % Increase exposure a touch
                obj.cam.src.ExposureTime = 4000;

                %vid.TriggerRepeat = Inf;

                rPos = obj.cam.vid.ROIPosition;

                preview(p.cam.vid)

            catch ME
                delete(obj)
                rethrow(ME)
            end
        end % Close constructor


        function delete(obj)
            % Destructor
            delete(obj.cam)
            delete(obj.hFig)
        end % Close destructor

    end % Close block containing constructor and destructor



    % Short methods
    methods

        function startCam(obj)
            % Set up the camera to start acquiring frames 
            obj.cam.stopVideo
            obj.cam.flushdata;
            obj.startTime = now;
            obj.cam.startVideo

        end

        function varargout = runStagePosSequence(obj,seq)
            % seq is a relative move sequence in mm
            obj.startCam
            obj.startTime=tic;

            pause(0.25) % So we have a baseline

            for ii=1:length(seq)
                if ~isempty(obj.linStage)
                    obj.linStage.relativeMove(seq(ii));
                end
            end
            elapsedTime = toc(obj.startTime);
            obj.cam.stopVideo

            fps = round(obj.cam.vid.framesAcquired/elapsedTime);

            fprintf('Ran at %d fps\n',fps)

            warning off 
            imStack = squeeze(getdata(obj.cam.vid));
            warning on

            out.fps = fps;
            out.imStack = imStack;
            out.seq = seq;

            if nargout>0
                varargout{1}=out;
            end
        end % runStagePosSequence


    end % Close block containing short methods



    % Callback functions
    methods

        function closeFig(obj,~,~)
            obj.delete
        end

    end % Close block containing callbacks


end % close pos_tester

