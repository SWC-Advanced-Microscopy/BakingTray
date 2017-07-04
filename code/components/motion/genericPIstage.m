classdef genericPIstage < linearstage
%% 
% Generic PI stage class
%
%
% All abstract methods should have doc text only in the abstract method class file.

    properties

    end

    methods
        
        %Constructor
        function obj = genericPIstage(obj)
            obj.axisID = '1'; %This is the default for PI controllers with one axis only
        end %Constructor


    end %methods


end