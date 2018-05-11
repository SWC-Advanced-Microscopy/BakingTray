function fitStruct = fitSigmoidToData(x,y)
    % Fit a sigmoid to data
    %
    % function fitStruct = fitSigmoidToData(x,y)
    %
    %
    % Prepare data and generate starting parameters
    %
    % Returns parameters:
    %  [min, max, x50%, slope]
    %
    % y should ideally be in the 0 to 1.0 range


    [x,y] = prepareCurveData(x,y);

    % Store fit data in a structure
    fitStruct.x = x;
    fitStruct.y = y;

    initialParams=[quantile(y,0.05) quantile(y,0.95) 1 1];

    %estimate the 50% point
    if sum(y==quantile(y,0.5))==0
        f=find(y==quantile(y(2:end),0.5));
    else
        f=find(y==quantile(y,0.5));
    end


    if length(f)>1
        f=f(1);
        fprintf('Data might be noisy. Multiple 50%% values found by %s. Choosing %0.2f\n',  mfilename, x(f));
    end
    initialParams(3) = x(f);


    tFit = @(param,xval) param(1) + ( param(2)-param(1) )./ ( 1 + 10.^( ( param(3) - xval ) * param(4) ) );


    [BETA,RESID,JAC,COVB] = nlinfit(x, y, tFit, initialParams);
    fitStruct.yHat = tFit(BETA,x);
    fitStruct.param=BETA';
    fitStruct.fit = tFit;

    % confidence interval of the parameters
    fitStruct.paramCI = nlparci(BETA,RESID,'Jacobian',JAC);
    fitStruct.Jacobian = JAC;
    fitStruct.covb = COVB;
    fitStruct.badFit = any(all(JAC==0));

    % confidence interval of the estimation
    [fitStruct.ypred,delta] = nlpredci(tFit,x,BETA,RESID,'Covar',COVB);
    fitStruct.ypredlowerCI = fitStruct.ypred - delta;
    fitStruct.ypredupperCI = fitStruct.ypred + delta;
    fitStruct.startingParams = initialParams;

    %Find the x value nearest to the midpoint of the fit
    [~,minInd]=min(abs(x-BETA(3)));
    fitStruct.maxSlope.x = x(minInd);
    fitStruct.maxSlope.yHat = fitStruct.yHat(minInd);
