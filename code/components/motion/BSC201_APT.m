classdef BSC201_APT < linearcontroller 
% BSC201_APT is a class that inherits linearcontroller and defines the interface between
% Baking Tray and the ThorLabs BSC201 controller. This class works via Thor's APT 
% ActiveX control system. This is available in both 32 bit and 64 bit implementations. 
%
% This class is written under the assumption that it will control the linear actuator
% that pushes the X/Y stages up and down on the jack table. 
% 
% All abstract methods should (where possible) have doc text only in the abstract method class file.
%
% NOTE: this controller has the general problem that its functions tend to return "0"
%       both when they did and did not succeed. Only certain error conditions return a 
%       a different code. 
%
%
% Instructions:
%
% Step 1:
% You should download and install the correct version for your system. 
%
% At the time of writing, software downloads can be accessed via this link:
% http://www.thorlabs.com/software_pages/viewsoftwarepage.cfm?code=Motion_Control
% - Confirm that the hardware can be controlled with the ThorLabs APT GUI. 
% - Confirm that it is not possible for a software command to cause hardware
%   to crash into each other. 
%
%
% Step 2:
% Instantiating an object from this class can be done by providing as an input argument
% the ouput of the DRV014_BSC101_connect command. (TODO: for now).
%
% e.g. 
% H=DRV014_BSC101_connect; %TODO: what is this??
% myDevice = BSC201(H);

    properties 
        % controllerID - the information necessary to build a connected object
        %
        % This property is filled in if needed... (TODO)
        %
        % The BSC201_APT is connected via USB.

        loggingObject %property to which we attach the logging object

        % The handle to the figure where ActiveX will be connected 
        figH

    end %close public properties
      

    methods
        
      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function obj=BSC201_APT(stageObject,logObject)

        if nargin<1
          stageObject=[];
        end
        if nargin<2
          logObject=[];
        end

        if ~isempty(stageObject)
          obj.attachLinearStage(stageObject);
        end

        if ~isempty(logObject)
            obj.attachLogObject(logObject);
        end

      end %constructor


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function delete(obj)
        if ~isempty(obj.hC)
          fprintf('Closing connection to BSC201 controller\n')
          obj.hC.StopCtrl;
          delete(obj.figH)
        end
      end %destructor


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = connect(obj,hFig,hideContols)
        %Connect to the ThorLabs BSC201 using ActiveX
        %
        % hFig - a figure handle to which to attach the activex object
        %                   empty or missing
        % hideControls    - 1/0 or empty or missing (ignored if connectedObject is a figure handle)

        if ~obj.isStageConnected
          obj.logMessage(inputname(1),dbstack,7,'Not completing connection routine. Closing')
          success=false;
          return
        end

        if nargin<2 || isempty(hFig)
          obj.figH=figure; %Create a figure to which we can attach the ActiveX handles
        elseif isa(hFig,'handle') & strcmp(get(f,'type'),'figure')
          obj.figH=hFig;
        end
        set(obj.figH,'Name','THORLABS', ...
          'ToolBar','None', ...
          'MenuBar','None', ...
          'NumberTitle','off', ...
          'HandleVisibility','Off') %so it doesn't respond to "close all")

        %So the user confirms before they close the window. Avoids accidently disconnecting the controller
        set(obj.figH,'CloseRequestFcn', @obj.closeBSC201window)

        if nargin<3 || isempty(hideContols)
          hideContols=0;
        end
        %The size of the ActiveX control in the figure 
        %TODO: this will need to go elsewhere
        if hideContols
          pos=[0,0,1,1];
        else
          pos=[0,0,380,350];
        end


        % Create the main control, ActiveX
        % Consult the functions actxcontrolselect, actxcontrollist, methodsview
        fprintf('Creating ThorLabs logging object for BSC201 controller.\n')
        obj.loggingObject = actxcontrol('MG17SYSTEM.MG17SystemCtrl.1', pos, obj.figH);

        % Start the control
        fprintf('Starting logging object for BSC201 controller.\n')
        obj.loggingObject.StartCtrl;


        % Start the ActiveX controls
        % Verify the number of hardware controllers
        [~, nMotorControllers] = obj.loggingObject.GetNumHWUnits(6, 0); %6 is the type of the controller we have
        if nMotorControllers < 1
            obj.logMessage(inputname(1),dbstack,6,'Did not find any motor controllers')
            return
        end

        %Return the ID of the controller
        [~,ID] = obj.loggingObject.GetHWSerialNum(6,0,0);
        obj.controllerID=ID;

        %Create a motor control ActiveX connection
        fprintf('Creating Motor object for BSC201 controller.\n')
        obj.hC =  actxcontrol('MGMOTOR.MGMotorCtrl.1', pos, obj.figH);
        obj.hC.StartCtrl; %TODO: we've already done this with the logging object. Does it need to be done here too?
        set(obj.hC,'HWSerialNum',obj.controllerID)

        success = obj.isControllerConnected; %Check that the object is connected

        %Ensure that the stage will operate in the way desired (correct zero point, etc)
        %using properties the user set before running the connect method
        obj.setHomedReferencePoint;
        obj.setMotionRange; %The hardware controller itself will be unable to move the stage out of range


        if ~obj.isMotorHomed & ~isempty(obj.attachedStage)
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
          [~,success]=obj.hC.GetHWCommsOK(0);
        catch
          fprintf('Failed to communicate with BSC201 controller\n')
        end
      end %isControllerConnected



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function moving = isMoving(obj, ~) 
        bits=obj.getStatusBits;
        if isempty(bits)
          moving=false; %unlikely to be moving if we can't talk to the controller 
          return
        end

        if bitget(bits,5) || bitget(bits,6)
          moving=true;
        else 
          moving=false;
        end
      end %isMoving



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function pos = axisPosition(obj)
        ready=obj.isAxisReady;
        if ~ready
          pos=[];
          return
        end
        [~,pos]=obj.hC.GetPosition(0,0);

        pos = obj.attachedStage.transformDistance(pos);
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
        obj.hC.SetRelMoveDist(0,obj.attachedStage.transformDistance(distanceToMove));
        obj.hC.MoveRelative(0,0); %TODO: is that right??? Why is this here?
        success=true;

      end %relativeMove



      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = absoluteMove(obj, targetPosition)
        %TODO: figure out what output we get from the ActiveX stuff if the stage failed to move. 
        success=obj.isAxisReady;
        if ~success
          return
        end

        if ~obj.isMoveInBounds(targetPosition)
          success=false;
          return
        end

        obj.logMessage(inputname(1),dbstack,1,sprintf('moving to %0.f',targetPosition));
        obj.hC.SetAbsMovePos(0,obj.attachedStage.transformDistance(targetPosition));
        obj.hC.MoveAbsolute(0,0);%TODO: is that right??? Why is this here?
      end %absoluteMove


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function success = stopAxis(obj)
        success=obj.isAxisReady;
        if ~success
          return
        end

        success=obj.hC.StopImmediate(0);
        if success==0 %TODO: I think this is is right. 
          success=true;
        else
          success=false;
        end

      end %stopAxis


      % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      function posUnits = getPositionUnits(~)
          %TODO - get this method working, even though we will never set it to degrees
          posUnits='mm'; %The units of the BSC201 are fixed at mm or degrees. Stick to mm. 
      end %getPositionUnits

      function success=setPositionUnits(obj,controllerUnits)
        %TODO - get this method working, even though we will never set it to degrees
        if ~strcmp(controllerUnits,'mm')
          obj.logMessage(inputname(1),dbstack,6,'BSC201 units can only be mm')
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
        velocity=obj.hC.GetVelParams_MaxVel(0);
      end

      function success = setMaxVelocity(obj, velocity)
        success=obj.isAxisReady;
        if ~success
          velocity=false;
          return
        end
        minVel = obj.getInitialVelocity;
        accel = obj.getAcceleration;
        obj.hC.SetVelParams(0,minVel,accel,velocity); %set
        [~,minV,accel,maxV]=obj.hC.GetVelParams(0,0,0,0); %read

        if abs(velocity-maxV)<1E-2
          success=true;
        else
          obj.logMessage(inputname(1),dbstack,6,'Failed to set maximum velocity')
          success=false;
        end
      end %getMaxVelocity

      function velocity = getInitialVelocity(obj)
        success=obj.isAxisReady;
        if ~success
          velocity=false;
          return
        end
        [~,velocity]=obj.hC.GetVelParams(0,0,0,0);
      end

      function success = setInitialVelocity(obj, velocity)
        success=obj.isAxisReady;
        if ~success
          return
        end

        accel = obj.getAcceleration;
        maxVel = obj.getAcceleration;
        obj.hC.SetVelParams(0,velocity,accel,maxVel); %set
        [~,minV,accel,maxV]=obj.hC.GetVelParams(0,0,0,0); %read

        
        if abs(velocity-minV)<1E-2
          success=true;
        else
          obj.logMessage(inputname(1),dbstack,6,'Failed to set minimum velocity')
          success=false;
        end
      end %setInitialVelocity

      function accel = getAcceleration(obj)
        success=obj.isAxisReady;
        if ~success
          accel=false;
          return
        end
        accel=obj.hC.GetVelParams_Accn(0);
      end

      function success = setAcceleration(obj, acceleration)
        success=obj.isAxisReady;
        if ~success
          return
        end

        minVel = obj.getInitialVelocity;
        maxVel = obj.getAcceleration;

        obj.hC.SetVelParams(0,minVel,acceleration,maxVel); %set
        [~,minV,accel,maxV]=obj.hC.GetVelParams(0,0,0,0); %read
        if abs(acceleration-accel)<1E-2
          success=true;
        else
          obj.logMessage(inputname(1),dbstack,6,'Failed to set acceleration')
          success=false;
        end
      end


      % - - - - - - - - - - - - -
      function success=enableAxis(obj)
        %NOTE: can not return false if the command failed
        success=obj.isAxisReady;
        if ~success
          return
        end
        obj.hC.EnableHWChannel(0);
      end %enableAxis


      function success=disableAxis(obj)
        %NOTE: can not return false if the command failed
        success=obj.isAxisReady;
        if ~success
          return
        end
        obj.hC.DisableHWChannel(0);
      end %disableAxis



      %TODO: enforce that this function must always be present. even for V552, etc?
      function success=referenceStage(obj)
        %We first ensure that the limit switch associated with home
        %is the switch associated with the retracted actuator. This
        %will be safer for our application. 
        success=obj.isAxisReady;
        if ~success
          return
        end

        obj.hC.MoveHome(0,0);

        fprintf('Homing axis on BSC201')
        pause(0.1)
        while obj.isMoving
          pause(0.2)
          fprintf('.')
        end
        fprintf('\n')

        pause(1) %Because this might help with the APT crashing problems

        if obj.isMotorHomed
          success=true; 
        else
          obj.logMessage(inputname(1),dbstack,6,'Controller reports motor is not homed. Stage may not be referenced')
          success=false;
        end


      end %reference stage



      %The following are hardware query commands that the BSC201 supports but we can't be 
      %certain if other hardware will do so or if it's relevant to other hardware. 
      function motorHomed=isMotorHomed(obj)
        % Has the homing routine been performed?
        % output: true/false. If no connection can be established, returns empty

        bits=obj.getStatusBits;
        if isempty(bits)
          motorHomed=[]; 
          return
        end

        if bitget(bits,11)
          motorHomed=true;
        else 
          motorHomed=false;
        end

      end %isMotorHomed



      function success=setMotionRange(obj)
        % Set the motion range of the stage to this set of values
        % This command ensures that the controller itself is unable to move the stage ourside 
        % of the safe range.

        success=false;
        stageObj = obj.attachedStage;

        %Set the range of allowable motions
        [c,m,M,U,ptc,sns]=obj.hC.GetStageAxisInfo(0,0,0,0,0,0);

        %Check that we have values for all of the fields
        if isempty(stageObj.minPos) | isempty(stageObj.maxPos)
          obj.logMessage(inputname(1),dbstack,6,'You must fill in the max and min positions in the stage object')
          return
        end


        %Note, max and min pos are inverted here:
        obj.hC.SetStageAxisInfo(c,stageObj.transformDistance(stageObj.maxPos),stageObj.transformDistance(stageObj.minPos),U,ptc,sns);

        %re-read the parameters to check that they were changed
        [c,maxPos,minPos,U,ptc,sns]=obj.hC.GetStageAxisInfo(0,0,0,0,0,0);

        %Otherwise rounding errors creep in and cause the function to return false
        maxPos = round(maxPos,5);
        minPos = round(minPos,5);

        if maxPos~=stageObj.transformDistance(stageObj.maxPos) || minPos~=stageObj.transformDistance(stageObj.minPos)
          msg=sprintf('Failed to set min and max positions on BSC201. maxRequested=%0.2f, maxActual=%0.2f, minRequested=%0.2f, minActual=%0.2f', ...
            stageObj.transformDistance(stageObj.maxPos) ,maxPos, stageObj.transformDistance(stageObj.minPos) ,minPos)
          obj.logMessage(inputname(1),dbstack,6,msg)
        else
          success=true;
        end
      end %setMotionRange


      function success=setHomedReferencePoint(obj)
        %Set actuator's the motion range of the stage to this set of values
        st = obj.attachedStage;
        success=false;
        %Check that we have values for all of the fields
        if isempty(st.limitSwitch) | isempty(st.homingDir) | isempty(st.homeVel) | isempty(st.zeroOffset)
          obj.logMessage(inputname(1),dbstack,6,'You must fill in all referencing properties in stage object.\n')
          return
        end

        obj.hC.SetHomeParams(st.axisID,st.homingDir,st.limitSwitch,st.homeVel,st.zeroOffset);

        %re-read to check that the settings were sent to the device
        [a,hD,lS,hV,zO]=obj.hC.GetHomeParams(0,0,0,0,0);

        if hD~=st.homingDir | lS~=st.limitSwitch | hV~=st.homeVel | zO~=st.zeroOffset
          obj.logMessage(inputname(1),dbstack,6,'Failed to set reference parameters on BSC201. Stage may not be possible to reference')
        else
          success=true;
        end

      end

      function resetAxis(obj)
        %enable/disable of the stepper motor could cause loss of the position and is never needed
        fprintf('Axis reset not valid for the BSC201 as it is driving a stepper motor with no encoder\n')
      end

      function printAxisStatus(obj)
        printAxisStatus@linearcontroller(obj); %call the superclass
        [~,maxPos,minPos,~,~,~]=obj.hC.GetStageAxisInfo(0,0,0,0,0,0);

        fprintf('Controller minPos = %0.2f mm ; Controller maxPos = %0.2f mm\n', ... 
              obj.attachedStage.transformDistance(minPos), obj.attachedStage.transformDistance(maxPos))
        if obj.isMotorHomed
          fprintf('Motor is homed\n')
        else
          fprintf('Motor is NOT homed!\n')
        end

      end


    end %close methods


    methods (Hidden)

        function bits = getStatusBits(obj)
            % Returns the abs(status bits)
            %
            %
            success=obj.isAxisReady;
            if ~success
              bits=[];
              return
            end
            bits = obj.hC.GetStatusBits_Bits(0);
            bits = abs(bits);
        end

        function closeBSC201window(obj,~,~)
            %Confirm before closing window
            choice = questdlg('Closing this window will disconnect the Z stage motor. Are you sure?', '', 'Yes', 'No', 'No');

            switch choice
                case 'No'
                    %pass
                case 'Yes'
                    obj.delete
            end
        end

    end %private methods

end %close classdef 