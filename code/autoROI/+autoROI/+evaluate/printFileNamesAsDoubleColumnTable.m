function printFileNamesAsDoubleColumnTable(fnames)
    % Print to screen the filenames in the cell array fnames as a double-column table
    %
    % This helper function is used by genComparisonTable and plotResults, amongst others

    maxLengthFname = max(cellfun(@length,{fnames{:}}));

    for ii= 1 : 2 : length(fnames)-mod(length(fnames),2);
        spacesToAdd = maxLengthFname-length(fnames{ii}) + 2; %The spaces between the two columns
        fprintf('%03d/%03d. %s%s%03d/%03d. %s\n', ...
            ii, length(fnames),fnames{ii}, ...
            repmat(' ',1,spacesToAdd), ...
            ii+1, length(fnames),fnames{ii+1} )
    end

    % Print last name if we have an odd number of cases
    if mod(length(fnames),2) == 1
        fprintf('%03d/%03d. %s\n', ...
            length(fnames), length(fnames),fnames{end})

    end