function [trl, event] = sct_trialfun(cfg)
%SCT_TRIALFUN FieldTrip trial-definition function for the Simon Conflict Task
%
%   [trl, event] = SCT_TRIALFUN(cfg) is called internally by
%   FT_DEFINETRIAL (via cfg.trialfun = 'sct_trialfun') to locate trial
%   boundaries around stimulus onset events. 
%   For each stimulus event matching the requested phase (Training or 
%   Testing phase), it defines a trial window from prestim seconds before
%   onset to poststim seconds after onset, and pairs it with the response 
%   and feedback event codes that follow it as the next two events in 
%   the event list:
%       - respCode is taken positionally as the very next event after
%         the stimulus onset
%       - fbCode is taken positionally as the event two after the
%         stimulus onset (the second event following the response).
%         This represents the on-screen feedback message shown to the
%         participant — either reward/punishment feedback ('FB') or an
%         error/no-response message ('STATUS').
%
%   Input:
%       cfg - FieldTrip configuration struct (built by ft_definetrial),
%             with the following fields expected to be set beforehand:
%                 cfg.dataset          - (string) path to the dataset file
%                 cfg.trialdef.phase    - (string) 'train' or 'test'
%                 cfg.trialdef.prestim  - (numeric) seconds before stimulus onset
%                 cfg.trialdef.poststim - (numeric) seconds after stimulus onset
%
%   Output:
%       trl   - FieldTrip trial matrix, one row per trial:
%                   [begsample endsample offset trialinfo]
%               where trialinfo = [trialType stimCode respCode fbCode]
%                   trialType - 1 for 'train', 2 for 'test'
%                   stimCode  - numeric code extracted from the stimulus event
%                   respCode  - numeric code of the response event following
%                               the stimulus
%                   fbCode    - numeric code of the feedback event following 
%                               the response
%       event - full event structure as read by ft_read_event, with
%               .sample and .offset added and .value converted to
%               numeric where possible
%   Example:
%       cfg = [];
%       cfg.dataset = 'sub-001_task-SimonConflict_eeg.set';
%       cfg.trialdef.phase = 'train';
%       cfg.trialdef.prestim = 0.5;
%       cfg.trialdef.poststim = 2.17;
%       cfg.trialfun = 'sct_trialfun';
%       cfg = ft_definetrial(cfg);
%
%   See also SCT_DEFINETRIALS, FT_DEFINETRIAL, FT_REDEFINETRIAL

    %% Load header and events
    fprintf('\n\t--> Reading events from %s...\n', cfg.dataset);
    event = ft_read_event(cfg.dataset);
    hdr   = ft_read_header(cfg.dataset);

    Fs       = hdr.Fs;
    prestim  = cfg.trialdef.prestim;
    poststim = cfg.trialdef.poststim;
    phase    = cfg.trialdef.phase;
    
    %% Trial type coding
    switch phase
        case 'train'
            trialType = 1;
            stimTag   = 'Trn Stim';
        case 'test'
            trialType = 2;
            stimTag   = 'Test Stim';
    end

    %% Convert timestamps and values
    for i = 1:numel(event)
        event(i).sample = round(event(i).timestamp * Fs);
        event(i).offset = -round(prestim * Fs);

        % Extract numeric part of the value
        tokens = regexp(event(i).value, '\d+', 'match');
        if ~isempty(tokens)
            event(i).value = str2double(tokens{1});
        end
    end

    %% Define trials
    fprintf('\t--> Defining %s trials...\n', phase);
    trl = [];

    for i = 1:numel(event)

        if contains(event(i).type, stimTag)

            begsample = event(i).sample - prestim  * Fs;
            endsample = event(i).sample + poststim * Fs - 1;
            offset    = event(i).offset;

            stimCode = event(i).value;

            respCode = NaN;
            fbCode   = NaN;

            % Response is the next event of the stimulus event
            if i+1 <= numel(event)
                respCode = event(i+1).value;
            end

            % Feedback is the next two events after the stimulus event
            % There is no feedback in the testing phase
            if trialType == 1 && i+2 <= numel(event)
                fbCode = event(i+2).value;
            end

            trialinfo = [trialType stimCode respCode fbCode];

            trl(end+1,:) = [begsample endsample offset trialinfo];
        end
    end
end