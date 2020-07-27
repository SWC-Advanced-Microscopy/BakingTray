function roiStatsToShift = shiftROIsBasedOnStageFrontLeft(target_FrontLeftStageMM,roiStatsToShift)
    % Translate bounding boxes based on the difference in front/left position between two sections
    %
    % function roiStatsToShift = autoROI.shiftROIsBasedOnStageFrontLeft(target_FrontLeftStageMM,roiStatsToShift.)
    %
    % Purpose
    % We use section n to determine where to image in section n+1. This will inevitably result in the
    % the ROI front/left position changing. Consequently, the ROI (bounding box) coords calculated in 
    % section n can not be used to correctly overlay bounding boxes on section n+1. This is a problem
    % because we need to do this in order to pull out the imaged ROIs in n+1 in order to feed them back
    % into autoROI. This method uses the difference in front/left position between section n and n+1 to 
    % shift the ROIs
    %
    % This function is used by core BakingTray methods. Currently it's not used explicitly by autoROI 
    % itself. For example, this function is called by hBTview.view_acquire.overlayLastBoundingBoxes.
    %
    %
    % Inputs
    % target_FrontLeftStageMM - Structure with fields "X" and "Y" defining the FL of the image axes
    %                            in the target (e.g. current) section over which we want to overlay the
    %                            ROIs in roiStatsToShift..
    % roiStatsToShift. - one element from the roiStats structure. This will be modified so that the ROI
    %                   coords will match those acquired at target_FrontLeftStageMM.

    verbose = false;

    micsPix = 20;  % TODO - we hard-code here the number of microns per pixel of the preview image stack

    FL_prevSection = roiStatsToShift.BoundingBoxDetails(1).frontLeftStageMM;

   
    dX_pix = (target_FrontLeftStageMM.X - FL_prevSection.X) / (micsPix * 1E-3);
    dY_pix = (target_FrontLeftStageMM.Y - FL_prevSection.Y) / (micsPix * 1E-3);


    if verbose
        fprintf('%s is shifting ROIs of this section.\n', mfilename)
        fprintf('Previous FL: x=%0.2f y=%0.2f\nTarget FL: x=%0.2f y=%0.2f\n', ...
            FL_prevSection.X, FL_prevSection.Y, target_FrontLeftStageMM.X, target_FrontLeftStageMM.Y)
        fprintf('Shift new ROIs by x=%0.1f and y=%0.1f pixels\n', dX_pix, dY_pix)
    end

    for ii=1:length(roiStatsToShift.BoundingBoxDetails)

        % Altering the BoundingBoxDetails.frontLeftPixel is not necessary
        % as autoROI does not use this. It will use only the ROIs

        if verbose
            fprintf('Bounding box originally at %d/%d and size %d x %d\n', ...
                roiStatsToShift.BoundingBoxes{ii})
        end
        
        % Shifting the corner of the ROIs
        roiStatsToShift.BoundingBoxes{ii}(1) = ...
        roiStatsToShift.BoundingBoxes{ii}(1) + dY_pix;

        roiStatsToShift.BoundingBoxes{ii}(2) = ...
        roiStatsToShift.BoundingBoxes{ii}(2) + dX_pix;

        if verbose
            fprintf('Bounding box now at %d/%d and size %d x %d\n', round(roiStatsToShift.BoundingBoxes{ii}))
        end

        if verbose && any( roiStatsToShift.BoundingBoxes{ii}(1:2) < 0 )
            fprintf('Bounding boxes contain negative corner pixel locations\n')
        end

    end



    % TODO: the BoundingBoxDetails contain the front/left position with which the ROIs were imaged. Once we have run the 
    %       update, we will likely need to update this front/left position too. 
    for ii=1:length(roiStatsToShift.BoundingBoxDetails)
        roiStatsToShift.BoundingBoxDetails(ii).frontLeftStageMM.X = target_FrontLeftStageMM.X;
        roiStatsToShift.BoundingBoxDetails(ii).frontLeftStageMM.Y = target_FrontLeftStageMM.Y;
    end

end