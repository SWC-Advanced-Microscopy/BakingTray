<<<<<<< Updated upstream
function IN=analyseIm(IN)

    imStack = IN.imStack;
=======
function c=analyseIm(imStack)
>>>>>>> Stashed changes

    imr = imresize(imStack,1); %does nothing
    fprintf('Processing stack with %d frames\n',size(imStack,3))
    c = zeros(1,size(imStack,3));
    for ii=1:size(imStack,3)
        if mod(ii,10)==0
            fprintf('Doing frame %d\n', ii)
        end
<<<<<<< Updated upstream
        r = regionprops(imr(:,:,ii)>50);
=======
        r = regionprops(imr(:,:,ii)>75);
>>>>>>> Stashed changes
        [~,ind]=sort([r.Area],'descend');
        r = r(ind(1));
        c(ii) = r.Centroid(1);
    end
<<<<<<< Updated upstream

    IN.centroid = c;
    mxy.plotResults(IN)

=======
    
>>>>>>> Stashed changes
end

