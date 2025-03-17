classdef genericPriorstage < linearstage
%%
% Generic Prior stage class
%
%
% All abstract methods should have doc text only in the abstract method class file.

    properties

    end

    methods

        %Constructor
        function obj = genericPriorstage(obj)
            obj.controllerUnitsInMM = 1E-4; % We multiply by this number to ensure units are in mm
        end %Constructor


    end %methods


end
