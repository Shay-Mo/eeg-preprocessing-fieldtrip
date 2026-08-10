function trials = sct_defineTrials(interpolated)
%SCT_DEFINETRIALS Defines trial segments for the Simon Conflict Task
%
%   trials = SCT_DEFINETRIALS(interpolated) extracts trials in the training
%   and testing phases of the Simon Conflict Task using the 'sct_trialfun' 
%   function. It defines trial windows relative to the stimulus onset and
%   segments the EEG data accordingly.
% 
%   Input:
%       interpolated  - FieldTrip data structure
%
%   Output:
%       trials - FieldTrip data structure
%
%   Example:
%       trials = sct_defineTrials(interpolated);
%
%   See also SCT_TRIALFUN, FT_DEFINETRIAL, FT_REDEFINETRIAL

    %% Training phase
    fprintf('\n\t--> Defining training-phase trials...\n');
    cfg = [];
    cfg.dataset = interpolated.cfg.dataset;
    cfg.trialdef.prestim = 0.5;
    cfg.trialdef.poststim = 2.17;
    cfg.trialdef.phase   = 'train';
    cfg.trialfun = 'sct_trialfun';

    cfg = ft_definetrial(cfg);
    trainTrials = ft_redefinetrial(cfg, interpolated);

    %% Testing phase 
    fprintf('\t--> Defining testing-phase trials...\n');
    cfg = [];
    cfg.dataset = interpolated.cfg.dataset;
    cfg.trialdef.prestim = 0.5;
    cfg.trialdef.poststim = 1.0;
    cfg.trialdef.phase   = 'test';
    cfg.trialfun = 'sct_trialfun';
    
    cfg = ft_definetrial(cfg);
    testTrials = ft_redefinetrial(cfg, interpolated);

    %% Merge trials 
    fprintf('\t--> Merging training and testing trials...\n');
    cfg = [];
    trials = ft_appenddata(cfg, trainTrials, testTrials);

end