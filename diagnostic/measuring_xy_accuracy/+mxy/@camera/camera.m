classdef camera < handle
    % mxy.camera
    %
    % Purpose
    % This class acts as an interface between the diffusersensor class and the MATLAB 
    % image acquisition toolbox. 
    % TODO - Currently this class does nothing very interesting, but in future it will 
    %        ensure there is a consistent interface for handling things like camera exposure.
    %
    %
    % e.g.
    % >> c= mxy.camera
    %   1  -  videoinput('gentl', 1, 'Mono12')
    %   2  -  videoinput('gentl', 1, 'Mono8')
    %
    %  Enter device number and press return: 2


    properties
        vid   % Holds the camera object
        src   % Holds the camera-specific properties
    end




    methods
        function obj = camera(camToStart)
            if nargin<1 || isempty(camToStart)
                camToStart=[];
            end

            if strcmpi(camToStart,'demo')

                fprintf('dws.camera is starting with a dummy camera\n')
                obj.demoMode
                return
            end

            % Find which adapters are installed
            cams=imaqhwinfo;
            if isempty(cams.InstalledAdaptors)
                fprintf('NO CAMERAS FOUND by dws.camera\n');
                return
            end

            % Loop through each combination of camera and formats and build commands to start each
            constructorCommands = {};
            for ii=1:length(cams.InstalledAdaptors)
                tDevice = imaqhwinfo(cams.InstalledAdaptors{ii});
                if isempty(tDevice.DeviceIDs)
                    continue
                end
                formats = tDevice.DeviceInfo.SupportedFormats;
                for jj=1:length(formats)
                    tCom = tDevice.DeviceInfo.VideoInputConstructor; % command to connect to device
                    tCom = strrep(tCom,')',[', ''',formats{jj},''')'] );
                    constructorCommands = [constructorCommands,tCom];
                end

            end

            constructorCommand=[];
            if length(constructorCommands)==1
                constructorCommand = constructorCommands{1};
            elseif length(constructorCommands)>1 && isempty(camToStart)
                for ii=1:length(constructorCommands)
                    fprintf('%d  -  %s\n',ii,constructorCommands{ii})
                end
                IN='';
                fprintf('\n')
                while isempty(IN) | IN<0 | IN>length(constructorCommands)
                    IN = input('Enter device number and press return: ','s');
                    IN = str2num(IN);
                end
                constructorCommand = constructorCommands{IN};

            elseif length(constructorCommands)>1 && length(camToStart)==1
                fprintf('Available interfaces:\n')
                for ii=1:length(constructorCommands)
                    fprintf('%d  -  %s\n',ii,constructorCommands{ii})
                end
                fprintf('\nConnecting to number %d\n', camToStart)
                constructorCommand = constructorCommands{camToStart};
            else
                fprintf('NO CAMERAS FOUND by dws.camera\n');             
            end


            %Runs one of the camera functions in the camera private sub-directory
            if ~isempty(constructorCommand)
                obj.vid = eval(constructorCommand);
                obj.src = getselectedsource(obj.vid);

                % Set up the camera so that it is manually triggerable an 
                % unlimited number of times. 
                triggerconfig(obj.vid,'manual')
                vid.TriggerRepeat=inf;
                obj.vid.FramesPerTrigger = inf;
                obj.vid.FramesAcquiredFcnCount=10; %Run frame acq fun every frame
            else
                obj.demoMode
            end

        end % close constructor


        function delete(obj)
            if isa(obj.vid,'videoinput')
                stop(obj.vid)
                delete(obj.vid)
            end
        end % close destructor


        function startVideo(obj)
            if isa(obj.vid,'videoinput')
                start(obj.vid)
                trigger(obj.vid)
            end
        end

        function stopVideo(obj)
            if isa(obj.vid,'videoinput') && isrunning(obj.vid)
                stop(obj.vid)
            end
        end

        function flushdata(obj)
            if isa(obj.vid,'videoinput')
                flushdata(obj.vid)
            end
        end

        function lastFrame=getLastFrame(obj)
            if isa(obj.vid,'videoinput')
                lastFrame=squeeze(peekdata(obj.vid,1));
            end
        end

        function vidRunning=isrunning(obj)
            if isa(obj.vid,'videoinput')
                vidRunning=isrunning(obj.vid);
            else
                vidRunning = false;                
            end
        end

        function nFrm=framesAcquired(obj)
            if isa(obj.vid,'videoinput')
                nFrm=obj.vid.FramesAcquired;
            else
                nFrm=0;
            end
        end

        function demoMode(obj)
            % Set up a few hard-coded properties so that diffusersensor runs
            % with no camera
            obj.vid.ROIPosition=[0,0,2048,2048]; % Make up a sensor size
        end



    end

end

