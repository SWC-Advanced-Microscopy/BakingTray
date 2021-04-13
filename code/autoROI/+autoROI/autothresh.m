function [thresh,stats] = autothresh(pStack)
    % Run the correct algorithm's code for obtaining a threshold


    settings = autoROI.readSettings;

    switch settings.alg
        case 'dynamicThresh_Alg'
            [thresh,stats] = dynamicThresh_Alg.autothresh.run(pStack,[],settings);
        otherwise
            thresh = [];
            stats = [];
            fprintf('Algorithm %s is unkown. QUITTING\n',settings.alg)
    end
