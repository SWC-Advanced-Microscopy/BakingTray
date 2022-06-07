function varargout = assessAverage(maxAve)
% Run averaging and display effect of averaging more frames
%
% Purpose
% Simply setting the averaging in ScanImage to different values and looking at the 
% image in Focus mode is a bad way to assess how many frames need to be averaged. 
% You will over-estimate because during this process a lot of bleaching happens and
% so you end up needing average more in order to compensate for the reduced signal. 
%
% This function takes a fixed number of frames (16 by default) and displays images 
% showing the effect of averaging increased numbers of frames: none, 2, 4, 8, and 16.
%
% For best results, run this function over a bit of tissue that has not been imaged. 
%
% 
% Inputs (optional)
% assessAverage - 16 by default
%
% 
% Limitations
% Chooses the first channel only. 
%
%
% Rob Campbell - SWC 2022


if nargin<1
	maxAve=16;
end

% Get hSI from base workspace
W = evalin('base','whos');
if ~ismember('hSI',{W.name})
	error('No hSI found in bse workspace')
end

hSI = evalin('base','hSI'); 

% Record initial values
init_ave = hSI.hDisplay.displayRollingAverageFactor;
init_num_slices = hSI.hStackManager.numSlices;
init_frames_per_slice = hSI.hStackManager.framesPerSlice;


% Set to suitable parameters for this test
hSI.hDisplay.displayRollingAverageFactor = maxAve;
hSI.hStackManager.numSlices = 1;
hSI.hStackManager.framesPerSlice = maxAve;


hSI.startGrab

while ~strcmp(hSI.acqState,'idle')
	pause(0.1)
end


%Tidy
hSI.hDisplay.displayRollingAverageFactor = init_ave;
hSI.hStackManager.numSlices = init_num_slices;
hSI.hStackManager.framesPerSlice = init_frames_per_slice;


% Now get the data
laststripe = hSI.hDisplay.stripeDataBuffer;

im = laststripe{1}.roiData{1}.imageData{1}{1};

im = repmat(im,[1,1,length(laststripe)]);

for ii=2:length(laststripe)
	im(:,:,ii) = laststripe{ii}.roiData{1}.imageData{1}{1};
end


% Plot the image
figure
im = single(im);


n=1; % averaging
ind=1; %index
while n<=size(im,3)
	plt_data(:,:,ind) = mean(im(:,:,1:n),3);
	n = n*2;
	ind = ind + 1;
end

% bound
plt_data = plt_data - min(plt_data(:));
plt_data = plt_data / max(plt_data(:));

disp('Building montage image')
size(plt_data)
montage(plt_data)



if nargout>0
	varargout{1} = im;
end

if varargout>1
	varargout{2} = plt_data;
end
