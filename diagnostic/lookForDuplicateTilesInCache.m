function lookForDuplicateTilesInCache(tileCache)
    % Look for duplicate tiles in hBT.allDownsampledTilesOneSection
    %
    % function lookForDuplicateTilesInCache(tileCache)
    %
    %
    % Purpose
    % Look for duplicate acquired tiles
    %
    % Example
    % lookForDuplicateTilesInCache(hBT.allDownsampledTilesOneSection)

    showAllComparisons=false;

    for ii=1:length(tileCache)-1
        a = tileCache{ii};   % This index
        b = tileCache{ii+1}; % The next index

        % In practice only one channel ever contains data, so we look for this
        t = squeeze(sum(a,[1,2]));
        if all(t==0)
            continue
        else
            chan = find(t>0);
            chan = chan(1); % pick the first channel in case multiple are present
        end

        a = a(:,:,:,chan);
        b = b(:,:,:,chan);

        if showAllComparisons
            clf
            subplot(1,2,1), imagesc(a(:,:,1,1)), title(ii)
            subplot(1,2,2), imagesc(b(:,:,1,1)), title(ii+1)
            pause
        end

        % Look for duplicates by subtracting one from the other
        d = a-b;

        % If the differences are all zeros then it's identical
        sD = squeeze(sum(d,[1,2]));
        if any(sD == 0)
            fprintf('Duplicates at tile pos %d and %d\n', ii, ii+1)
            clf
            subplot(1,2,1), imagesc(a(:,:,1,1))
            subplot(1,2,2), imagesc(b(:,:,1,1))
            pause
        end
    end
