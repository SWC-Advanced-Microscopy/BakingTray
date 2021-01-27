function [tThresh,stats] = autoThresh(im,settings)
    % Returns the absolute threshold between the sample and background from an image
    %
    % function tThresh = autoThresh(im,settings)
    %
    % Purpose
    % Uses the 2D image, im, to obtain a threshold between sample and background
    %
    % Inputs
    % im - a 2d image
    % settings - optional. The output of autoROI.readSettings
    %
    % Outputs
    % im - the image with bright pixels set to zero
    % stats - more info to be used for debugging and logging
    %
    % Rob Campbell - SWC 2021
    %
    % See also: removeBrightBlocks, obtainCleanBackgrounSD


    if nargin<2
        settings = autoROI.readSettings;
    end

    [SD_bg,median_bg,stats] = autoROI.autothresh.wholeImageGMM.obtainCleanBackgroundSD(im,settings);

    %Find pixels within b pixels of the border
    tThreshSD = settings.main.defaultThreshSD;
    tThresh = median_bg + SD_bg*tThreshSD;
