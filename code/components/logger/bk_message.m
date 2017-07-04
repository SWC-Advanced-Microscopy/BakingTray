classdef (Abstract) bk_message
% bk_message is an abstract class that handles
% logging and display of messages to screen and disk.
% 


methods (Static)
    function display(messageString, messageClass)
        % Displays message string to command line
        % Tags message according to its messageClass
        % TODO: log to file

        if isempty(messageString) || ~ischar(messageString)
            return
        end
        if nargin<2
            messageClass='';
        end

        logLocation=1; %1 is screen

        if ~isempty(messageClass)
            messageString = [messageClass,' - ', messageString];
        end
        fprintf(logLocation, messageString)
        
    end %display

    
end %Static methods


methods (Access=protected, Static)
    function msgClassString = messageClass2MessageClassString(messageClass)
        %Receive a valid message class string and convert to a standardised 
        %output that we can be used for display and to categorise logging.

        switch lower(messageClass)          
            case 'fail'
                msgClassString = 'FAIL';
            otherwise 
                msgClassString = '';
        end %switch
    end 

end %private methods


end