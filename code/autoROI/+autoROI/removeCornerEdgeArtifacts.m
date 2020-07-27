function im = removeCornerEdgeArtifacts(im)

    %The corner with the non-laid down tile can create artifacts
    %that mess up the auto-finder. We remove those here. 


    m=medfilt2(im,[3,3]);
    BW = (im - m) > 500;
    mPix = median(im(:));
    im(BW) = m(BW);

