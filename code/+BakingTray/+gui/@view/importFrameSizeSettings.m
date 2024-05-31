function importFrameSizeSettings(obj)
    % Import scanner frame sizes and set up text pop-up box
    %
    % function BakingTray.gui.view.importFrameSizeSettings
    %

    if isempty(obj.model.scanner)
        return
    end
    obj.model.scanner.readFrameSizeSettings;

    thisStruct = obj.model.scanner.frameSizeSettings;

    if ~isempty(thisStruct)
        for ii=1:length(thisStruct)

            % The popUpText is that which appears in the main GUI under the "Tile Size" pop-up menu
            popUpText{ii} = sprintf('%dx%d %0.2f \x03BCm/pix', ...
                thisStruct(ii).pixelsPerLine, thisStruct(ii).linesPerFrame, thisStruct(ii).nominalMicronsPerPixel);
        end

        obj.recipeEntryBoxes.other{1}.String = popUpText;
        obj.recipeEntryBoxes.other{1}.UserData = thisStruct; %TODO: ugly because it's a second copy
        obj.recipeEntryBoxes.other{1}.Callback = @(src,evt) obj.applyScanSettings(src,evt); % Cause ScanImage to set the image size

    else % Report no frameSize file found
        fprintf('\n\n No frame size file found\n\n')
        obj.recipeEntryBoxes.other{1}.String = 'No frame size file ';
        obj.recipeEntryBoxes.other{1}.Enable = 'Off';
    end

    obj.updateTileSizeLabelText; %Make the label text red if scan settings and pop-up value do not match

end % importFrameSizeSettings
