function varargout=autoROI(pStack, lastSectionStats, varargin)
    % autoROI
    %
    % function varargout=autoROI(pStack, lastSectionStats, 'param',val, ... )
    % 
    % Purpose
    % Automatically detect regions in the current section where there is
    % sample and find a tile-based bounding box that surrounds it. This function
    % can also be fed a bounding box list in order to use these ROIs as a guide
    % for finding the next set of boxes in the next section. This mimics the 
    % behavior under the microscope. 
    % See: autoROI.text.runOnStackStruct
    %
    % Return results in a structure.
    %
    % 
    % Inputs (Required)
    % pStack - The pStack structure. From this we extract key information such as pixel size.
    % lastSectionStats - By default the whole image is used. If this argument is 
    %               present it should be the output of autoROI from a
    %               previous section. This is empty by default. Not in input parser
    %               because adding there slows down the parser.
    %
    %
    %
    % Inputs (Optional param/val pairs)
    %
    % Common to all algorithms
    % settings - the settings structure. If empty or missing, we read from the file itself
    % showBinaryImages - shows results from the binarization step
    % doPlot - if true, display image and overlay boxes. false by default
    %
    %
    % Dynamic Threshold Algorithm
    % tThresh - Threshold for tissue/no tissue. By default this is auto-calculated
    % tThreshSD - Used to do the auto-calculation of tThresh.
    % isAutoThresh - false by default. If autoROI is being called from autoThresh.run, then
    %                this should be true. If true, we don't expand ROIs with tissue clipping.
    % skipMergeNROIThresh - If more than this number of ROIs is found, do not attempt
    %                         to merge. Just return them. Used to speed up auto-finding.
    %                         By default this is infinity, so we always try to merge.
    % doBinaryExpansion - default from setings file. If true, run the expansion of 
    %                     binarized image routine. 
    %
    %
    %
    % Outputs
    % stats - borders and so forth
    % binaryImageStats - detailed stats on the binary image step (see binarizeImage) NOT IMPLEMENTED RIGHT NOW
    % H - plot handlesNOT IMPLEMENTED RIGHT NOW
    %
    %
    % Rob Campbell - SWC, 2019




    % Parse optional input arguments
    params = inputParser;
    params.CaseSensitive = false;
    params.addParameter('tNet', [])
    params.addParameter('doPlot', [])

    params.parse(varargin{:})
    tNet = params.Results.tNet;



    settings = autoROI.readSettings;

    switch settings.alg
        case 'dynamicThresh_Alg'
            stats=dynamicThresh_Alg.run(pStack,lastSectionStats,varargin{:});
        case 'chunkedCNN_Alg'
            stats=chunkedCNN_Alg.run(pStack,lastSectionStats,tNet);
        case 'u_net_Alg'
            stats=u_net_Alg.run(pStack,lastSectionStats,tNet);
        otherwise
            stats= [];
            fprintf('autoROI.m does not know algorithm module %s. QUITTING.\n',settings.alg)
    end



    if nargout>0
        varargout{1} = stats;
    end
