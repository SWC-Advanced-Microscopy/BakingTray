function chansToSave = determineLaserWavelength(obj,diagnosticPlot)
    % Based on emission spectra figure out the optimal laser wavelength
    %
    %  function chansToSave = channelChooser.determineLaserWavelength(obj,diagnostPlot)
    %
    % Purpose
    % Returns optimal laser wavelength in nm
    %
    % Inputs
    % diagnosticPlot - optional bool. false by default. If true returns a plot
    %                  showing how the result was achieved. 
    %


    if nargin<2
        diagnosticPlot = false;
    end 


    laserWavelength = [];

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

    eSpectra = zeros(length(eL), length(tFields));

    for ii=1:length(tFields)

        eSpectra(:,ii) = resampleCurve(obj.hDyeSpectraExcitation.(tFields{ii}),eL);
        % We will not consider ever setting the wavelength to values
        % where one of the flurophores has a very low value. So we 
        % bias ourselves here by setting these to Nans. TODO.
        return

    end


    if ~diagnosticPlot
        return
    end

    f = figure(sum(mfilename));
    f.Name = 'wavelength diagnostics';




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
    X = data.XData;
    Y = data.YData;

    origDataSamplePeriod = mode(diff(X))
    for ii = 1:length(eL)-1
        f = find(X>=eL(ii) & X<=eL(ii+1))
    end
end %resampleCurve
