function pause_callback(obj,~,~)
    % Run when the pause button is pressed
    % Pauses or resumes the acquisition according to the state of the observable property in scanner.acquisitionPaused
    % This will not pause cutting. It will only pause the system when it's acquiring data. If you press this during
    % cutting the acquisition of the next section will not begin until pause is disabled. 
    if ~obj.model.acquisitionInProgress
        obj.updatePauseButtonState;
        return
    end

    if obj.model.scanner.acquisitionPaused
        %If acquisition is paused then we resume it
        obj.model.scanner.resumeAcquisition;
    elseif ~obj.model.scanner.acquisitionPaused
        %If acquisition is running then we pause it
        obj.model.scanner.pauseAcquisition;
    end

end %pause_callback