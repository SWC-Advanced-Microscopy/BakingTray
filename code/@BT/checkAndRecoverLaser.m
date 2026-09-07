function [laserIsReady,msg] = checkAndRecoverLaser(obj,thisLaser)
    % Check that one laser is ready and try to recover it if it is not
    %
    % function [laserIsReady,msg] = checkAndRecoverLaser(obj,thisLaser)
    %
    % Purpose
    % Run between sections by BT.bake for each laser taking part in the acquisition. If
    % the laser is not ready (most often because it has lost modelock) we wait and check
    % again, in case the first reading was momentary. If it is still not ready we try to
    % turn it back on and re-open the shutter, then wait up to 150 seconds for it to come
    % back. bake stops the acquisition rather than cutting if this fails, so the sample is
    % left safe.
    %
    % Recovery is not attempted on a laser we can no longer communicate with, since the
    % commands that would recover it can not reach it either.
    %
    % This exists as a method so that bake can run it over every monitored laser rather
    % than only the primary one. It was previously inline in bake and hard-coded to
    % BT.laser, which meant that a second laser dropping out mid-acquisition went unnoticed.
    % It can also be run at the command line against any laser: BT.checkAndRecoverLaser.
    %
    % Inputs
    % obj - the BT object
    % thisLaser - a single laser object, e.g. one element of BT.lasers
    %
    % Outputs
    % laserIsReady - true if the laser is ready or was successfully recovered
    % msg - describes what went wrong. Empty if the laser is ready.
    %
    %
    % See also: BT.bake, BT.laserName

    laserName = obj.laserName(thisLaser);

    [laserIsReady,msg] = thisLaser.isReady;
    if ~laserIsReady
        % Pause and check it's really down before carrying on
        pause(3)
        [laserIsReady,msg] = thisLaser.isReady;
    end

    % If laser returns ready we can leave the method
    if laserIsReady
        return
    end

    % It's unlikely we ever get here
    if ~obj.isThisLaserConnected(thisLaser)
        % There is nothing to recover: we can not talk to the laser at all, so turnOn and
        % openShutter can not reach it either. Bail out rather than spending 150 seconds
        % retrying on an acquisition that is going to stop regardless.
        msg = sprintf('LASER NOT CONNECTED (Section %d): %s: %s\n', ...
            obj.currentSectionNumber, laserName, msg);
        obj.acqLogWriteLine(msg);
        return
    end

    msg = sprintf('LASER NOT RUNNING (Section %d): %s: %s\n', ...
        obj.currentSectionNumber, laserName, msg);
    obj.acqLogWriteLine(msg);
    obj.slack(sprintf('%sBakingTray trying to recover it.\n', msg));

    thisLaser.turnOn;
    pause(3)
    thisLaser.openShutter;
    pause(2)


    % Re-test if the laser is ready
    for ii=1:15
        laserIsReady = thisLaser.isReady;
        if laserIsReady
            obj.acqLogWriteLine(sprintf('LASER RECOVERED: %s\n', laserName));
            obj.slack(sprintf('BakingTray managed to recover %s.', laserName));
            return
        end
        pause(10)
    end

    msg = sprintf('%sFailed to recover %s.\n', msg, laserName);

end % checkAndRecoverLaser
