function setChannelToView(obj,~,~)
    if obj.verbose, fprintf('In acquisition_view.setChannelToView callback\n'), end

    % This callback runs when the user ineracts with the channel popup.
    % The callback sets which channel will be displayed
    if isempty(obj.model.scanner.channelsToDisplay)
        %Don't do anything if no channels are being viewed
        return
    end
    thisSelection = obj.channelSelectPopup.String{obj.channelSelectPopup.Value};
    thisChannelIndex = str2double(regexprep(thisSelection,'\w+ ',''));
    if isempty(thisChannelIndex)
        return
    end
    obj.chanToShow=thisChannelIndex;
    obj.updateSectionImage([],[],true); %force update
    obj.updateImageLUT;
end %setDepthToView

function chooseChanToDisplay(obj)
    % Choose a channel to display as a default: For now just the first channel

    if obj.verbose, fprintf('In acquisition_view.chooseChanToDisplay callback\n'), end

    channelsBeingAcquired = obj.model.scanner.channelsToAcquire;
    channelsScannerDisplays = obj.model.scanner.channelsToDisplay;

    if isempty(channelsScannerDisplays)
        % Then we can't display anything
        return
    end

    %TODO: we can choose this more cleverly in future
    obj.channelSelectPopup.Value=1;

    obj.setChannelToView
end %chooseChanToDisplay