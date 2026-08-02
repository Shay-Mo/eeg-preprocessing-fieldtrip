function eegData = sct_loadRawData(filename)
%SCT_LOADRAWDATA loads raw EEG data for the Simon Conflict Task
%
%   eegData = SCT_LOADRAWDATA(filename) loads raw EEG data using
%   FieldTrip from the specified file, excluding EOG channels.
%
%   Input:
%       filename - (string) full path to the raw EEG dataset file
%
%   Output:
%       eegData  - FieldTrip raw data structure, EOG channel excluded
%
%   Example:
%       eegData = sct_loadRawData('/data/sub-001_task-Simon_eeg.set');


    % Validate the input
    if ~isfile(filename)
        error('sct_loadRawData:fileNotFound', ...
            'File not found: %s', filename);
    end

    
    cfg = [];
    cfg.dataset = filename;
    cfg.channel = {'all', '-EOG'};  % Exclude EOG channels
    eegData = ft_preprocessing(cfg);

end