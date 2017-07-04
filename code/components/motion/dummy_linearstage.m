classdef dummy_linearstage < linearstage
%% 
% dummy stage class
    
    properties (Hidden)
        speed
    end

    methods

        %Constructor
        function obj = dummy_linearstage
            obj.currentPosition=0;
        end %Constructor

    end %methods



end