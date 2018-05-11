function OUT=measureScanPlaneTilt(planeData)

    % Purpose
    % Measure the tilt


    d = size(planeData(1).imStack);
    nLines = round(d(1)/10);

    %middle pixels to avererage
    midPix = round(d(1)/2);
    n=20;
    pixToAverage = (midPix-n) : (midPix+n);

    delta = planeData(1).distanceBetweenDepths;
    x = (0:(size(planeData(1).imStack,3)-1)) * delta;


    for ii=1:3

        im=double(planeData(ii).imStack);

        m = mean(im,3);
        im = im-min(m(:));

        m = mean(im,3);
        im = im/max(m(:));


        tRows = squeeze(mean(im(1:nLines,:,:),1));
        OUT.statsRows(ii) = BakingTray.utils.fitSigmoidToData(x, squeeze(mean(tRows(pixToAverage,:),1)) );

        tCols = squeeze(mean(im(:,1:nLines,:),2));
        OUT.statsCols(ii) = BakingTray.utils.fitSigmoidToData(x, squeeze(mean(tCols(pixToAverage,:),1)) );

    end



    clf

    subplot(1,2,1)
    cols = {[1,0,0]; [0,1,0]; [0,0,1]};
    for ii=1:3
        plotDataAndFit(OUT.statsRows(ii),cols{ii})
    end
    xlabel('depth (microns)')
    title('Rows')
    box on 
    grid on

    subplot(1,2,2)
    for ii=1:3
        plotDataAndFit(OUT.statsCols(ii),cols{ii})
    end
    xlabel('depth (microns)')
    title('Columns')
    box on
    grid on




function plotDataAndFit(fRes,tColor)
    hold on
    dotColor = tColor+0.5;
    dotColor(dotColor>1)=1;
    h = plot(fRes.x, fRes.y,'.','Color',dotColor); % The raw data

    plot(fRes.x, fRes.yHat,'-','Color',tColor) %The fit

    plot(fRes.maxSlope.x, fRes.maxSlope.yHat, 'o', 'Color', tColor) %The mid-point
    hold off

