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
        tmp=squeeze(mean(tRows(pixToAverage,:),1));
        OUT.statsRows(ii) = fitDataToSigmoid(x, tmp );

        tCols = squeeze(mean(im(:,1:nLines,:),2));
        OUT.statsCols(ii) = fitDataToSigmoid(x, squeeze(mean(tCols(pixToAverage,:),1)) );

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







function fitStruct = fitDataToSigmoid(x,y)

    % Prepare data and generate starting parameters
    [x,y] = prepareCurveData(x,y);

    % Store fit data in a structure
    fitStruct.x = x;
    fitStruct.y = y;

    automatic_initial_params=[quantile(y,0.05) quantile(y,0.95) 1 1];

    %estimate the 50% point
    if sum(y==quantile(y,0.5))==0
        automatic_initial_params(3) = x(y==quantile(y(2:end),0.5));
    else
        automatic_initial_params(3) = x(y==quantile(y,0.5));
    end


    tFit = @(param,xval) param(1) + ( param(2)-param(1) )./ ( 1 + 10.^( ( param(3) - xval ) * param(4) ) );


    [BETA,RESID,JAC,COVB] = nlinfit(x, y, tFit, automatic_initial_params);
    fitStruct.yHat = tFit(BETA,x);
    fitStruct.param=BETA';
    fitStruct.fit = tFit;

    % confidence interval of the parameters
    fitStruct.paramCI = nlparci(BETA,RESID,'Jacobian',JAC);

    % confidence interval of the estimation
    [fitStruct.ypred,delta] = nlpredci(tFit,x,BETA,RESID,'Covar',COVB);
    fitStruct.ypredlowerCI = fitStruct.ypred - delta;
    fitStruct.ypredupperCI = fitStruct.ypred + delta;
    fitStruct.startingParams = automatic_initial_params;

    %Find the x value nearest to the midpoint of the fit
    [~,minInd]=min(abs(x-BETA(3)));
    fitStruct.maxSlope.x = x(minInd);
    fitStruct.maxSlope.yHat = fitStruct.yHat(minInd);


function plotDataAndFit(fRes,tColor)
    hold on
    dotColor = tColor+0.5;
    dotColor(dotColor>1)=1;
    h = plot(fRes.x, fRes.y,'.','Color',dotColor); % The raw data

    plot(fRes.x, fRes.yHat,'-','Color',tColor) %The fit

    plot(fRes.maxSlope.x, fRes.maxSlope.yHat, 'o', 'Color', tColor) %The mid-point
    hold off

