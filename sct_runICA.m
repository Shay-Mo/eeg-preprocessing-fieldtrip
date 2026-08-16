function components = sct_runICA(cleanTrials, subjectDIR)
%SCT_RUNICA Performs ICA decomposition on EEG data
%
%   components = SCT_RUNICA(cleanTrials, subjectDIR) concatenates the
%   cleaned trials back into continuous data and runs Infomax ICA
%   (via FieldTrip's 'runica' method), excluding interpolated channels
%   (e.g. CPz) from the decomposition. Component labels (ic001, ic002,
%   ...) are added, and the resulting components are saved to a .mat
%   file.
%
%   Input:
%       cleanTrials - FieldTrip data structure, as returned by
%                    sct_autoInspectTrials
%       subjectDIR  - (string) full path to the subject's results
%                    directory, where the ICA components are saved
%
%   Output:
%       components - FieldTrip component data structure, with channel
%                    labels replaced by component labels (ic001, ic002,
%                    ...)
%
%   Example:
%       components = sct_runICA(cleanTrials, subjectDIR);
%
%   See also SCT_AUTOINSPECTTRIALS, SCT_INSPECTICA, SCT_REJECTARTIFACTS

    %% Concatenate the segmented data back together 
    fprintf('\n\t--> Concatenating trials into continuous data...\n');

    % NOTE: keep continuous = 'yes'. ft_componentanalysis internally
    % concatenates all trials for training anyway, including any overlapping
    % samples between adjacent trials (our epoch windows can overlap). 
    % Feeding overlapping samples straight into ft_componentanalysis would 
    % duplicate those samples in the training data and bias the ICA 
    % decomposition. This step instead concatenates trials back onto their 
    % original continuous timeline first, so overlapping trials are merged
    % into fewer, larger trials with no duplicated samples (trial count may
    % drop as a result - that's expected, not data loss).
    cfg = [];
    cfg.continuous = 'yes';
    cntData = ft_redefinetrial(cfg, cleanTrials);
    
    % Exclude interpolated channels from ICA (e.g. CPz, which is a linear
    % combination of its neighbours and would otherwise introduce artificial
    % rank deficiency)
    excludedChannels = {'CPz'};

    rng(42);  % fixed seed so ICA decomposition is reproducible across re-runs
    
    %% Perform the ICA decomposition
    fprintf('\t--> Running ICA decomposition...\n');
    cfg = [];
    cfg.method = 'runica';
    cfg.channel = setdiff(cntData.label, excludedChannels);
    try
        components = ft_componentanalysis(cfg, cntData);
    catch ME
        error('sct_runICA:runicaFailed', ...
            'ICA decomposition (runica) failed — check it is on the MATLAB path.\nOriginal error: %s', ...
            ME.message);
    end
    
    % Add component labels (e.g., ic001, ic002, ...)
    nComp = size(components.trial{1}, 1);
    components.label = arrayfun(@(x) sprintf('ic%03d', x), 1:nComp, ...
        'UniformOutput', false)';

    %% Save the components as a .mat 
    [~, subjectID] = fileparts(subjectDIR);
    filename = fullfile(subjectDIR, [subjectID '_components.mat']);
    save(filename, 'components');
    fprintf('\t--> Saved ICA components to %s\n', filename);

end