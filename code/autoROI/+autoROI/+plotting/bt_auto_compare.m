function bt_auto_compare(BT,aROI)
    % Compare results from BakingTray and autoROI for a single sample
    %
    % Purpose
    % This is an exploratory function. Do a bunch of plots to see if BakingTray
    % is doing a reasonable job of replicated what happens in autoROI during
    % development
    %
    % Inputs
    % BT - The structure saved in rawData/auto_ROI_stats.mat after a BT acquistion
    % aROI - testLog structure of the same acquisition



    % convenience
    B = BT.roiStats;
    A = aROI;


    clf
    subplot(2,2,1)
    plot([A.stdBackground],'.r-')
    hold on
    plot([B.stdBackground],'.k-')
    ylabel('STD background')

    subplot(2,2,2)
    plot([A.stdForeground],'.r-')
    hold on
    plot([B.stdForeground],'.k-')
    ylabel('STD foreground')

    subplot(2,2,3)
    plot([A.BoundingBoxSqMM],'.r-')
    hold on
    plot([B.BoundingBoxSqMM],'.k-')
    xlabel('section')
    ylabel('Bounding box sq mm')

    subplot(2,2,4)
    plot([A.tThresh],'.r-')
    hold on
    plot([B.tThresh],'.k-')
    xlabel('section')
    ylabel('tThresh')
    legend('autoROI','BakingTray')