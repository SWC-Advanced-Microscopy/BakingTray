classdef analog_controller < linearcontroller 
% analog_controller is a class that inherits linearcontroller and defines the interface between
% Baking Tray and an NI device that controls a motion controller via an analog output.
%
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
% Requires the data acquisition toolbox. 
%
    properties 
      NIdevice = '' %String containing the NI device ID
      outputPort =  '' %Name of the analog output port (e.g. 'AO0')

      % NOTE - these properties are different to those for the other motion control classes
      voltsPerMicron = [] %the number of volts through the analog output that will translate to a motion of one micron
      
      %We won't use the max and min properties in the stage object since the only analog controller I have 
      %access to (PIFOC) accepts a relative input only
      minAO = []; %Minimum allowa1ble voltage
      maxAO = []; %Maxumum allowa1ble voltage


      lastCommandedValue=[];
    end %close public properties


    methods

      % Constructor
      function obj=analog_controller(stageObject,logObject) 
        if nargin<1
          stageObject=[];
        end
        if nargin<2
          logObject=[];
        end
        obj.maxStages=1;
        if ~isempty(stageObject)
          obj.attachLinearStage(stageObject);
        end

        if ~isempty(logObject)
            obj.attachLogObject(logObject);
        end

      end % Constructor

      % Destructor
      function delete(obj)
        if ~isempty(obj.hC)
          obj.logMessage(inputname(1),dbstack,3,'Closing connection to C891 controller')
          obj.hC.CloseConnection
        end
      end % Destructor

      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = connect(obj,niDeviceName,outputPort)
        %First define the appropriate fields (TODO: this is clumsy)
        if isempty(obj.voltsPerMicron)
          fprintf('CONNECTION ABORTED: Please define the voltsPerMicron property\n')
          success=false;
          return
        end
        if isempty(obj.minAO)
          fprintf('CONNECTION ABORTED: Please define the minAO property\n')
          success=false;
          return
        end
        if isempty(obj.maxAO)
          fprintf('CONNECTION ABORTED: Please define the maxAO property\n')
          success=false;
          return
        end


        obj.NIdevice = niDeviceName;
        obj.outputPort = outputPort;



        %Establish a connection
        try 
          msg = sprintf('Attempting to connect to %s create PI_GCS_Controller object',niDeviceName);
          obj.logMessage(inputname(1),dbstack,3,msg)
          obj.hC = daq.createSession('ni');
          obj.hC.addAnalogOutputChannel(obj.NIdevice,obj.outputPort,'Voltage');

          %Ensure output is at zero volts
          obj.lastCommandedValue=0;
          obj.hC.outputSingleScan(0)

        catch
          msg = sprintf('Failed to connect to %s',niDeviceName);
          obj.logMessage(inputname(1),dbstack,7,msg)
          success=false;
          return
        end

      end %connect

      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = isControllerConnected(obj)
        success=false;
        if isempty(obj.hC)
          obj.logMessage(inputname(1),dbstack,7,'No attempt to connect to the controller has been made')
          return
        end

        if isa(obj.hC,'daq.ni.Session') %TODO: maybe should also check that there's an analog connection there?
          success=true;
        else
          obj.logMessage(inputname(1),dbstack,7,'Failed to establish connection to NI device')
        end
      end %isControllerConnected



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function moving = isMoving(obj,~)
        % This isn't defined right now for this device
        % We are writing this controller with the PIFOC in mind, so motion time is negligable 
        moving=false;
      end %isMoving



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function pos = axisPosition(obj,~)
        %returns the relative axis position
        pos=obj.lastCommandedValue / obj.voltsPerMicron;
      end %axisPosition



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = relativeMove(obj, distanceToMove)
        obj.logMessage(inputname(1),dbstack,1,sprintf('moving by %0.f',distanceToMove));
        st = obj.returnStageObject;
        distanceToMove=st.transformInputDistance(distanceToMove);
        obj.writeAbsPosAsVoltage(distanceToMove,true) %perform relative move
        success=true;
      end %relativeMove



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = absoluteMove(obj, targetPosition)
        success = false;
        obj.logMessage(inputname(1),dbstack,1,sprintf('moving to %0.f',targetPosition));
        st = obj.returnStageObject;
        targetPosition=st.transformInputDistance(targetPosition);
        obj.writeAbsPosAsVoltage(targetPosition) %perform absolute move
        success=true;
      end %absoluteMove


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = stopAxis(obj)
        %Not really defined for this device
        success=true;
      end %stopAxis


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function pos = getPositionUnits(~,~)
          %TODO: currently microns
          pos='um';
      end %getPositionUnits

      function success=setPositionUnits(obj,controllerUnits,~)
        %No unit setting allowed right now
        success=false;
      end %setPositionUnits


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function minPos=getMinPos(obj
        [minPos,st,ID]=getMinPos@linearcontroller(obj;

        if isempty(minPos)
          minPos = obj.hC.qTMN(ID); 
          minPos = st.transformOutputDistance(minPos);
        end
      end

      function maxPos=getMaxPos(obj
        [maxPos,st,ID]=getMaxPos@linearcontroller(obj;

        if isempty(maxPos)
          maxPos = obj.hC.qTMX(ID); 
          maxPos = st.transformOutputDistance(maxPos);
        end
      end


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      % get or set speed and acceleration settings
      function velocity = getMaxVelocity(obj)
        velocity=[];
      end

      function success = setMaxVelocity(obj, velocity)
        success=false;
      end

      function velocity = getInitialVelocity(obj)
        velocity=0;
      end

      function success = setInitialVelocity(obj, velocity)
        %This can't be set
        success=false;
      end

      function accel = getAcceleration(obj)
        accel=[];
      end

      function success = setAcceleration(obj, acceleration)
        success=false;
      end
 

      function success=enableAxis(obj)
        success=true;
      end %enableAxis


      function success=disableAxis(obj)
        success=true;
      end %disableAxis



    end %close methods


    methods (Hidden)
      function writeAbsPosAsVoltage(obj,pos,doRelativeMove)
        %Write the distance 'pos' (in microns) as a voltage to the analog output line
        % if doRelativeMove is true, then we make a relative motion WRT were we are now. 
        if nargin<3
          doRelativeMove=0;
        end

        voltageValue = pos * obj.voltsPerMicron;
        if doRelativeMove
          voltageValue = voltageValue + obj.lastCommandedValue;
        end

        if voltageValue > obj.maxAO
          msg = sprintf('Commanded voltage value (%0.2f) is larger than the max allowed value (%0.2f)',voltageValue,obj.maxAO);
          obj.logMessage(inputname(1),dbstack,6,msg)
          success=false;
          return
        end      

        if voltageValue < obj.minAO
          msg = sprintf('Commanded voltage value (%0.2f) is smaller than the min allowed value (%0.2f)',voltageValue,obj.minAO);
          obj.logMessage(inputname(1),dbstack,6,msg)
          success=false;
          return
        end      

        obj.lastCommandedValue = voltageValue;
        obj.hC.outputSingleScan(voltageValue)

      end
    end %private methods


end %close classdef
