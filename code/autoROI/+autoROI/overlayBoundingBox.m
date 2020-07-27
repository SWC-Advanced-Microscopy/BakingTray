function varargout = overlayBoundingBox(boundingBox)
% Overlay bounding box on current axes
%
% h=autoROI.overlayBoundingBox(boundingBox)
%
% Purpose
% Overlays a bounding box on the current axes. Optionally return the handle
% to the plot object. Returns axis  hold state to whatever it was originally. 
%
% Inputs
% boundingBox - vector of length 4. Same format as the regionprops BoundingBox:
%              [x, y, x_width, y_height]
%
% 
% Rob Campbell - November 2019



% Record hold state
origHoldState = ishold;


% Plot the bounding box
hold on 

b=boundingBox;
x=[b(1), b(1)+b(3), b(1)+b(3), b(1), b(1)];
y=[b(2), b(2), b(2)+b(4), b(2)+b(4), b(2)];
h=plot(x,y,'-r','LineWidth',2);


% Return hold state to original value
if ~origHoldState
    hold off
end


% Optionally return handle to plot object
if nargout>0
    varargout{1}=h;
end
