function OUT=previewMatFilesToImStack(dirToProcess)
% Process all mat files saved by BakingTray into image stacks
%
% function previewMatFilesToImStack(dirToProcess)
%
% Purpose
% Average all depths into one image and stack them up in a mat file. Process all samples
% and files in directory. 



d=dir('*.mat');


% Find unique sample names
fnames = cell(1,length(d));

for ii=1:length(d)
    fnames{ii} = regexprep(d(ii).name,'_section.*','');
end


samples= unique(fnames);



for ii=1:length(samples)
    OUT=processSample(samples{ii});
    return
end



function OUTDATA=processSample(sampleName)
    maxSection=1000; % crappy. Hard-code max number of sections
    d = dir([sampleName,'*']);

    % find cases where there are multiple files associated with each section
    % this is a bug in BakingTray.
    founddups=false;
    for ii=1:maxSection
        tempFname = sprintf([sampleName,'_section_%d_*'],ii);
        td=dir(tempFname);
        if length(td)>1
            fprintf('DUPLICATE SECTION FILE FOR %s. NOT PROCESSING THIS SAMPLE \n',tempFname)
            founddups=true;
        end
    end

    if founddups
        return
    end


    % Which channels have data?
    load(d(1).name)
    d(1).name
    dataChans = squeeze(sum(abs(imData),[1,2,3]));
    dataChans = dataChans>0;

    % Get a list of the section numbers since they may well not start at 1
    secnums = ones(1,length(d));

    for ii=1:length(d)
        tok=regexp(d(ii).name,'.*section_(\d+)_.*','tokens');
        secnums(ii) = str2num(tok{1}{1});
    end
    
    secnums=sort(secnums);
    if ~all(diff(secnums)==1)
        data(1).name
        fprintf('\n BAD: There are discontinuous section numbers\n')
        disp(secnums)
        fprintf('\n BAD: There are discontinuous section numbers\n')
        return
    end


    OUTDATA = {};

    for cc = 1:length(dataChans)

        if dataChans(cc)==0
            continue
        end

        tempFname = dir(sprintf([sampleName,'_section_%d_*'],secnums(1)));
        load(tempFname.name);
        TMP = mean(imData(:,:,:,cc),3);
        TMP = repmat(TMP,[1,1,length(d)]);
        for ii = 2:length(secnums)
            tempFname = dir(sprintf([sampleName,'_section_%d_*'],secnums(ii)));
            disp(tempFname.name)
            load(tempFname.name);
            TMP(:,:,ii) = mean(imData(:,:,:,cc),3);
        end
        OUTDATA{cc}=TMP;
    end
