function [success,msg] = turnOffAllLasers(obj)
    % Turn off every attached laser and report what each of them said
    %
    % function [success,msg] = BT.turnOffAllLasers
    %
    % Purpose
    % Switch off all the lasers in BT.lasers and return a message describing the state of
    % each one afterwards. This exists so that the end of an acquisition can turn off every
    % laser rather than only the primary one. It can also be run at the command line.
    %
    % Inputs
    % none
    %
    % Outputs
    % success - true if every laser reported that it turned off. A system with no lasers
    %           attached returns true: there was nothing to do and nothing went wrong.
    % msg - a string with one line per laser, suitable for the acquisition log or Slack.
    %       Empty if no lasers are attached.
    %
    %
    % See also: BT.bakeCleanupFun

    success=true;
    msg='';

    if isempty(obj.lasers)
        return
    end

    % Send the turn off command to all lasers before reading back from any of them, otherwise
    % a system with multiple real lasers waits for each in turn.
    turnedOff=false(1,length(obj.lasers));
    for ii=1:length(obj.lasers)
        turnedOff(ii)=obj.lasers{ii}.turnOff;
    end

    % It takes a little while for a real laser to turn off. One pause covers all of them.
    if any(cellfun(@(x) ~isa(x,'dummyLaser'), obj.lasers))
        pause(10)
    end

    for ii=1:length(obj.lasers)
        if turnedOff(ii)
            msg=[msg,sprintf('%s reports it turned off: %s\n', ...
                obj.laserName(obj.lasers{ii}), obj.lasers{ii}.returnLaserStats)];
        else
            success=false;
            msg=[msg,sprintf('%s turn off command reports it did not work\n', ...
                obj.laserName(obj.lasers{ii}))];
        end
    end

end %turnOffAllLasers
