function [tThresh,stats] = autoThresh(im,settings, makePlots)
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
    % makePlots - false by default. If true, we make plots showing how the threshold works 
    %            with this image
    %
    % Outputs
    % im - the image with bright pixels set to zero
    % stats - more info to be used for debugging and logging
    %
    % Rob Campbell - SWC 2021
    %
    % See also: removeBrightBlocks, obtainCleanBackgrounSD


    if nargin<2 || isempty(settings)
        settings = autoROI.readSettings;
    end

    if nargin<3
        makePlots=false;
    end

    [SD_bg,median_bg,stats,BGimage] = autoROI.autothresh.wholeImageGMM.obtainCleanBackgroundSD(im,settings);

    %Find pixels within b pixels of the border
    tThreshSD = settings.main.defaultThreshSD;
    tThresh = median_bg + SD_bg*tThreshSD;

    stats.SD_bg = SD_bg;
    stats.median_bg = median_bg;



    if ~makePlots
        return
    end


    figure(19348)
    clf

    subplot(2,2,1)
    hist(single(im(:)),2000)
    hold on
    plot([tThresh,tThresh],ylim,'-r')
    legend('Pixel counts','threshold')
    title(sprintf('Image histogram thresh=%0.1f',tThresh))
    hold off
    grid on 

    subplot(2,2,2)
    f=find(stats.statsGMM.hist.n>0);
    bar(stats.statsGMM.hist.x(1:f(end)), stats.statsGMM.hist.n(1:f(end)) )
    hold on
    plot([tThresh,tThresh],ylim,'-r')
    legend('Pixel counts','threshold')
    hold off
    title('Histgram fed to GMM')
    grid on 


    subplot(2,2,3)
    imagesc(BGimage)
    axis equal tight
    colormap gray