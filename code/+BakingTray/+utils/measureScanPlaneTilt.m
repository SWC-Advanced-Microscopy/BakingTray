function OUT=measureScanPlaneTilt(planeData)

    % Purpose
    % Measure the tilt


    d = size(planeData(1).imStack);
    nLines = round(d(1)/10);

    %middle pixels to avererage
    midPix = round(d(1)/2);
    n=20;
    pixToAverage = (midPix-n) : (midPix+n);

    for ii=1:3

        im=planeData(ii).imStack;

        tRows = squeeze(mean(im(1:nLines,:,:),1));
        tRows = squeeze(mean(tRows(pixToAverage,:),1));

        tCols = squeeze(mean(im(:,1:nLines,:),2));
        tCols = squeeze(mean(tCols(pixToAverage,:),1));


        OUT.R(ii,:) = smooth(tRows,1);
        OUT.C(ii,:) = smooth(tCols,1);

    end



    clf
    delta = planeData(1).distanceBetweenDepths;
    x = 0:delta:length(OUT.R)*delta - delta;
    subplot(1,2,1)
    plot(x , OUT.R')
    xlabel('depth (microns)')
    title('Rows')

    subplot(1,2,2)
    plot(x,OUT.C')
    xlabel('depth (microns)')
    title('Columns')