function optimalWavelength = determineLaserWavelength(obj,diagnosticPlot)
    % Based on emission spectra figure out the optimal laser wavelength
    %
    %  function optimalWavelength = channelChooser.determineLaserWavelength(obj,diagnostPlot)
    %
    % Purpose
    % Returns optimal laser wavelength in nm
    %
    % Inputs
    % diagnosticPlot - optional bool. false by default. If true returns a plot
    %                  showing how the result was achieved. 
    %

    % TODO:
    % 1. Compare mCherry at 760 and 780. How much nicer is it? Should we cap the laser to 780? Are there other issues with 760?
    % 2. Compare tdTomato at 920 vs 980. Supposedly it's brighter at 980 and if we have it alone then this would make sense. However,
    %    how much less power is there? Will it be a hasle to set up or should I just have a power calib curve for 980? 
    % 3. Maybe I should write code to make a power calib table automatically. Then it can be produced for the user at the same time
    %    as the laser wavelenth is set. 


    if nargin<2
        diagnosticPlot = false;
    end 


    optimalWavelength = [];

    if isempty(obj.hDyeSpectraExcitation)
        return
    end

    tFields = fields(obj.hDyeSpectraExcitation);

    if isempty(tFields)
        return
    end

    % Go through the wavelength range and determine the mean fluorophore brightness
    % for each trace in 10 nm bins. Take into account the fact that curves are
    % sampled at different rates.
    eSpectra =  obj.hDyeSpectraExcitation;

    XLim = obj.hAxesExcite.XLim;
    stepSize = 10;
    eL = XLim(1):stepSize:XLim(2);

    eSpectra = zeros(length(eL)-1, length(tFields));

    for ii=1:length(tFields)

        eSpectra(:,ii) = resampleCurve(obj.hDyeSpectraExcitation.(tFields{ii}),eL);
        % We will not consider ever setting the wavelength to values
        % where one of the flurophores has a very low value. So we 
        % bias ourselves here by setting these to Nans. TODO.
        

    end

    % To bias away from choosing values where a fluorophore is very low brightness, set
    % any brightness values that are less than 2.5 to -10
    eSpectra(eSpectra<=2.5)=-10;

    normSpectra = eSpectra ./ max(eSpectra);

    [val,ind]=max(sum(normSpectra,2));
    x = eL(1:end-1) + stepSize/2;

    optimalWavelength = x(ind);


    if ~diagnosticPlot
        return
    end

    fprintf('Optimal wavelength: %d nm\n', optimalWavelength)

    f = figure(sum(mfilename));
    f.Name = 'wavelength diagnostics';
    subplot(1,2,1)
    plot(eSpectra), drawnow,
    plot(x,sum(eSpectra,2)), drawnow,

    subplot(1,2,2)
    plot(x,sum(normSpectra,2))



    function areaUnderCurve = chanOverlap(X,Y)
        areaUnderCurve = zeros(1,length(obj.chanRanges));

        for kk=1:length(obj.chanRanges)
            cr = obj.chanRanges(kk);
            minL = cr.centre - (cr.width/2);
            maxL = cr.centre + (cr.width/2);
            f = find(X>minL & X<maxL);
            areaUnderCurve(kk) = sum(Y(f));
        end
        
    end

end %determineLaserWavelength


function OUT = resampleCurve(data,eL)
    % resampleCurve
    % Resample the wavelength curve in fixed bins defined by the vector eL

    X = data.XData;
    Y = data.YData;

    OUT = zeros(1,length(eL)-1);

    origDataSamplePeriod = mode(diff(X));
    for ii = 1:length(eL)-1
        f = find(X>=eL(ii) & X<=eL(ii+1));
        OUT(ii) = mean(Y(f));
    end

end %resampleCurve
