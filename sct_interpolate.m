function interpolated = sct_interpolate(preprocessed, layoutFilename, flag)
%SCT_INTERPOLATE Recreates the CPz reference channel via spatial interpolation
%
%   interpolated = SCT_INTERPOLATE(preprocessed, layoutFilename, flag)
%   recreates (interpolates) the CPz channel — the online reference
%   channel during recording, which therefore contains no signal — using
%   spatial interpolation from neighbouring electrodes.
%
%   This function is called twice in the pipeline (see sct_pipeline):
%     1. Pre-ICA: CPz is recreated so a complete 64-channel montage is
%        available for trial definition and inspection. CPz itself is
%        then excluded from the ICA decomposition (sct_runICA), since an
%        interpolated channel is a linear combination of other channels
%        and would violate ICA's full-rank requirement. If CPz's
%        neighbouring channels contain artifacts at this stage, the
%        interpolated CPz value inherits that contamination.
%     2. Post-ICA: after artifactual components are removed from the
%        neighbouring channels (sct_rejectArtifacts), CPz is recreated a
%        second time from those now-cleaned neighbours, so the final CPz
%        signal doesn't carry forward pre-ICA artifact contamination.
%
%   Input:
%       preprocessed   - FieldTrip data structure
%       layoutFilename - (string) full path to the electrode positions file
%       flag           - (string) processing stage at which this function
%                        is called; either 'pre-ICA' or 'post-ICA'. When
%                        'pre-ICA', the original dataset name is
%                        reattached to the output (lost during
%                        interpolation); when 'post-ICA', it is not.
%
%   Output:
%       interpolated - FieldTrip data structure with CPz recreated
%
%   Example:
%       interpolated = sct_interpolate(preprocessed, ...
%           '/data/sub-001_electrodes.tsv', 'pre-ICA');
%
%   See also SCT_PIPELINE, SCT_CREATELAYOUT, SCT_COMPUTENEIGHBOURS

    %% Validate flag
    if ~(strcmp(flag, 'pre-ICA') || strcmp(flag, 'post-ICA'))
        error('sct_interpolate:invalidFlag', ...
            'flag must be either ''pre-ICA'' or ''post-ICA'' (got ''%s'').', flag);
    end

    %% Load electrode positions and compute neighbours
    fprintf('\n\t--> Loading electrode layout and computing neighbours...\n');
    
    [elec, layout] = sct_createLayout(layoutFilename);
    neighbours = sct_computeNeighbours(elec);

    %% Interpolate CPz
    channels = {'CPz'};

    cfg = [];
    cfg.elec = elec;
    cfg.layout = layout;
    cfg.method = 'spline';
    cfg.badchannel = channels;
    cfg.neighbours = neighbours;
    interpolated = ft_channelrepair(cfg, preprocessed);

    % Preserve dataset name (only needed before ICA re-labels the data)
    if strcmp(flag, 'pre-ICA')
        interpolated.cfg.dataset = preprocessed.cfg.dataset;
    end

end