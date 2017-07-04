function takeNslices(obj,~,~)
    % Take a number of slices off the block 
    %
    % function takeNslices(obj,~,~)
    %
    % Reads from the number of slices edit box and takes this many slices off the block
    % Updates GUI elements accordingly.

    [cuttingPossible,msg]=obj.model.checkIfCuttingIsPossible;
    if ~cuttingPossible
        warndlg(msg,'')
        return
    end
    %Takes multiple slices according to what is entered in the multiple slice text entry box
    slicesToTake = str2double(obj.editBox.takeNslices.String);
    origString=obj.takeNSlices_button.String;
    obj.takeNSlices_button.ForegroundColor='r';

    for ii=1:slicesToTake
        if ~obj.model.checkIfCuttingIsPossible;
            %If the user breaks off the previous section with the blade beyond the cutting start point
            %then no further sections will be cut. However, cutting will restart if the user happened to
            %to abort cutting during the return of the sample to the start point. 
            break
        end
        fprintf('\nCutting slice %d/%d\n',ii,slicesToTake);
        obj.takeNSlices_button.String=sprintf('Slicing %d/%d',ii,slicesToTake);
        obj.model.sliceSample(obj.lastSliceThickness, obj.lastCuttingSpeed);
        pause(2) %so the bath does not swill around too much
    end
    obj.takeNSlices_button.String=origString;
    obj.takeNSlices_button.ForegroundColor='k';
end
