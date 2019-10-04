function previewFilesToTiffStack(dirPath)
% convert a directory of preview images into single stack
%
% function previewFilesToTiffStack(dirPath)
%
% * Purpose
% Running BakingTray with a valid directory defined in hBT.logPreviewImageDataToDir
% will save preview images to mat files in this directory. These are named according
% to the sample name, physical section and optical plane. One per physical section.
% These images can be used for debugging and development. This function converts
% a directory full of preview files into a single stack. Each plane in the stack
% is the average of all planes in one physical section. Data are saved to a .mat
% file that bears the sample ID name and has data saved as int16. You may run this
% function in a directory containing data from multiple samples and it will sort them
% for you automatically. The original .mat files for each plane are not deleted
% automatically.
%
%
% Inputs
% dirPath - if empty uses current directory. Looks in this directory for the preview 
%.          mat files. You may have multiple samples in one directory: these will be
%           separated into different stacks based on name.
%
% Outputs
% none (data are saved to disk instead.)
%
%
% Rob Campbell - SWC 2019



if nargin<1 || isempty(dirPath)
    dirPath=pwd;
end



% look for BakingTray preview files in the named directory
d=dir( fullfile(dirPath,'*_section_*.mat') );

%Remove anything that isn't really a preview file
notSectionFiles = ~cellfun(@(x) regexp(x,'.*?_section_\d+_\d+_\d+_\d+\.mat'),{d.name} );
d(notSectionFiles)=[];

if isempty(d)
    fprintf('Found no preview section files in %s\n', dirPath)
    return
end


% Segregate files into samples
tok = cellfun(@(x) regexp(x,'(.*?)_section_\d+_\d+_\d+_\d+\.mat','tokens'),{d.name} );
samples = unique([tok{:}]);

if length(samples)==1
    fprintf('Found one sample called %s\n', samples{1});
else
    fprintf('Found %d samples:\n', length(samples))
    cellfun(@(x) fprintf(' - %s\n',x),samples)
end

% Loop through samples and convert to stack
for ii=1:length(samples)
    pStack=buildStack(dirPath,samples{ii});
    fname = fullfile(dirPath,sprintf('%s_previewStack.mat',samples{ii}));
    fprintf('Saving variable pStack to %s', fname)
    save(fname, '-v7.3', 'pStack')
    fprintf('\n\n')
end





function OUT=buildStack(dirPath,sampleName)
    % 

    fprintf('Determining logged channel for sample %s\n', sampleName)
    % All files associated with this sample
    d = dir(fullfile(dirPath,[sampleName,'_section_*.mat']));

    % Open the last one and find which plane contains data
    load(d(end).name)

    % Collapse over optical planes
    imData = squeeze(mean(imData,3));

    % Reduce the influence of the un-imaged corner
    f=(imData == -2^15);
    tmp=(imData(~f));
    imData(f) = pi;

    % Find the plane containing data
    mu=squeeze(mean(mean(imData)));
    [~,dataPlaneInd]=max(abs(mu-median(mu)));
    fprintf('Logged channel is channel %d\n', dataPlaneInd)

    imData = imData(:,:,dataPlaneInd);

    %Further remove the nasty corner
    indexEmptyPatch = (imData==pi);
    tmp = imData(~indexEmptyPatch);
    mm = median(tmp(:));
    imData(indexEmptyPatch) = mm;

    % Loop through all to build stack
    OUT = repmat(imData,[1,1,length(d)]);
    OUT(:)=0;

    fprintf('Loading %d planes in parallel for sample %s...', length(d), sampleName)
    D = {};
    parfor ii=1:length(d)
        L=load(d(ii).name); %load

        if isempty(L.imData), continue, end

        % keep only data we care about
        imData = squeeze(mean(L.imData,3));
        imData = imData(:,:,dataPlaneInd);
        imData(indexEmptyPatch) = mm ; 

        % insert into cell array
        D{ii} = imData;
    end
    fprintf('Done!\n')


    fprintf('Building image stack')
    for ii=1:length(d)
        if isempty(D{ii}), continue, end

        % Skip if the plane we are trying to add is a different size to all the others.
        % This might happen if the first plane is in fact from a different sample. 
        % This is a known bug in BakingTray: https://github.com/SainsburyWellcomeCentre/BakingTray/issues/215
        if ~isequal(size(D{ii}), size(OUT(:,:,1))), 
            continue
        end
        if mod(ii,5)==0, fprintf('.'), end
        sectionNumber = regexp(d(ii).name ,'.*?_section_(\d+)_.*\.mat','tokens');
        sectionNumber = str2num(sectionNumber{1}{1});

        OUT(:,:,sectionNumber)=D{ii};
    end
    fprintf('\n')

    OUT = rot90(OUT,-1);

    %Delete any planes that are empty:
    OUT = OUT(:,:, ~(squeeze([sum(sum(OUT))])==0) );

    % convert to positive ints only
    OUT = int16(OUT - min(OUT(:)));
