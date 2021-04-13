function [thresh,stats] = autothresh(pStack)
    % Run the correct algorithm's code for obtaining a threshold


    settings = autoROI.readSettings;

    switch settings.alg
        case 'dynamicThresh_Alg'
            [thresh,stats] = dynamicThresh_Alg.autothresh.run(pStack,[],settings);
        case 'chunkedCNN_Alg'
            thresh = [];
            stats = [];
        otherwise
            thresh = [];
            stats = [];
            fprintf('Autothresh -- Algorithm %s is unkown. QUITTING\n',settings.alg)
    end
