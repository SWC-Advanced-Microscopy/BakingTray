function updatePowerAtObjectiveText(obj)
    % If the appropriate settings file was available, display laser power at the sample
    %
    % updatePowerAtObjectiveText
    %
    %

    if isempty(obj.powerCoefs) || ~exist('scanimage','file')
        return
    end

    rs = dabs.resources.ResourceStore();

    % If shutter is closed we can not take a reading
    s=rs.filterByName('shutter');
    if s.isOpen 
        obj.powerAtObjectiveText.String = 'Power @ sample: close shutter';
        return
    end


    beam = rs.filterByName('Pockels'); % This is a hard-coded name based on the MDF

    % If beam is set to zero we don't read
    if beam.hAOControl.lastKnownValue == 0
        obj.powerAtObjectiveText.String = 'Set Pockels for Power @ sample';
        return
    end

    PD = beam.hAIFeedback;
    AIval = PD.readValue;

    % TODO -- not yet implemented the lambda scaling. See readLaserPowerSettingsFile

    powerInmW = AIval*obj.powerCoefs.linear.b1 + obj.powerCoefs.linear.b0;

    tStr = sprintf('Power at sample: %0.1f mW', powerInmW);
    obj.powerAtObjectiveText.String = tStr;

end
