function varargout = reportAcquisitionSize(obj)
    % Report to screen the expected size of the acquisition along with disk space.
    % Optionally return the information as a string.
    %


    acqInGB = obj.recipe.estimatedSizeOnDisk;

    fprintf('Acquisition will take up %0.2g GB of disk space\n', acqInGB)

    volumeToWrite = strsplit(obj.sampleSavePath,filesep);
    volumeToWrite = volumeToWrite{1};

    out = BakingTray.utils.returnDiskSpace(volumeToWrite);

    msg = sprintf('Writing to volume %s which has %d/%d GB free\n', ...
        volumeToWrite, round(out.freeGB), round(out.totalGB));

    fprintf(msg)


    if nargout>0
        varargout{1} = msg;
    end
