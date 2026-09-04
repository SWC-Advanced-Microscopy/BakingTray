function success=attachLaser(obj,settings)
    % Attach one or more lasers to BT
    %
    % function success=attachLaser(obj,settings)
    %
    % Inputs (optional)
    % settings - this is the laser field from the settings structure produced by
    %            the settings reader BakingTray.settings.readComponentSettings
    %            If left empty, the the settings file is read by this function
    %            and the correct field is extracted. This is a structure array
    %            with one element per laser. A settings file describing a single
    %            laser produces a 1x1 structure array, so single-laser systems
    %            need no changes to their settings file.
    %
    % Outputs
    % success - Returns true if at least one laser was built successfully.
    %           The lasers themselves are placed in the BT.lasers cell array,
    %           so BT is a composite object. The first laser in the cell array
    %           is the primary laser and is what BT.laser returns.
    %
    % Notes
    % If more than one laser is defined, each must have a non-empty and unique beamName
    % so that it can be associated with a beam in ScanImage. A laser that breaks this
    % rule is not attached, but the others still are: a bad settings file costs you a
    % laser, not the ability to start BakingTray.
    %
    % This is the only place that writes to BT.lasers.

    success=false;

    %Read the settings file if a structure was not supplied for this component
    if nargin<2
         settings=BakingTray.settings.readComponentSettings;
         settings=settings.laser;
    end

    % The pockels field is new (2021/10/11) optional and if present looks like this:
    %   pockels.doPockelsPowerControl=true;
    %   pockels.pockelsDAQ='Dev3';
    %   pockels.pockelsDigitalLine='port0/line0';
    if ~isfield(settings,'pockels')
        [settings.pockels]=deal([]);
    end

    %Build each laser in turn, keeping only those that are valid
    for ii=1:length(settings)
        thisLaser=buildLaserComponent(settings(ii).type, settings(ii));

        % Deliberately not isThisLaserConnected: the question here is whether we got a
        % laser object back at all, not whether it is currently talking. A laser whose
        % connect probe failed is still kept, so that it can be recovered by hand with
        % lasers{n}.connect without restarting BakingTray.
        if isempty(thisLaser) || ~isa(thisLaser,'laser') || ~isvalid(thisLaser)
            fprintf('Failed to build laser %d of %d.\n', ii, length(settings))
            continue
        end

        if length(settings)>1 && ~laserBeamNameIsValid(thisLaser, obj.lasers)
            delete(thisLaser) %To clean up any open ports, etc
            continue
        end

        % Add a link to the BT parent object to the component so this
        % component can access other attached components
        thisLaser.parent=obj;
        obj.lasers{end+1}=thisLaser;
    end

    %Return false if no lasers at all were attached
    if ~isempty(obj.lasers)
        success=true;
    end

end %attachLaser


function isValid = laserBeamNameIsValid(thisLaser, attachedLasers)
    % Return true if the beamName of thisLaser allows it to be told apart from the lasers
    % already attached. Warns and returns false if it does not. Only applied when more than
    % one laser is defined: a lone laser needs no beamName and most systems have only one.

    isValid = false;

    if isempty(thisLaser.beamName)
        warning('attachLaser:emptyBeamName', ...
            ['Laser "%s" has no beamName but more than one laser is defined. ', ...
             'Every laser needs a unique beamName so it can be associated with a beam ', ...
             'in ScanImage. NOT attaching this laser.'], thisLaser.friendlyName)
        return
    end

    attachedBeamNames = cellfun(@(x) x.beamName, attachedLasers, 'UniformOutput', false);
    if any(strcmp(thisLaser.beamName, attachedBeamNames))
        warning('attachLaser:duplicateBeamName', ...
            ['More than one laser has the beamName "%s". Beam names must be unique. ', ...
             'NOT attaching this laser.'], thisLaser.beamName)
        return
    end

    isValid = true;
end %laserBeamNameIsValid
