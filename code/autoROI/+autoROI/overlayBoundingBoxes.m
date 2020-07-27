function varargout = overlayBoundingBoxes(im,stats)
% Overlay bounding box on current axes
%
% h=autoROI.overlayBoundingBoxes(im,stats)
%
% Purpose
% Overlays all bounding boxes on top of image im using in a stats structure. 
% This function calls autoROI.overlayBoundingBox and is called by autoROI. 
%
% Inputs
% stats
% 
% Rob Campbell - January 2020



% Record hold state
origHoldState = ishold;


% Plot the bounding box
hold on 

imagesc(im)

colormap gray
axis ij equal tight
H=[];
for ii=1:length(stats)
    H(ii)=autoROI.overlayBoundingBox(stats(ii).BoundingBox);
end

drawnow

% Return hold state to original value
if ~origHoldState
    hold off
end


% Optionally return handle to plot object
if nargout>0
    varargout{1}=H;
end
