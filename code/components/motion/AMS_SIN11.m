classdef AMS_SIN11 < linearcontroller 
% AMS_SIN11 is a class that inherits linearcontroller and defines the interface between
% BakingTray and the Advanced Microsystems SIN-11 interface used to talk to stepper
% controllers such as the mSTEP-407.
%
% This class is written under the assumption that it will control the linear actuator
% that pushes the X/Y stages up and down on the jack table. 
% 
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
% Instructions:
%
% Step 1:
% You should download and install the SIN-11 driver:
% http://stepcontrol.com/acc_sin11usb/
% If you wish you can use AMS Cockpit for testing http://stepcontrol.com/download_software/
%
% Step 2:
% Ensure you know how to set up the device in a way that blocks motion commands
% that would cause the stage stage to crash into anything

    properties 
        % controllerID - the information necessary to build a connected object
        %
        % This property is filled in if needed... (TODO)
        %
        % The SIN-11 is connected via USB.

        loggingObject %property to which we attach the logging object


    end %close public properties

    properties (Hidden)
      axID %Convenience property (copy of attached stage axis ID)
      stageRefCompleted=false %Set to true after reference motion done
    end

    methods

      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function obj=AMS_SIN11(stageObject,logObject)

        if nargin<1
          stageObject=[];
        end
        if nargin<2
          logObject=[];
        end

        if ~isempty(stageObject)
          obj.attachLinearStage(stageObject);
          obj.axID = obj.attachedStage.axisID;
        end

        if ~isempty(logObject)
            obj.attachLogObject(logObject);
        end

      end %constructor


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function delete(obj)
        if ~isempty(obj.hC) && isa(obj.hC,'serial') && isvalid(obj.hC)
          fprintf('Closing connection to AMS_SIN11 controller\n')
          flushinput(obj.hC) %There may be characters left in the buffer because of the timers used to poll the laser
          fclose(obj.hC);
          delete(obj.hC);
        end
      end %destructor


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = connect(obj,connectionDetails)

        if ~obj.isStageConnected
          obj.logMessage(inputname(1),dbstack,7,'Not completing connection routine. Closing')
          success=false;
          return
        end


        % Create serial connection to the device


        success = obj.isControllerConnected; %Check that the object is connected

        %Ensure that the stage will operate in the way desired (correct zero point, etc)
        %using properties the user set before running the connect method

        %TODO - home the stage
        if ~obj.isStageReferenced & ~isempty(obj.attachedStage)
          obj.referenceStage;
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
          reply = obj.sendAndReceiveSerial('&V');
          success = ~isempty(regexp(reply,'v\d+\.\d+'));
        catch
          fprintf('Failed to communicate with AMS_SIN11 controller\n')
        end
      end %isControllerConnected



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function moving = isMoving(obj, ~)
        moving=obj.sendAndReceiveSerial([obj.axID,'^']);
        moving = str2double(moving);
      end %isMoving



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function pos = axisPosition(obj)
        ready=obj.isAxisReady;

        if ~ready
          pos=[];          
          return
        end

        pos=obj.sendReceiveSerial([obj.axisPosition,'Z']);
        pos = str2double(pos);
        pos = obj.attachedStage.transformOutputDistance(pos);
        obj.attachedStage.currentPosition=pos;
      end %axisPosition



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = relativeMove(obj,distanceToMove)
        %TODO: figure out what output we get from the ActiveX stuff if the stage failed to move. 
        success=obj.isAxisReady;
        if ~success
          return
        end

        if ~obj.checkDistanceToMove(distanceToMove)
          return
        end

        %Check that it's OK to move here
        willMoveTo = distanceToMove+obj.axisPosition;
        if ~obj.isMoveInBounds(willMoveTo)
          success=false;
          return
        end

        obj.logMessage(inputname(1),dbstack,1,sprintf('moving by %0.f',distanceToMove));
        distanceToMove=obj.attachedStage.transformInputDistance(distanceToMove);
        obj.sendAndReceiveSerial([obj.axisID,distanceToMove]);
        success=true;

      end %relativeMove



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = absoluteMove(obj, targetPosition)
        %TODO: figure out what output we get from the ActiveX stuff if the stage failed to move. 
        success=obj.isAxisReady;
        if ~success
          return
        end

        if ~obj.stageRefCompleted
          obj.logMessage(inputname(1),dbstack,5,sprintf('Axis on AMS_SIN11 not referenced. Can not make absolute move'));
          return
        end

        if ~obj.isMoveInBounds(targetPosition)
          success=false;
          return
        end

        obj.logMessage(inputname(1),dbstack,1,sprintf('moving to %0.f',targetPosition));
        targetPosition=obj.attachedStage.transformInputDistance(targetPosition);
        obj.sendAndReceiveSerial([obj.axisID,'R',targetPosition]);
      end %absoluteMove


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = stopAxis(obj)
        success=obj.isAxisReady;
        if ~success
          return
        end


        obj.sendAndReceiveSerial([obj.axisID,'@']);
        pause(0.5)
        success = ~obj.isMoving;

      end %stopAxis


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function posUnits = getPositionUnits(~)
          %The class will only handle mm
          posUnits='mm'; %The units of the AMS_SIN11 are fixed at mm or degrees. Stick to mm. 
      end %getPositionUnits

      function success=setPositionUnits(obj,controllerUnits)
        %Position units can not be set to anything other than mm
        if ~strcmp(controllerUnits,'mm')
          obj.logMessage(inputname(1),dbstack,6,'AMS_SIN11 units can only be mm')
          success=false;
        end
        success=true;
      end %setPositionUnits




      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function minPos=getMinPos(obj)
        [minPos,ID]=getMinPos@linearcontroller(obj);

        if isempty(minPos)
          obj.logMessage(inputname(1),dbstack,5,'** NO CODE YET FOR GETTING MIN POS.')  %TODO!
        end
      end

      function maxPos=getMaxPos(obj)
        [maxPos,ID]=getMaxPos@linearcontroller(obj);

        if isempty(maxPos)
          obj.logMessage(inputname(1),dbstack,5,'** NO CODE YET FOR GETTING MAX POS.') %TODO!
        end
      end


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      % get or set speed and acceleration settings 

      function velocity = getMaxVelocity(obj)
        success=obj.isAxisReady;
        if ~success
          velocity=false;
          return
        end
        %TODO
      end

      function success = setMaxVelocity(obj, velocity)
        success=obj.isAxisReady;
        if ~success
          velocity=false;
          return
        end
        %TODO
      end %getMaxVelocity

      function velocity = getInitialVelocity(obj)
        success=obj.isAxisReady;
        if ~success
          velocity=false;
          return
        end
        %TODO
      end

      function success = setInitialVelocity(obj, velocity)
        success=obj.isAxisReady;
        if ~success
          return
        end
        %TODO
      end %setInitialVelocity

      function accel = getAcceleration(obj)
        success=obj.isAxisReady;
        if ~success
          accel=false;
          return
        end
        %TODO
      end

      function success = setAcceleration(obj, acceleration)
        success=obj.isAxisReady;
        if ~success
          return
        end
        %TODO
      end


      % - - - - - - - - - - - - -
      function success=enableAxis(obj)
        %NOTE: can not return false if the command failed
        success=obj.isAxisReady;
        if ~success
          return
        end
        %TODO
      end %enableAxis


      function success=disableAxis(obj)
        success=obj.isAxisReady;
        %TODO
      end %disableAxis


      function success=referenceStage(obj)
        %We first ensure that the limit switch associated with home
        %is the switch associated with the retracted actuator. This
        %will be safer for our application. 
        success=obj.isAxisReady;
        if ~success
          return
        end

        fprintf('Homing axis on AMS_SIN11')
        obj.relativeMove(1); %move up one mm to pre-load
        obj.sendAndReceiveSerial([obj.axID,'M-20000']); %go all the way down
        while obj.isMoving
          pause(0.2)
          fprintf('.')
        end
        fprintf('\n')

        obj.sendAndReceiveSerial([obj.axID,'O0']); %Set this as zero (home)
        obj.stageRefCompleted=true

      end %reference stage

      function motorHomed=isStageReferenced(obj)
        % Has the homing routine been performed?
        % output: true/false. If no connection can be established, returns empty

        motorHomed=obj.stageRefCompleted; %TODO
      end %isStageReferenced



      %The following are hardware query commands that the AMS_SIN11 supports but we can't be 
      %certain if other hardware will do so or if it's relevant to other hardware. 


      function resetAxis(obj)
        %enable/disable of the stepper motor could cause loss of the position and is never needed
        fprintf('Axis reset not valid for the AMS_SIN11 as it is driving a stepper motor with no encoder\n')
      end

      function printAxisStatus(obj)
        printAxisStatus@linearcontroller(obj); %call the superclass
        
        if obj.isStageReferenced
          fprintf('Motor is homed\n')
        else
          fprintf('Motor is NOT homed!\n')
        end

      end



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        function [success,reply]=sendAndReceiveSerial(obj,commandString,waitForReply)
            % Send a serial command and optionally read back the reply
            if nargin<3
                waitForReply=true;
            end

            if isempty(commandString) || ~ischar(commandString)
                reply='';
                success=false;
                obj.logMessage(inputname(1),dbstack,6,'AMS_SIN11.sendReceiveSerial command string not valid.')
                return
            end

            fprintf(obj.hC,commandString);

            if ~waitForReply
                reply=[];
                success=true;
                if obj.hC.BytesAvailable>0
                    fprintf('Not waiting for reply by there are %d BytesAvailable\n',obj.hC.BytesAvailable)
                end
                return
            end

            reply=fgets(obj.hC);

            if ~isempty(reply)
                reply(end)=[];
            else
                msg=sprintf('AMS_SIN11 serial command %s did not return a reply\n',commandString);
                success=false;
                obj.logMessage(inputname(1),dbstack,6,msg)
                return
            end

            %Strip the command string and axis name
            reply = regexprep(reply,commandString,'');
            reply = regexprep(reply,[' ',obj.axID,' '],'');

            success=true;
        end


    end %close methods


    methods (Hidden)

    end %hidden methods

end %close classdef 