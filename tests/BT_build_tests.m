classdef BT_build_tests < matlab.unittest.TestCase
    % Basic integration tests of BT with its dummy components.

    properties
        hBT=[];
    end %properties


    methods(TestMethodSetup)
        function buildBT(obj)
            % Does BT build with dummy parameters?
            obj.hBT = BT('componentSettings',BakingTray.settings.dummy);
            obj.verifyClass(obj.hBT,'BT');
        end
    end
 
    methods(TestMethodTeardown)
        function closeBT(obj)
            delete(obj.hBT);
        end
    end





    methods (Test)

        function componentsPresent(obj)
            %Check that all components are present (basic)
            obj.verifyNotEmpty(obj.hBT.xAxis)
            obj.verifyNotEmpty(obj.hBT.yAxis)
            obj.verifyNotEmpty(obj.hBT.zAxis)
            obj.verifyNotEmpty(obj.hBT.cutter)
            obj.verifyNotEmpty(obj.hBT.laser)
            obj.verifyNotEmpty(obj.hBT.scanner)
        end

        function componentsCorrectClass(obj)
            %Check that all components are of the correct class
            obj.verifyInstanceOf(obj.hBT.xAxis,'linearcontroller')
            obj.verifyInstanceOf(obj.hBT.yAxis,'linearcontroller')
            obj.verifyInstanceOf(obj.hBT.zAxis,'linearcontroller')
            obj.verifyInstanceOf(obj.hBT.cutter,'cutter')
            obj.verifyInstanceOf(obj.hBT.laser,'laser')
            obj.verifyInstanceOf(obj.hBT.scanner,'scanner')
        end

        function laser_turnOn(obj)
            %Check that the dummy laser turn on/off methods toggle the isLaserOn property
            obj.assumeTrue(obj.isLaserReady)
            obj.verifyTrue(obj.hBT.laser.turnOff)
            obj.verifyFalse(obj.hBT.laser.isLaserOn)
            obj.verifyTrue(obj.hBT.laser.turnOn)
            obj.verifyTrue(obj.hBT.laser.isLaserOn)
        end

        function laser_shutter(obj)
            %Check that the dummy laser shutter open/close methods toggle the isLaserShutterOpen property
            obj.assumeTrue(obj.isLaserReady)
            obj.verifyTrue(obj.hBT.laser.closeShutter)
            obj.verifyFalse(obj.hBT.laser.isLaserShutterOpen)
            obj.verifyTrue(obj.hBT.laser.openShutter)
            obj.verifyTrue(obj.hBT.laser.isLaserShutterOpen)
        end


        function laser_targetWavelengthSet(obj)
            %Check the dummy laser targetWavelength property can be changed
            obj.assumeTrue(obj.isLaserReady)
            W=900;
            obj.verifyTrue(obj.hBT.laser.setWavelength(W))
            obj.verifyEqual(obj.hBT.laser.targetWavelength,W)
        end

        function cutter_vivbrate(obj)
            %Check the dummy cutter start/stop methods toggle the isCutterVibrating property
            obj.assumeTrue(obj.isCutterReady)
            obj.verifyTrue(obj.hBT.cutter.startVibrate)
            obj.verifyTrue(obj.hBT.cutter.isCutterVibrating)
            obj.verifyTrue(obj.hBT.cutter.stopVibrate)
            obj.verifyFalse(obj.hBT.cutter.isCutterVibrating)

        end

        function attachGoodRecipe(obj)
            %Read a recipe that is supposed to work 
            obj.verifyTrue(obj.hBT.attachRecipe('recipes/workingRecipe.yml'))
            obj.verifyTrue(obj.hBT.attachRecipe([]))
            obj.verifyTrue(obj.hBT.attachRecipe)
        end

        function recipeAttachWrongPath(obj)
            % Check that the attachRecipe method fails gracefully if a bad path is fed to it
            obj.verifyFalse(obj.hBT.attachRecipe('./'))
            obj.verifyFalse(obj.hBT.attachRecipe('./readme.txt'))
            obj.verifyFalse(obj.hBT.attachRecipe('./DoesNotExist.txt'))            
            obj.verifyFalse(obj.hBT.attachRecipe('./DoesNotExist.yml'))            
        end

    end %methods (Test)


    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    methods
        % These are convenience methods for running the tests
        function laserReady = isLaserReady(obj)
            if isempty(obj.hBT) || ...
                isempty(obj.hBT.laser) || ...
                ~isa(obj.hBT.laser,'laser') || ...
                ~obj.hBT.laser.isControllerConnected
                laserReady=false;
            else
                laserReady=true;
            end
        end

        function cutterReady = isCutterReady(obj)
            if isempty(obj.hBT) || ...
                isempty(obj.hBT.cutter) || ...
                ~isa(obj.hBT.cutter,'cutter') || ...
                ~obj.hBT.cutter.isControllerConnected
                cutterReady=false;
            else
                cutterReady=true;
            end
        end
    end



end %classdef core_tests < matlab.unittest.TestCase