function stats = getBoundingBoxes(BW,im,pixelSize)
    % Get bounding boxes in binarized image, BW. 
    verbose=true;
    settings = autoROI.readSettings;

    % Find bounding boxes, removing very small ones and 
    stats = regionprops(BW,'boundingbox', 'area');

    if isempty(stats)
        fprintf('autofindBrainsInSection.image2boundingBoxes found no sample in ROI! BAD!\n')
        return
    end

    % Delete very small objects and ensure we have no non-integers
    % TODO - could use bwprop filt at this point?
    sizeThresh = settings.mainGetBB.minSizeInSqMicrons / pixelSize;

    for ii=length(stats):-1:1
        stats(ii).BoundingBox(1:2) = round(stats(ii).BoundingBox(1:2));
        stats(ii).BoundingBox(stats(ii).BoundingBox==0)=1;
        if stats(ii).Area < sizeThresh;
            %%fprintf('Removing small ROI of size %d\n', stats(ii).Area)
            stats(ii)=[];
        end
    end
    if length(stats)==0
        fprintf('%s > getBoundingBoxes after removing small ROIs there are none left.\n',mfilename)
    end

    % -------------------
    % Get rid of the non-imaged pixels in the corner tile. This is done because the older
    % test acquisitions have final tiles that were not imaged. This has since been fixed
    % so in live acquisitions all tiles have been imaged.

    for ii=length(stats):-1:1
        % If it's large, we skip analysing it
        boxAreaInSqMM = prod(stats(ii).BoundingBox(3:4)) * (pixelSize*1E-3)^2;
        if boxAreaInSqMM>4
            continue
        end


        % Ask if most pixels the median value.
        tmp=autoROI.getSubImageUsingBoundingBox(im,stats(ii).BoundingBox);
        tMod=mode(tmp(:));
        propMedPix=length(find(tmp==tMod)) / length(tmp(:));
        if propMedPix>0.25
            %Then delete the ROI
            fprintf('Removing corner ROI\n')
            stats(ii)=[];
        end
    end
    % -------------------

    %Sort in ascending size order
    [~,ind]=sort([stats.Area]);
    stats = stats(ind);

    if verbose==false
        return
    end

    if length(stats)==1
        fprintf('%s > getBoundingBoxes Found 1 Bounding Box\n',mfilename)
    elseif length(stats)>1
        fprintf('%s > getBoundingBoxes Found %d Bounding Boxes\n',mfilename,length(stats))
    elseif length(stats)==0
        fprintf('%s > getBoundingBoxes Found no Bounding Boxes\n',mfilename)
    end



