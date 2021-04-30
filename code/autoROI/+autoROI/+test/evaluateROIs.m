function report=evaluateROIs(stats,pStack)
% Evaluate how well the bounding boxes capture the sample tissue
%
%  function txtReport=autoROI.test.evaluateROIs(stats)
%
% Purpose
% Report accuracy of tissue (sample) finding with a text report. Shows images of failed sections
% if no outputs were requested. NOTE: evaluates based on the border
% defined in pStack.borders and not on the binarised image.
% This function is run automatically by test.runOnStackStruct once
% it has finished processing all of the data.
%
% Inputs
% The pStackLog file in test directory. The pStack is loaded automatically.
%
% Inputs (optional)
% pStack - if supplied optionally as a second input argument, the pStack
%          is not loaded from disk.
%
%
% Example
% testLog  = autoROI.test.runOnStackStruct(testLog)
% autoROI.test.evaluateROIs(testLog)
% autoROI.test.evaluateROIs(testLog,pStack)
%
% Outputs
% report - A structure describing how well this sample registered. 

% Look for pStack file to load
if nargin==1
    pStackFname = stats.stackFname;
    if ~exist(pStackFname,'file')
        txtReport = sprintf('No pStack file found at %s\n', pStackFname);
        fprintf(txtReport)
        return
    else
        fprintf('Loading stack file %s\n',pStackFname)
        load(pStackFname)
    end
end


nPlanesWithMissingTissue=0;

txtReport = '';


if length(stats.roiStats)~=size(pStack.binarized,3)
    msg=sprintf('WARNING -- There are %d sections in the image stack but only %d were processed.\n', ...
        size(pStack.binarized,3), length(stats.roiStats));
    fprintf(msg)
    txtReport = [txtReport,msg];
end

% Look for cases where the bounding box covers more than 99% of the FOV
numSectionsWithHighCoverage = sum([stats.roiStats.propImagedAreaCoveredByBoundingBox]>0.975);
if numSectionsWithHighCoverage>0
    msg=sprintf('WARNING -- Proportion of original imaged area has coverage of over 0.975 in %d sections\n', ...
        numSectionsWithHighCoverage);
    fprintf(msg)
    txtReport = [txtReport,msg];
end

numSectionsWithOverFlowingCoverage = sum([stats.roiStats.propImagedAreaCoveredByBoundingBox]>1);
if numSectionsWithOverFlowingCoverage>0
    msg=sprintf('WARNING -- Proportion of original imaged area has coverage of over 1.0 in %d sections\n', ...
        numSectionsWithOverFlowingCoverage);
    fprintf(msg)
    txtReport = [txtReport,msg];
end



%Report the average proportion of pixels within a boundingbox that have tissue
if isfield(stats.roiStats,'foregroundSqMM')
    medPropPixelsInRoiThatAreTissue=median(([stats.roiStats.foregroundSqMM]./[stats.roiStats.totalBoundingBoxSqMM]));
    msg=sprintf('Median area of ROIs filled with tissue: %0.2f (run at %d micron border size).\n', ...
        medPropPixelsInRoiThatAreTissue, stats.settings.mainBin.expansionSize);
    fprintf(msg)
    txtReport = [txtReport,msg];
else
    medPropPixelsInRoiThatAreTissue = [];
end

%Report the total imaged area, summing over all ROIs
totalImagedSqMM=sum([stats.roiStats.totalBoundingBoxSqMM]);
msg=sprintf('Total imaged sq mm in this acquisition: %0.2f\n', ...
    totalImagedSqMM);
fprintf(msg)
txtReport = [txtReport,msg];


%Report the proportion of the original FOV that was imaged. 
%This is, of course, only valid for data not acquired with an auto-finder
imSizeSqmm = prod(size(pStack.imStack)) * (pStack.voxelSizeInMicrons * 1E-3)^2;
propImagedArea = totalImagedSqMM/imSizeSqmm;
msg=sprintf('Proportion of original area imaged by ROIs: %0.4f\n', ...
    propImagedArea);
fprintf(msg)
txtReport = [txtReport,msg];



% Build an output structure
report.numSectionsWithHighCoverage=numSectionsWithHighCoverage;
report.numSectionsWithOverFlowingCoverage=numSectionsWithOverFlowingCoverage;
report.medPropPixelsInRoiThatAreTissue=medPropPixelsInRoiThatAreTissue;
report.totalImagedSqMM=totalImagedSqMM;
report.propImagedArea=propImagedArea;
report.txtReport=txtReport;



% Now loop through the whole stats structure and extract more information for
% cases where there are non-imaged pixels, etc
report.nonImagedTiles=zeros(1,length(stats.roiStats));
report.nonImagedSqMM=zeros(1,length(stats.roiStats));
report.extraSqMM=zeros(1,length(stats.roiStats));


for ii=1:size(pStack.imStack,3)

    %Empty image. We will fill with ones all regions where the ground-truth tissue was found.
    tB = pStack.borders{1}{ii}; % Ground truth tissueborders

    % Create an empty binary image
    BW = zeros(size(pStack.binarized,[1,2])); 

    % Draw the borders over it
    for jj = 1:length(tB)
        if isempty(tB{jj})
            continue
        end

        f = sub2ind(size(BW),tB{jj}(:,1),tB{jj}(:,2));
        BW(f)=1;
    end

    %Fill it in
    BW = imfill(BW);


    % Now we get the bounding boxes and set all pixels within those to zero.
    % So if all the tissue was found the BW image will be full of zeros.
    % HOWEVER: we get the bounding boxes from the preceeding section for all but
    % the first section
    if ii>1
        if length(stats.roiStats)>=ii
            bBoxes = stats.roiStats(ii-1).BoundingBoxes;
        else
            % The auto-finding must have ended prematurely. We make blank data
            bBoxes={};
        end
            
    else
        bBoxes = stats.roiStats(ii).BoundingBoxes;
    end

    for jj=1:length(bBoxes)
        % All pixels that are within the bounding box should be zero
        bb=bBoxes{jj};

        bb(bb<=0)=1; %In case boxes have origins outside of the image
        BW(bb(2):bb(2)+bb(4), bb(1):bb(1)+bb(3))=0;
    end

    % Any non-zero pixels indicate non-imaged sample areas. These are the 
    % number of non-imaged pixels in the original, non-rescaled, images.
    nonImagedPixels = sum(BW,[1,2]);


    if nonImagedPixels>0
        nPlanesWithMissingTissue = nPlanesWithMissingTissue + 1;

        if nargout==0
            imagesc(pStack.imStack(:,:,ii));

            % Overlay the sample border
            hold on
            for jj=1:length(pStack.borders{1}{ii})
                tBorder = pStack.borders{1}{ii}{jj};
                plot(tBorder(:,2),tBorder(:,1), '--c')
                plot(tBorder(:,2),tBorder(:,1), ':g','LineWidth',1)
            end
            hold off

            % Overlay bounding boxes
            for jj=1:length(bBoxes)
                bb=bBoxes{jj};
                autoROI.plotting.overlayBoundingBox(bb);
            end


            set(gcf,'Name',sprintf('%d/%d',ii,size(pStack.binarized,3)))
            caxis([0,300])
            drawnow
        end

        % How many pixels fell outside of the area?
        pixelsInATile = round(pStack.tileSizeInMicrons/pStack.voxelSizeInMicrons)^2;
        nonImagedTiles = nonImagedPixels/pixelsInATile;
        if nonImagedTiles>1
            warnStr = ' * ';
        elseif nonImagedTiles>2
            warnStr = ' ** ';
        elseif nonImagedTiles>3
            warnStr = ' *** ';
        else
            warnStr = '';
        end

        nonImagedSqMM = nonImagedPixels * (pStack.voxelSizeInMicrons*1E-3)^2;

        msg = sprintf('%sSection %03d/%03d, %d ROIs, %d non-imaged pixels; %0.3f tiles; %0.3f sq mm \n', ...
            warnStr, ...
            ii, ...
            size(pStack.binarized,3), ...
            length(bBoxes), ...
            nonImagedPixels, ...
            nonImagedTiles, ...
            nonImagedSqMM);

        fprintf(msg)
        txtReport = [txtReport,msg];

        % Add to cumulative total
        report.nonImagedTiles(ii)=nonImagedTiles;
        report.nonImagedSqMM(ii)=nonImagedSqMM;
    end

    % Add this information to the output structure




    % Calculate how many pixels were imaged more than once. Weight each by the number of extra times it was imaged.
    tmp=autoROI.genOverlapStack(bBoxes,size(pStack.imStack,1:2));
    tmp=sum(tmp,3);
    tmp=tmp-1;
    tmp(tmp<0)=0;
    totalPixOverlaps = sum(tmp(:));
    totalExtraSqmm = totalPixOverlaps * (pStack.voxelSizeInMicrons * 1E-3)^2;
    if totalPixOverlaps>0
        msg = sprintf('Section %03d/%03d has %0.3f extra sq mm due to multiple-imaging of pixels\n', ...
            ii, size(pStack.binarized,3), totalExtraSqmm);
        fprintf(msg)
        txtReport = [txtReport,msg];
    end
    report.extraSqMM(ii)=totalExtraSqmm;

end %for ii=1:size(pStack.imStack,3)

report.nPlanesWithMissingTissue=nPlanesWithMissingTissue;

if nPlanesWithMissingTissue==0
    msg=sprintf('GOOD -- None of the %d evaluated sections have sample which is unimaged.\n', ...
        length(stats.roiStats));
    fprintf(msg)
    txtReport = [txtReport,msg];
end
