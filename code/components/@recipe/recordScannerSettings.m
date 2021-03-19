function success=recordScannerSettings(obj)
    % Checks if a scanner object is connected to the parent (BakingTray) object and if so runs
    % its scanner.returnScanSettings method and store the output in recipe.ScannerSettings
    if isempty(obj.parent)
        success=false;
        fprintf('ERROR: recipe class has nothing bound to property "parent". Can not access BT\n')
        return
    end

    if ~isempty(obj.parent.scanner)
        obj.ScannerSettings = obj.parent.scanner.returnScanSettings;

        % Update properties related to the scanner. 
        % Some stuff will be duplicated, but is stored in a nicer format.
        % Other stuff is calculated from the scanner and recipe information
        obj.VoxelSize.X = obj.ScannerSettings.micronsPerPixel_cols;
        obj.VoxelSize.Y = obj.ScannerSettings.micronsPerPixel_rows;

        % get z-voxel size
        if obj.ScannerSettings.numOpticalSlices == 1
            obj.VoxelSize.Z = obj.mosaic.sliceThickness * 1E3;
        elseif obj.ScannerSettings.numOpticalSlices > 1
            obj.VoxelSize.Z = obj.ScannerSettings.micronsBetweenOpticalPlanes;
        end

        obj.Tile.nRows  = obj.ScannerSettings.linesPerFrame;
        obj.Tile.nColumns = obj.ScannerSettings.pixelsPerLine;

        % Figure out if we are using one the pre-set scan settings and copy these
        % values from the scanner to the recipe

        tileOptions = obj.parent.scanner.frameSizeSettings;

        if isempty(tileOptions) || length(fields(tileOptions))==0
            success=false;
            return
        end

        ind = ([tileOptions.pixelsPerLine]==obj.Tile.nColumns) .* ...
            ([tileOptions.linesPerFrame]==obj.Tile.nRows) .* ...
            ([tileOptions.zoomFactor]==obj.ScannerSettings.zoomFactor); 
        ind = find(ind);

        if ~isempty(ind) && length(ind)==1
            FrameData = tileOptions(ind);
        else
            FrameData=[];
            if obj.verbose
                fprintf('Recipe can not find scanner stitching settings\n')
            end
        end

        if isstruct(FrameData) && ...
            (~isfield(FrameData,'stitchingVoxelSize') || isempty(FrameData.stitchingVoxelSize))
            % Just take nominal values. It doesn't matter too much. 
            mu = mean([obj.ScannerSettings.micronsPerPixel_rows, obj.ScannerSettings.micronsPerPixel_cols]);
            obj.StitchingParameters.VoxelSize.X=mu;
            obj.StitchingParameters.VoxelSize.Y=mu;
        elseif isstruct(FrameData)
            obj.StitchingParameters.VoxelSize = FrameData.stitchingVoxelSize;
        else
            if obj.verbose
                fprintf('NOT USING PRE-DEFINED STITCHING PARAMS! NONE AVILABLE\n')
            end
        end

        if isstruct(FrameData) 
            if ~isempty(FrameData.lensDistort)
                obj.StitchingParameters.lensDistort = FrameData.lensDistort;
            else
                obj.StitchingParameters.lensDistort.rows=0;
                obj.StitchingParameters.lensDistort.cols=0;
            end
            if ~isempty(FrameData.affineMat)
                obj.StitchingParameters.affineMat = FrameData.affineMat;
            else
                obj.StitchingParameters.affineMat = eye(3);
            end
            obj.StitchingParameters.scannerSettingsIndex = ind;
        end

        success=true;
    else
        success=false;
    end
end % recordScannerSettings
