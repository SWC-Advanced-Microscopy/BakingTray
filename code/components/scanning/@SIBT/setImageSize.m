function setImageSize(obj,pixelsPerLine,evnt)
    % Set image size
    %
    % Purpose
    % Change the number of pixels per line and ensure that the number of lines per frame changes 
    % accordingly to maintain the FOV and ensure pixels are square. This is a bit harder than it 
    % needs to be because we allow for non-square images and the way ScanImage deals with this is 
    % clunky. 
    % 
    % Inputs
    % If pixelsPerLine is an integer, this method applies it to ScanImage and ensures that the
    % scan angle multipliers remain the same after the setting was applied. It doesn't alter
    % the objective resolution value.
    %
    % This method can also be run as a callback function, in which case pixelsPerLine is a is
    % the source structure (matlab.ui.container.Menu) and should contain a field called 
    % "UserData" which is a structure that looks like this:
    %
    %              objective: 'nikon16x'
    %          pixelsPerLine: 512
    %           linePerFrame: 1365
    % nominalMicronsPerPixel: 0.7850
    %               fastMult: 0.7500
    %               slowMult: 2
    %                 objRes: 59.5500
    %
    % This information is then used to apply the scan settings. 

    if isa(pixelsPerLine,'matlab.ui.control.UIControl') % Will be true if we're using a pop-up menu to set the image size
        if ~isprop(pixelsPerLine,'UserData')
            fprintf('SIBT.setImageSize is used as a CallBack function but finds no field "UserData" in its first input arg. NOT APPLYING IMAGE SIZE TO SCANIMAGE.\n')
            return
        end
        if isempty(pixelsPerLine.UserData)
            fprintf('SIBT.setImageSize is used as a CallBack function but finds empty field "UserData" in its first input arg. NOT APPLYING IMAGE SIZE TO SCANIMAGE.\n')
            return
        end

        settings=pixelsPerLine.UserData(pixelsPerLine.Value);
        if ~isfield(settings,'pixelsPerLine')
            fprintf('SIBT.setImageSize is used as a CallBack function but finds no field "pixelsPerLine". NOT APPLYING IMAGE SIZE TO SCANIMAGE.\n')
            return
        end

        pixelsPerLine = settings.pixelsPerLine;
        pixEqLin = settings.pixelsPerLine==settings.linesPerFrame; % Is the setting asking for a square frame?
        fastMult = settings.fastMult;
        slowMult = settings.slowMult;
        objRes = settings.objRes;

    else
        pixEqLin = obj.hC.hRoiManager.pixelsPerLine == obj.hC.hRoiManager.linesPerFrame; % Do we currently have a square image?
        fastMult = [];
        slowMult = [];
        objRes = [];
    end

    %Let's record the image size
    orig = obj.returnScanSettings;

    % Do we have square images?
    pixEqLinCheckBox = obj.hC.hRoiManager.forceSquarePixelation;


    if pixEqLin % is the user asking for square tiles?
        % It's pretty easy to change the image size if we have square images. 
        if ~pixEqLinCheckBox
            fprintf('Setting Pix=Lin check box in ScanImage CONFIGURATION window to true\n')
            obj.hC.hRoiManager.forceSquarePixelation=true;
        end
        obj.hC.hRoiManager.pixelsPerLine=pixelsPerLine;

        else

            if pixEqLinCheckBox
                fprintf('Setting Pix=Lin check box in ScanImage CONFIGURATION window to false\n')
                obj.hC.hRoiManager.forceSquarePixelation=false;
            end

            % Handle changes in image size if we have rectangular images
            if isempty(slowMult)
                slowMult = obj.hC.hRoiManager.scanAngleMultiplierSlow;
            end
            if isempty(fastMult)
                fastMult = obj.hC.hRoiManager.scanAngleMultiplierFast;
            end

            obj.hC.hRoiManager.pixelsPerLine=pixelsPerLine;

            obj.hC.hRoiManager.scanAngleMultiplierFast=fastMult;
            obj.hC.hRoiManager.scanAngleMultiplierSlow=slowMult;

            if ~isempty(objRes)
                obj.hC.objectiveResolution = objRes;
            end

    end

    % Issue a warning if the FOV of the image has changed after changing the number of pixels. 
    after = obj.returnScanSettings;

    if isempty(objRes)
        % Don't issue the warning if we might change the objective resolution 
        if after.FOV_alongRowsinMicrons ~= orig.FOV_alongRowsinMicrons
            fprintf('WARNING: FOV along rows changed from %0.3f microns to %0.3f microns\n',...
                orig.FOV_alongRowsinMicrons, after.FOV_alongRowsinMicrons)
        end

        if after.FOV_alongColsinMicrons ~= orig.FOV_alongColsinMicrons
            fprintf('WARNING: FOV along cols changed from %0.3f microns to %0.3f microns\n',...
                orig.FOV_alongColsinMicrons, after.FOV_alongColsinMicrons)
        end
    end
