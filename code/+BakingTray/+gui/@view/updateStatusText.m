function varargout = updateStatusText(obj,~,~)
    % Update the status text in the main BakingTray GUI window
    if obj.model.isRecipeConnected
        R=obj.model.recipe;

        scannerID=obj.getScannerID;
        if scannerID ~= false
            %If the user is to run ScanImage, prompt them to start it
            scnSet = obj.model.scanner.returnScanSettings;
        else
            settings=BakingTray.settings.readComponentSettings;
            if strcmp(settings.scanner.type,'SIBT')
                scannerID='START SCANIMAGE AND CONNECT IT';
            else
                scannerID='NOT ATTACHED';
            end
            scnSet=[];
        end

        if ~obj.model.isScannerConnected
            fprintf('Can not generate tile positions: no scanner connected.\n')
        end

        micronsBetweenOpticalPlanes = (R.mosaic.sliceThickness/R.mosaic.numOpticalPlanes)*1000;

        if ~isempty(scnSet)
            tilesPlane = R.NumTiles.tilesPerPlane;

            endTime = obj.model.estimateTimeRemaining(scnSet, tilesPlane.total);
            %Strip seconds off total time as they take up space and
            %mean nothing
            endTime.timeForSampleString = ... 
                regexprep(endTime.timeForSampleString, ...
                        ' \d+ secs', '');
            if length(obj.model.scanner.channelsToAcquire)>1
                 channelsToAcquireString = sprintf('%d channels',length(obj.model.scanner.channelsToAcquire));
            elseif length(obj.model.scanner.channelsToAcquire)==1
                channelsToAcquireString = sprintf('%d channel',length(obj.model.scanner.channelsToAcquire));
            elseif length(obj.model.scanner.channelsToAcquire)==0
                channelsToAcquireString = 'NO CHANNELS!';
            end


            estimatedSize = obj.model.recipe.estimatedSizeOnDisk(tilesPlane.total);
            msg = sprintf(['FOV: %d x %d\\mum ; Voxel: %0.1f x %0.1f x %0.1f \\mum\n', ...
                'Tiles: %d x %d ; Depth: %0.1f mm ; %s\n', ...
                'Time left: %s; Per slice: %s\n',  ....
                'Disk usage: %0.2f GB'], ...
                round(scnSet.FOV_alongColsinMicrons), ...
                round(scnSet.FOV_alongRowsinMicrons), ...
                scnSet.micronsPerPixel_cols, scnSet.micronsPerPixel_rows, micronsBetweenOpticalPlanes, ...
                tilesPlane.X, tilesPlane.Y, R.mosaic.sliceThickness*R.mosaic.numSections, channelsToAcquireString, ...
                endTime.timeForSampleString, endTime.timePerSectionString, estimatedSize);

        elseif isempty(scnSet)
            msg = sprintf('System ID: %s ; Scanner: %s', R.SYSTEM.ID, scannerID);
        end

        % Place system name in window title
        obj.hFig.Name = sprintf('BakingTray on %s', R.SYSTEM.ID);
        set(obj.text_status,'String', msg)

        % Finally we highlight the tile size label as needed
        obj.updateTileSizeLabelText(scnSet)

        if nargout>0
            varargout{1} = msg;
        end

    end
end %updateStatusText
