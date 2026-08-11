classdef BT_laser_multi_tests < matlab.unittest.TestCase
    % Tests of the multiple-laser behaviour of BT.
    %
    % BT.lasers is a cell array of laser objects and BT.laser is a read-only alias for the
    % first of them. These tests cover the alias, the "is anything connected" logic, and the
    % building of N lasers by BT.attachLaser. Everything here runs against dummyLaser so no
    % hardware is needed.
    %
    % See also: BT_build_tests, which covers the single-laser behaviour of the built system.

    properties
        hBT=[];
    end %properties


    methods(TestMethodSetup)
        function buildBT(obj)
            evalin('base','clear hBT')
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

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % The BT.laser alias

        function alias_returnsFirstLaser(obj)
            %BT.laser must be the first laser in BT.lasers
            L1 = dummyLaser;
            L2 = dummyLaser;
            obj.hBT.lasers = {L1,L2};
            obj.verifySameHandle(obj.hBT.laser,L1)
        end

        function alias_emptyWhenNoLasers(obj)
            %BT.laser must be empty and not error when no lasers are attached
            obj.hBT.lasers = {};
            obj.verifyEmpty(obj.hBT.laser)
        end

        function alias_isReadOnly(obj)
            %Assigning to BT.laser must fail: lasers are attached with BT.attachLaser only
            f = @() setLaserAlias(obj.hBT);
            obj.verifyError(f,'MATLAB:class:noSetMethod')
        end


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % BT.isLaserConnected

        function isLaserConnected_trueIfOneConnected(obj)
            %One connected laser is enough for the system to count as having a laser
            obj.hBT.lasers = {dummyLaser};
            obj.verifyTrue(obj.hBT.isLaserConnected)
        end

        function isLaserConnected_trueIfAnyConnected(obj)
            %A deleted laser alongside a live one must not hide the live one
            L1 = dummyLaser;
            L2 = dummyLaser;
            delete(L1)
            obj.hBT.lasers = {L1,L2};
            obj.verifyTrue(obj.hBT.isLaserConnected)
        end

        function isLaserConnected_falseIfNoLasers(obj)
            %No lasers at all means no laser is connected
            obj.hBT.lasers = {};
            obj.verifyFalse(obj.hBT.isLaserConnected)
        end

        function isLaserConnected_falseIfAllDeleted(obj)
            %A cell array of dead laser objects must not count as connected
            L1 = dummyLaser;
            delete(L1)
            obj.hBT.lasers = {L1};
            obj.verifyFalse(obj.hBT.isLaserConnected)
        end


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % BT.attachLaser

        function attach_singleLaser(obj)
            %The single-laser case must be unchanged: one laser, reachable via the alias
            obj.detachAllLasers
            settings = obj.laserSettings({''});
            obj.verifyTrue(obj.hBT.attachLaser(settings))
            obj.verifyNumElements(obj.hBT.lasers,1)
            obj.verifyInstanceOf(obj.hBT.laser,'laser')
            obj.verifySameHandle(obj.hBT.laser.parent,obj.hBT)
        end

        function attach_twoLasers(obj)
            %Two lasers with distinct beam names must both attach, in the order given
            obj.detachAllLasers
            settings = obj.laserSettings({'beamA','beamB'});
            obj.verifyTrue(obj.hBT.attachLaser(settings))
            obj.verifyNumElements(obj.hBT.lasers,2)
            obj.verifyEqual(obj.hBT.lasers{1}.beamName,'beamA')
            obj.verifyEqual(obj.hBT.lasers{2}.beamName,'beamB')
            obj.verifySameHandle(obj.hBT.laser,obj.hBT.lasers{1})
        end

        function attach_setsParentOnAllLasers(obj)
            %Every laser needs the link back to BT, not just the primary
            obj.detachAllLasers
            obj.hBT.attachLaser(obj.laserSettings({'beamA','beamB'}));
            for ii=1:length(obj.hBT.lasers)
                obj.verifySameHandle(obj.hBT.lasers{ii}.parent,obj.hBT)
            end
        end

        function attach_duplicateBeamNameIsRefused(obj)
            %A repeated beam name is ambiguous: warn, skip that laser, but still start up
            obj.detachAllLasers
            settings = obj.laserSettings({'beamA','beamA'});
            obj.verifyWarning(@() obj.hBT.attachLaser(settings), 'attachLaser:duplicateBeamName')
            obj.verifyNumElements(obj.hBT.lasers,1)
            obj.verifyEqual(obj.hBT.lasers{1}.beamName,'beamA')
        end

        function attach_emptyBeamNameIsRefusedIfMultipleLasers(obj)
            %With more than one laser every laser must be identifiable by beam name
            obj.detachAllLasers
            settings = obj.laserSettings({'beamA',''});
            obj.verifyWarning(@() obj.hBT.attachLaser(settings), 'attachLaser:emptyBeamName')
            obj.verifyNumElements(obj.hBT.lasers,1)
            obj.verifyEqual(obj.hBT.lasers{1}.beamName,'beamA')
        end

        function attach_emptyBeamNameIsFineIfOneLaser(obj)
            %A single laser needs no beam name: this is what every existing rig looks like
            obj.detachAllLasers
            obj.verifyTrue(obj.hBT.attachLaser(obj.laserSettings({''})))
            obj.verifyNumElements(obj.hBT.lasers,1)
        end

        function attach_failsIfNoLasersCouldBeBuilt(obj)
            %If nothing could be built we must report failure rather than a phantom success
            obj.detachAllLasers
            settings = obj.laserSettings({''});
            settings.type = 'notALaserClass';
            obj.verifyFalse(obj.hBT.attachLaser(settings))
            obj.verifyEmpty(obj.hBT.lasers)
        end

        function attach_worksWithNoWavelengthField(obj)
            %The wavelength field is optional: settings files written before it existed must
            %still attach. Only fixed-wavelength lasers such as the Axon need it.
            obj.detachAllLasers
            settings = obj.laserSettings({''});
            obj.verifyFalse(isfield(settings,'wavelength'))
            obj.verifyTrue(obj.hBT.attachLaser(settings))
            obj.verifyNumElements(obj.hBT.lasers,1)
        end

        function attach_wavelengthFieldIsHarmlessOnATunableLaser(obj)
            %A tunable laser reads its wavelength from the hardware and must ignore the
            %field rather than error or have its wavelength overwritten
            obj.detachAllLasers
            settings = obj.laserSettings({''});
            settings.wavelength = 1064;
            obj.verifyTrue(obj.hBT.attachLaser(settings))
            obj.verifyNotEqual(obj.hBT.laser.currentWavelength,1064)
        end


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % BT.turnOffAllLasers

        function turnOffAll_switchesAllOff(obj)
            %Every laser must be turned off, not just the primary
            obj.detachAllLasers
            obj.hBT.attachLaser(obj.laserSettings({'beamA','beamB'}));
            cellfun(@(x) x.turnOn, obj.hBT.lasers);
            obj.hBT.turnOffAllLasers;
            obj.verifyFalse(obj.hBT.lasers{1}.isLaserOn)
            obj.verifyFalse(obj.hBT.lasers{2}.isLaserOn)
        end

        function turnOffAll_reportsSuccess(obj)
            %The dummy lasers all turn off, so success must be true and each be reported
            obj.detachAllLasers
            obj.hBT.attachLaser(obj.laserSettings({'beamA','beamB'}));
            [success,msg] = obj.hBT.turnOffAllLasers;
            obj.verifyTrue(success)
            obj.verifyNumElements(strfind(msg,sprintf('\n')),2) % One line per laser
        end

        function turnOffAll_noLasersIsNotAFailure(obj)
            %With no lasers there is nothing to turn off and nothing to complain about
            obj.detachAllLasers
            [success,msg] = obj.hBT.turnOffAllLasers;
            obj.verifyTrue(success)
            obj.verifyEmpty(msg)
        end

    end %methods (Test)




    methods
        % These are helper methods, not tests

        function detachAllLasers(obj)
            % Remove the lasers attached by the dummy settings so a test can attach its own
            cellfun(@delete, obj.hBT.lasers);
            obj.hBT.lasers = {};
        end

        function settings = laserSettings(~,beamNames)
            % Return a laser settings struct array of dummy lasers, one per supplied beam name
            for ii=length(beamNames):-1:1
                settings(ii).type = 'dummyLaser';
                settings(ii).COM = [];
                settings(ii).beamName = beamNames{ii};
            end
        end

    end %methods

end %classdef


function setLaserAlias(hBT)
    % Used to check that BT.laser can not be written to. This has to happen in a function
    % because MATLAB will not parse an assignment to a property inside an anonymous function.
    hBT.laser = dummyLaser;
end
