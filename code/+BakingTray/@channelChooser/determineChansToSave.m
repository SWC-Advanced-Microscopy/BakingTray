function chansToSave = determineChansToSave(obj)
    % Based on plotted spectra and filter ranges, figure out which channels
    % to select for saving
    
    chansToSave = [];

    if isempty(obj.hDyeSpectraEmission)
        return
    end 

    tFields = fields(obj.hDyeSpectraEmission);

    if isempty(tFields)
        return
    end

    chansToSave = zeros(1,length(tFields));
    for ii=1:length(tFields)
        % Determine the channel that overlaps most with the spectrum rather than just where the max is. 
        Y = obj.hDyeSpectraEmission.(tFields{ii}).YData;
        X = obj.hDyeSpectraEmission.(tFields{ii}).XData;
        areaUnderCurve = chanOverlap(X,Y);

        % This is the channel with the biggest area
        [~,ind] = max(areaUnderCurve);
        chansToSave(ii) = ind;
    end
    chansToSave = unique(chansToSave);


    function areaUnderCurve = chanOverlap(X,Y)
        areaUnderCurve = zeros(1,length(obj.chanRanges));

        for kk=1:length(obj.chanRanges)
            cr = obj.chanRanges(kk);
            minL = cr.centre - (cr.width/2);
            maxL = cr.centre + (cr.width/2);
            f = find(X>minL & X<maxL);
            areaUnderCurve(kk) = sum(Y(f));
        end
        
    end %chanOverlap

end %determineChansToSave
