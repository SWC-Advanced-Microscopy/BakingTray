function varargout=measureSurfaceHeight(imStack,varargin)

    % Measure the surface height over a z-stack at multiple points
    %
    % function OUT=measureSurfaceHeight(imStack,varargin)
    %
    % Optional
    % 'distanceBetweenDepths' - a value in microns. By default it is 1
    % 'numSquares' - Number of squares into which to partition the image. (is rounded)
    %                default is 9. Assumes image is square, otherwise the grid will 
    %                contain rectangular tiles.
    % 'diagnosticPlots' - false by default. If true, press return after each plot
    %
    %


    vargout={};

    if isstr(imStack)
        fname = imStack;
        if ~exist(fname,'file')
            fprintf('Can not find file %s\n', fname)
            return
        end
        [~,imStack]=scanimage.util.opentif(fname); % TODO - why do my stacks keep producing a reshape error?
        imStack=squeeze(imStack);
        if ndims(imStack)
            fprintf('Found %d channels in %s. Averaging them all together.\n', size(imStack,3),fname)
            imStack = squeeze(mean(imStack,3));
        end

        % TODO - parse the header and extract depth info
        header = imfinfo(fname);
        header = header(1).ImageDescription;

    end




    %Handle default input arguments
    params = inputParser;
    params.CaseSensitive=false;
    params.addParameter('distanceBetweenDepths',1);
    params.addParameter('numSquares',9);
    params.addParameter('diagnosticPlots',false);
    params.parse(varargin{:});

    distanceBetweenDepths = params.Results.distanceBetweenDepths; %Number of microns between adjacent optical planes
    numSquares = params.Results.numSquares; %Number of microns between adjacent optical planes
    diagnosticPlots = params.Results.diagnosticPlots;


    squaresPersSide = round(sqrt(numSquares));

    gridRows = round( linspace(1,size(imStack,1), squaresPersSide+1) );
    gridCols = round( linspace(1,size(imStack,2), squaresPersSide+1) );


    x = (0:(size(imStack,3)-1)) * distanceBetweenDepths;
    x=x';


    % Scale image so it goes from roughly zero to one
    imStack = double(imStack);
    m = mean(imStack,3); %to get rid of outliers
    imStack = imStack-min(m(:)); 

    m = mean(imStack,3);
    imStack = imStack/max(m(:));

    %Loop through all grid squares and average data


    n=1;
    midPoints = nan(squaresPersSide);
    for ii=1:length(gridRows)-1
        for jj=1:length(gridCols)-1
            tR = gridRows(ii:ii+1);
            tC = gridCols(jj:jj+1);

            thisBlock = imStack(tR,tC,:);
            mu = squeeze(mean(mean(thisBlock)));

            mu = smooth(mu,5); %apply a little smoothing to the z-stack data or it can get noisy and the fit can fail

            GridData(n) = BakingTray.utils.fitSigmoidToData(x,mu);
            if diagnosticPlots
                plotFit(GridData(n),[1,0,0])
                drawnow
                title(sprintf('Position %d ii=%d, jj=%d', n, ii, jj))
                pause
            end

            if GridData(n).badFit==0
                midPoints(ii,jj) = GridData(n).param(3);
            end
            n=n+1;
        end
    end


    clf
    subplot(2,2,1)
    imagesc(midPoints)
    xlabel('Fast axis')
    ylabel('Slow axis')
    colorbar


    subplot(2,2,2)
    [XX,YY]=meshgrid(1:squaresPersSide);

    xx = XX(:);
    yy = YY(:);
    mp = midPoints(:);


    Xpred = [ones(size(xx)) xx yy xx.*yy];
    b = regress(mp,Xpred);
    YFIT = b(1) + b(2)*XX + b(3)*YY + b(4)*XX.*YY;
    surf(XX,YY,YFIT)
    hold on
    s=scatter3(xx,yy,mp,'filled');
    s.MarkerEdgeColor='w';
    s.MarkerFaceColor='r';
    hold off


    subplot(2,2,3)
    x=1:squaresPersSide;
    plot(x, x*b(2),'-r')
    hold on
    plot(x, x*b(3),'-b')
    hold off
    legend('Fast axis','Slow axis')
    title(sprintf('Fast=%0.1f - Slow=%0.1f',b(2),b(3)))

    if nargout>0
        varargout{1}=GridData;
    end









function plotFit(fRes,tColor)
    clf
    hold on
    dotColor = tColor+0.5;
    dotColor(dotColor>1)=1;
    h = plot(fRes.x, fRes.y,'.','Color',dotColor); % The raw data

    plot(fRes.x, fRes.yHat,'-','Color',tColor) %The fit

    plot(fRes.maxSlope.x, fRes.maxSlope.yHat, 'o', 'Color', tColor) %The mid-point
    hold off

