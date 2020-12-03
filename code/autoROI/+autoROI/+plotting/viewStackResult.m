function varargout = viewStackResult(fname,imRange,noCheating)
% Overlay bounding box on current axes
%
% h=autoROI.plotting.viewStackResult(fname,imRange)
%
% Purpose
% Load data into volView based on a stack result file to see results of an analysis. 
% Optionally return handle to volView. 
%
% Inputs
% fname - path to file. If empty or missing a GUI comes up.
% imRange - optional ([1,200] by default) if supplied, this is the 
%           displayed range in volView.
% noCheating - true by default. If true, we overlay the bounding boxes as
%              they would be were we running a live acquisition. i.e. we 
%              overlay the boxes from section n over section n+1
%
%
% Example
% >> autoROI.plotting.viewStackResult('200330_1657/log_CC_125_1__125_2_previewStack.mat')
%
% Rob Campbell - March 2020

if nargin<1 || isempty(fname)
    [fname,tpath] = uigetfile(pwd);
    fname = fullfile(tpath,fname);
    fprintf('Opening %s\n',fname)
end

if ~exist(fname,'file')
    fprintf('Can not find %s\n', fname);
    return
end

[~,~,ext] = fileparts(fname);
if ~strcmp('.mat',ext)
    fprintf('Expected a path to a .mat file\n')
    return
end


if nargin<2 || isempty(imRange)
    imRange=[1,200];
end

if nargin<3
    noCheating=true;
end


load(fname)

fprintf('Loading %s\n',testLog(1).stackFname)

load(testLog(1).stackFname)

% Get the bounding boxes 
if isfield(testLog,'roiStats')
    b={{testLog.roiStats.BoundingBoxes},{},{}};;
else
    b={{testLog.BoundingBoxes},{},{}};;
end


if noCheating
    % Apply bounding boxes as they would be were we running this for real:

    % Duplicate the first one, as we'll apply it twice: to section 1 and section 2. 
    b{1}=[b{1}(1),b{1}(1:end)];

    % Delete the final one: we never apply that
    b{1}(end)=[];
end

H=volView(pStack.imStack,imRange,b);


% Optionally return handle to plot object
if nargout>0
    varargout{1}=H;
end
