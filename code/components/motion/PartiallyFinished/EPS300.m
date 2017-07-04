classdef EPS300 < linearcontroller 
% EPS300 is a class that inherits linearcontroller and defines the interface between
% Baking Tray and Newport's EPS300 controller. 
%
% 
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%


    properties (Hidden)

      % Define the default properties for the serial port connection. 
      % Unlikely these will need changing, but they're here in case
      BaudRate=19200
      StopBits=1
      DataBits=8
      Parity='none'
      Terminator='CR'
    end %close public properties
      

    methods
        
      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function obj=EPS300(stageObject,logObject)

        if nargin<1
          stageObject=[];
        end
        if nargin<2
          logObject=[];
        end

        obj.maxStages=3;

        if ~isempty(stageObject)
          obj.attachLinearStage(stageObject);
        end

        if ~isempty(logObject)
            obj.attachLogObject(logObject);
        end
      end %constructor


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function delete(obj)
        obj.logMessage(inputname(1),dbstack,2,'Closing EPS300');
        fclose(obj.hC);
      end %destructor


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = connect(obj,comPort)
        %Connect to the EPS300 over a serial connection
        
        if ~obj.isStageConnected
          obj.logMessage(inputname(1),dbstack,7,'Not completing connection routine. Closing')
          success=false;
          return
        end

        %First clear any references to this port
        instances = instrfind('Port',comPort);
        for ii=1:length(instances)
            delete(instances(ii))
        end

        obj.hC = serial(comPort,...
                  'BaudRate'  , obj.BaudRate,...
                  'StopBits'  , obj.StopBits,...
                  'DataBits'  , obj.DataBits,...
                  'Parity'    , obj.Parity,...
                  'Terminator', obj.Terminator);
        set(obj.hC,'TimeOut',3);

        fopen(obj.hC);

        success = obj.isControllerConnected;

        %Set all connected stages to trapizoidal trajectory mode
        for ii=1:length(obj.attachedStages) %TODO: THIS WILL NO LONGER WORK. NEW SCHEME HAS ONE STAGE ATTACHED TO THE OBJECT AND COPIES OF THE OBJECT FOR EACH AXIS
          ID = obj.attachedStages{ii}.axisID;
          obj.serialSendReceive([ID,'TJ1']);
        end

        if ~success
            msg = sprintf('Failed to connect to EPS300 on port %s',comPort);
            obj.logMessage(inputname(1),dbstack,7,msg);
        end


      end %connect

        

      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = isControllerConnected(obj)
        success=false;
        if isempty(obj.hC)
          fprintf('No attempt to connect to the controller has been made\n')
          return
        end

        try 
          str = obj.serialSendReceive('VE?'); %VE just gets the firmwware version
          if length(str)<=1
              obj.logMessage(inputname(1),dbstack,7,'Failed to connect to EPS300')
              return
          else
              success=true;
          end
        catch
            L=lasterror;
            obj.logMessage(inputname(1),dbstack,7,['Failed to connect to EPS300 and there was an error: ', L.message])
        end
      end %isControllerConnected



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function moving = isMoving(obj, axisName) 
        if nargin<2
          axisName=[];
        end

        [ready,ID]=obj.isAxisReady(axisName);
        if ~ready
          pos=[];
          return
        end
        
        %The current velocity
        str = obj.serialSendReceive([ID,'TV?']); 
        vel = str2double(str);

        if vel==0
          moving=false;
        else
          moving=true;
        end

      end %isMoving



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function pos = axisPosition(obj, axisName)
        if nargin<2
          axisName=[];
        end

        [ready,ID]=obj.isAxisReady(axisName);
        if ~ready
          pos=[];
          return
        end

        str = obj.serialSendReceive([ID,'TP?']);
        pos = str2double(str);

        st = obj.returnStageObject;
        pos = st.transformDistance(pos);
      end %axisPosition



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = relativeMove(obj,distanceToMove, axisName)
        if nargin<3
          axisName=[];
        end

        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          return
        end

        if ~isnumeric(distanceToMove) || ~isscalar(distanceToMove)
          obj.logMessage(inputname(1),dbstack,6,'distanceToMove must be a number')
          success=false;
          return
        end

        %Check that it's OK to move here
        willMoveTo = distanceToMove+obj.axisPosition;
        if ~obj.isMoveInBounds(willMoveTo)
          success=false;
          return
        end

        obj.logMessage(inputname(1),dbstack,1,sprintf('moving by %0.f',distanceToMove));

        st = obj.returnStageObject;
        cmd = sprintf('%sPR%f', ID, st.transformDistance(distanceToMove) );
        obj.serialSendReceive(cmd);

        success=true;

      end %relativeMove



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = absoluteMove(obj, targetPosition, axisName)
        if nargin<3
          axisName=[];
        end

        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          return
        end

        if ~obj.isMoveInBounds(targetPosition)
          success=false;
          return
        end

        obj.logMessage(inputname(1),dbstack,1,sprintf('moving to %0.f',targetPosition));

        st = obj.returnStageObject;
        cmd = sprintf('%sPA%f', ID, st.transformDistance(targetPosition)); %TODO: check this
        obj.serialSendReceive(cmd);

        success=true;

      end %absoluteMove



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = stopAxis(obj, axisName)
        if nargin<2
          axisName=[];
        end

        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          return
        end
        
        obj.serialSendReceive([ID,'ST']);
        success=true;
      end


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function posUnits = getPositionUnits(obj, axisName)
        if nargin<2
          axisName=[];
        end

        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          posUnits = 'FAILED';
        end

        str = obj.serialSendReceive([ID,'SN?']);
        switch str
            case '0'
              posUnits='encoder count';
            case '1'
              posUnits='motor step';
            case '1'
              posUnits='motor step';
            case '2'
              posUnits='millimeter';
            case '3'
              posUnits='micrometer';
            case '4'
              posUnits='inches';
            otherwise
              posUnits='UKNOWN UNIT';
        end
 
      end %getPositionUnits

      function success=setPositionUnits(obj,controllerUnits,axisName)
        if nargin<3
          axisName=[];
        end

        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          return;
        end
        if isnumeric(controllerUnits)
          controllerUnits = num2str(controllerUnits);
        end

        obj.serialSendReceive([ID,'SN',controllerUnits]);

        actualPosUnits = obj.serialSendReceive([ID,'SN?',controllerUnits]);
        if strcmp(controllerUnits,actualPosUnits)
          success=true;
        else
          msg = sprintf('Attempted to set axis %s units to %s but failed. They are %s (%s)',...
            ID, controllerUnits, actualPosUnits, obj.getPositionUnits(axisName))
          obj.logMessage(inputname(1),dbstack,7,msg);
          success=false;
        end

      end %setPositionUnits




      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function minPos=getMinPos(obj, axisName)
        if nargin<2
          axisName=[];
        end
        [minPos,st,ID]=getMinPos@linearcontroller(obj,axisName);

        if isempty(minPos)
          %TODO: TEST THE FOLLOWING: MAY NOT BE CORRECT RIGHT NOW
          minPos = str2double(str2num(obj.serialSendReceive([ID,'SL?'])))
        end
      end

      function maxPos=getMaxPos(obj,axisName)
        if nargin<2
          axisName=[];
        end
        [maxPos,st,ID]=getMaxPos@linearcontroller(obj,axisName);

        if isempty(maxPos)
          %TODO: TEST THE FOLLOWING: MAY NOT BE CORRECT RIGHT NOW
          maxPos = str2double(str2num(obj.serialSendReceive([ID,'SR?'])))
        end
      end


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      % get or set speed and acceleration settings 

      function velocity = getMaxVelocity(obj, axisName)
        if nargin<2
          axisName=[];
        end

        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          velocity=false;
          return
        end
        str = obj.serialSendReceive([ID,'VU?']);
        velocity = str2double(str);
      end

      function success = setMaxVelocity(obj, velocity, axisName)
        if nargin<3
          axisName=[];
        end

        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          velocity=false;
          return
        end

        cmd = sprintf('%sVU%f',ID,velocity);
        obj.serialSendReceive(cmd);
      end %getMaxVelocity

      function velocity = getInitialVelocity(obj, axisName)
        if nargin<2
          axisName=[];
        end

        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          velocity=false;
          return
        end

        str = obj.serialSendReceive([ID,'VB?']);
        velocity = str2double(str);
      end

      function success = setInitialVelocity(obj, velocity, axisName)
        %TODO: not working!
        if nargin<3
          axisName=[];
        end

        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          return
        end

        cmd = sprintf('%sVB%f',ID,velocity);
        str = obj.serialSendReceive(cmd);
      end %setInitialVelocity

      function accel = getAcceleration(obj, axisName)
        if nargin<2
          axisName=[];
        end
        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          accel=false;
          return
        end

        str = obj.serialSendReceive([ID,'AC?']);
        accel = str2double(str);
      end

      function success = setAcceleration(obj, acceleration, axisName)
        if nargin<3
          axisName=[];
        end

        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          return
        end

        cmd = sprintf('%sAC%f',ID,acceleration);
        obj.serialSendReceive(cmd);
      end


      % - - - - - - - - - - - - -
      function success=enableAxis(obj,axisName)
        if nargin<2
          axisName=[];
        end

        %TODO: Get this working
        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          return
        end

        obj.serialSendReceive([ID,'MO']);
        str=obj.serialSendReceive([ID,'MO?']);
        if strcmp('1',str)
          success=true;
        else
          success=false;
        end
      end %enableAxis


      function success=disableAxis(obj,axisName)
        if nargin<2
          axisName=[];
        end

        %TODO: Get this working
        [success,ID]=obj.isAxisReady(axisName);
        if ~success
          return
        end

        obj.serialSendReceive([ID,'MF']);
        str=obj.serialSendReceive([ID,'MO?']);
        if strcmp('0',str)
          success=true;
        else
          success=false;
        end
      end %disableAxis


    end %close methods


    methods (Hidden)
     function ID = stageID(obj,~)
        ID=stageID@linearcontroller(obj,[]);
        if isempty(ID)
          return
        end

        if ~ischar(ID) 
          obj.logMessage(inputname(1),dbstack,7,'stage ID should be a character')
          ID=[];
        end
  
    end %stageID

    function str = serialSendReceive(obj,commandStr)
      % Send string commandStr to controller and receive reply
      fprintf(obj.hC,commandStr);

      %Only attempt to read back anything if the command string contains a question mark
      if ~isempty(strfind(commandStr,'?'))
        str = fgetl(obj.hC);
        str(1)=[]; %there appears to be a leading newline
      else
        str='';
      end
    end %serialSendReceive


  end %private methods

end %close classdef 