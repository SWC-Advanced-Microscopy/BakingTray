function IN=analyseIm(IN)

    imStack = IN.imStack;


    imr = imresize(imStack,1); %does nothing
    fprintf('Processing stack with %d frames\n',size(imStack,3))
    c = zeros(1,size(imStack,3));
    for ii=1:size(imStack,3)
        if mod(ii,10)==0
            fprintf('Doing frame %d\n', ii)
        end


        r = regionprops(imr(:,:,ii)>75);
        [~,ind]=sort([r.Area],'descend');
        r = r(ind(1));
        c(ii) = r.Centroid(1);
    end

    IN.centroid = c;
    mxy.plotResults(IN)
    
end

