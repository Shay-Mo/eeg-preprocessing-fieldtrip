function cleanTrials = sct_autoInspectTrials(trials, subjectDIR)
%SCT_AUTOINSPECTTRIALS Automatically detects and rejects bad trials
%
%   cleanTrials = SCT_AUTOINSPECTTRIALS(trials, subjectDIR) flags trials
%   as bad based on per-trial peak-to-peak amplitude and standard
%   deviation (aggregated across channels via the median), then rejects
%   the flagged trials using FieldTrip. A trial is flagged as bad if its
%   median peak-to-peak amplitude exceeds a fixed absolute threshold, or
%   if either its median peak-to-peak amplitude or standard deviation is
%   a z-score outlier relative to the other trials from the same
%   subject. The list of rejected trial indices is saved to a text file,
%   and the cleaned data is saved to a .mat file.
%
%   Input:
%       trials     - FieldTrip data structure (raw, filtered, in
%                    microvolts — i.e. pre-CSD), as returned by
%                    sct_defineTrials
%       subjectDIR - (string) full path to the subject's results
%                    directory, where the bad-trial log and cleaned
%                    data are saved
%
%   Output:
%       cleanTrials - FieldTrip data structure with bad trials removed;
%                    includes an added field, removedTrials, listing the
%                    indices (into the original trials structure) of the
%                    trials that were rejected
%
%   Example:
%       cleanTrials = sct_autoInspectTrials(trials, subjectDIR);
%
%   See also SCT_DEFINETRIALS, SCT_PIPELINE, FT_REJECTARTIFACT

    %% Rejection thresholds
    % peak2peakLimit chosen empirically for this dataset: raw filtered
    % data is still in microvolts at this stage (pre-CSD), so this is an
    % absolute microvolt cutoff, not a z-score.
    peak2peakLimit = 100;  % uV, absolute peak-to-peak amplitude cutoff
    zScoreLimit    = 3;    % z-score cutoff for both peak-to-peak and std dev

    %% Detect bad trials
    fprintf('\n\t--> Detecting bad trials...\n');

    nTrials   = numel(trials.trial);
    nChannels = numel(trials.label);

    peak2peak = zeros(nTrials, nChannels);
    stdDev    = zeros(nTrials, nChannels);

    % Loop over trials
    for t = 1:nTrials
        data = trials.trial{t};  % [nChannels x nSamples]
        peak2peak(t,:) = max(data,[],2) - min(data,[],2);
        stdDev(t,:)    = std(data,0,2);
    end

    % Aggregate across channels (median more robust than mean)
    peak2peak = median(peak2peak,2);
    stdDev    = median(stdDev,2);

    % Z-scores (computed across trials, within this subject)
    zPeak2Peak = zscore(peak2peak);
    zStdDev    = zscore(stdDev);

    % Flag bad trials
    badTrials = (zStdDev > zScoreLimit) | (zPeak2Peak > zScoreLimit) | ...
        (peak2peak > peak2peakLimit);
    badIdx = find(badTrials);

    fprintf('\t--> Detected %d bad trials out of %d.\n', numel(badIdx), nTrials);
    fprintf('\t--> Bad trials: %s\n', num2str(badIdx'));

    %% Reject bad trials
    fprintf('\t--> Rejecting bad trials...\n');

    % Convert bad trials to FieldTrip artifact format
    artfctdef = zeros(numel(badIdx), 2);
    for i = 1:numel(badIdx)
        thisTrial = badIdx(i);
        artfctdef(i,:) = [trials.sampleinfo(thisTrial,1), trials.sampleinfo(thisTrial,2)];
    end

    % Reject identified bad trials
    cfg = [];
    cfg.artfctdef.reject = 'complete';  % reject entire trial
    cfg.artfctdef.badtrials.artifact = artfctdef;
    cleanTrials = ft_rejectartifact(cfg, trials);

    % Store removed trial indices
    cleanTrials.removedTrials = badIdx;

    %% Save outputs
    [~, subjectID] = fileparts(subjectDIR);

    % Save removed trial indices in a log file
    filename = fullfile(subjectDIR, [subjectID '_badTrials.txt']);
    fid = fopen(filename, 'w');
    fprintf(fid, 'Bad trial indices:\n');
    fprintf(fid, '%d\n', badIdx);
    fclose(fid);
    fprintf('\t--> Saved bad trial list to %s\n', filename);

    % Save the cleaned signal as a .mat
    filename = fullfile(subjectDIR, [subjectID '_cleanTrials.mat']);
    save(filename, 'cleanTrials');
    fprintf('\t--> Saved cleaned trials to %s\n', filename);

end
