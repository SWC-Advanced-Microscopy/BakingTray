function updateBakeButtonState(obj,~,~)
    if obj.verbose, fprintf('In acquisition_view.updateBakeButtonState callback\n'), end

    if obj.model.acquisitionInProgress && ~obj.model.scanner.isAcquiring
        % This disables the button during the dead-time between asking for an acquisition
        % and it actually beginning
        obj.button_BakeStop.Enable='off';
    else
        obj.button_BakeStop.Enable='on';
    end

    if ~obj.model.acquisitionInProgress 
        %If there is no acquisition we put buttons into a state where one can be started
        set(obj.button_BakeStop, obj.buttonSettings_BakeStop.bake{:})
        obj.button_previewScan.Enable='on';

    elseif obj.model.acquisitionInProgress && ~obj.model.abortAfterSectionComplete && ~obj.model.isSlicing
        %If there is an acquisition in progress and we're not waiting to abort after this section
        %then it's allowed to have a stop option.
        set(obj.button_BakeStop, obj.buttonSettings_BakeStop.stop{:})
        obj.button_previewScan.Enable='off';
        obj.button_BakeStop.Enable='on';

    elseif obj.model.acquisitionInProgress && ~obj.model.abortAfterSectionComplete && obj.model.isSlicing
        %If there is an acquisition in progress and we're not waiting to abort after this section
        %then it's allowed to have a stop option.
        set(obj.button_BakeStop, obj.buttonSettings_BakeStop.stop{:})
        obj.button_previewScan.Enable='off';
        obj.button_BakeStop.Enable='off'; % TODO -- weirdly this does not disable
        obj.button_BakeStop.String='Slicing';
       
        

    elseif obj.model.acquisitionInProgress && obj.model.abortAfterSectionComplete
        %If there is an acquisition in progress and we *are* waiting to abort after this section
        %then we are give the option to cancel stop.
        set(obj.button_BakeStop, obj.buttonSettings_BakeStop.cancelStop{:})
        obj.button_previewScan.Enable='off';
    end

end %updateBakeButtonState