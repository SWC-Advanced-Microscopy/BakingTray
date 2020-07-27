function varargout = showBoundingBoxesForSection(pStack,stats,sectionNumber)
    % Show a plot of a given section with the calculated bounding boxes overlaid
    %
    % h=autoROI.plotting.showBoundingBoxesForSection(pStack,stats,sectionNumber)
    %
    % Purpose
    % This function is used to quickly visualise what the bounding boxes look like. 
    % It also indicates the order in which the boxes will be imaged by BakingTray if
    % they aren't re-ordered. 
    %
    % Inputs
    % pStack
    % stats - output of autoROI.test.runOnStackStruct(pStack)
    %
    % Inputs (optional)
    % sectionNumber - if missing, it's a section 1/3 of the way into the sample
    %

    %

    if nargin<3 || isempty(sectionNumber)
        sectionNumber = round(size(pStack.imStack,3));
    end

    % Plot the section image
    clf
    tSlice=pStack.imStack(:,:,sectionNumber);
    imagesc(tSlice);
    colormap gray
    axis equal tight
    caxis([0, mean(tSlice(:))*4])

    % Overlay the bounding boxes with a number to indicate the order in which they would be imaged.
    BB = stats.roiStats(sectionNumber).BoundingBoxes;
    hold on
        for ii=1:length(BB)
            overlayBB(BB{ii},ii);
        end
    hold off

end


% Local functions follow
function h=overlayBB(b,ind)
    % overlays bounding box, b, and labels it with number, ind. 

    % Box coords for plotting
    x=[b(1), b(1)+b(3), b(1)+b(3), b(1), b(1)];
    y=[b(2), b(2), b(2)+b(4), b(2)+b(4), b(2)];

    % plot box and overlay number
    h=plot(x,y,'-r','LineWidth',2);
    h(2)=text(mean(x(1:4)), mean(y(1:4)), num2str(ind), ...
        'FontWeight','Bold','FontSize',23,'HorizontalAlignment','Center',...
        'Color','k');
    h(3)=text(mean(x(1:4)), mean(y(1:4)), num2str(ind), ...
        'FontWeight','Bold','FontSize',20,'HorizontalAlignment','Center',...
        'Color','r');
end
