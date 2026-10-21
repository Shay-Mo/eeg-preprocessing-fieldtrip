function erp = sct_computeERP(binnedTrials)
%SCT_COMPUTEERP Computes baseline-corrected ERPs for each trial bin
% 
%   erp = sct_computeERP(binnedTrials) applies baseline correction to the 
%   binned trial data, then computes the trial-averaged event-related 
%   potential (ERP) separately for each bin defined by sct_defineBins 
%   (trialinfo column 5). Unbinned trials (bin code 0) are excluded. 
%   The result is returned as a struct so downstream analyses 
%   (e.g. PCA/LFADS) don't have to assume bin order or separately track 
%   channel labels and the time axis.
%
%   Input:
%       binnedTrials - FieldTrip data struct with a trialinfo matrix
%                      whose 5th column holds the bin code for each trial
%                      (see sct_defineBins)
%
%   Output:
%       erp - struct with fields:
%           .avg     - channels x time x bins array of trial-averaged,
%                      baseline-corrected ERPs
%           .dimord  - 'chan_time_bin', describing the dimensions of .avg
%           .label   - channel labels, matching the channel dimension of .avg
%           .time    - time vector (s), matching the time dimension of .avg
%           .bins    - bin codes, in the order stored along the 3rd
%                      dimension of .avg (see sct_defineBins for the
%                      congruency x feedback code scheme)
%
%   Example:
%       erp = sct_computeERP(binnedTrials);
%
%   See also SCT_DEFINEBINS, FT_PREPROCESSING, FT_TIMELOCKANALYSIS, SCT_SAVERESULT

    % Bin code column in trialinfo (see sct_defineBins)
    colBin = 5;

    % Baseline window (s), relative to cue onset
    baselineWindow = [-0.5 0];

    %% Baseline correction
    cfg = [];
    cfg.demean = 'yes';
    cfg.baselinewindow = baselineWindow;
    baseline = ft_preprocessing(cfg, binnedTrials);

    % Get list of bins, excluding unbinned trials (code 0)
    bins = unique(baseline.trialinfo(:, colBin));
    bins(bins == 0) = [];

    %% Compute ERP per bin
    fprintf('\n\t--> Computing ERPs for %d bin(s)...\n', length(bins));

    nChan = length(baseline.label);
    nTime = length(baseline.time{1});
    nBins = length(bins);
    avg = zeros(nChan, nTime, nBins);   % avg: channels x time x bins

    for binIdx = 1:nBins
        cfg = [];
        cfg.trials = find(baseline.trialinfo(:, colBin) == bins(binIdx));
        binERP = ft_timelockanalysis(cfg, baseline);
        avg(:, :, binIdx) = binERP.avg;
    end

    %% Bundle into a self-describing output struct
    erp.avg = avg;
    erp.dimord = 'chan_time_bin';
    erp.label = baseline.label;
    erp.time = baseline.time{1};
    erp.bins = bins;


end
