function setDepthToView(obj,~,~)
    % BakingTray.gui.acquisition_view.setDepthToView
    %
    % This callback runs when the user interacts with the depth popup.
    % The callback sets which depth will be displayed

    if obj.verbose, fprintf('In acquisition_view.setDepthToView callback\n'), end

    if isempty(obj.model.scanner.channelsToDisplay)
        %Don't do anything if no channels are being viewed
        return
    end
    if strcmp(obj.depthSelectPopup.Enable,'off')
        return
    end
    thisSelection = obj.depthSelectPopup.String{obj.depthSelectPopup.Value};
    thisDepthIndex = str2double(regexprep(thisSelection,'\w+ ',''));

    if thisDepthIndex>size(obj.previewImageData,3)
        %If the selected value is out of bounds default to the first depth
        thisDepthIndex=1;
        obj.depthSelectPopup.Value=1;
    end

    obj.depthToShow = thisDepthIndex;
    obj.updateSectionImage;
end %setDepthToView