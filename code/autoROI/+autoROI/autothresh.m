function thresh = autothresh(pStack)
    % Run the correct algorithm's code for obtaining a threshold


    settings = autoROI.readSettings;

    switch settings.alg
        case 'dynamicThresh_Alg'
            thresh = dynamicThresh_Alg.autothresh.run(pStack);
        otherwise
            stats= [];
            fprintf('Algorithm %s is unkown. QUITTING\n',settings.alg)
    end


    if nargout>0
        varargout{1} = stats;
    end
