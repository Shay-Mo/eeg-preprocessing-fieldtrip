function components = sct_autoInspectICA(components, layoutFilename)
%SCT_AUTOINSPECTICA Automatically flags likely-artifactual ICA components
%
%   components = SCT_AUTOINSPECTICA(components, layoutFilename) classifies
%   ICA components into candidate artifact types (blinks, lateral eye
%   movements, muscle activity, and generic discontinuities) using a mix
%   of spatial topography features and temporal (power spectrum,
%   kurtosis, variance) features, and stores the results in
%   components.hdr. Called internally by sct_inspectICA to pre-populate
%   suggested artifact labels for manual review; it does not reject or
%   remove any components itself.
%
%   IMPORTANT — origin of this code: the blink/lateral-eye detection and
%   muscle-band ratio are simple custom heuristics, but the
%   horizontal/vertical-eye, blink, and discontinuity classification
%   (GDSF/SED/SAD features and the EM adaptive-threshold method) are
%   adapted from the ADJUST toolbox (Mognon, Jovicich, Bruzzone &
%   Buiatti, 2011, Psychophysiology, "ADJUST: An automatic EEG artifact
%   detector based on the joint use of spatial and temporal features").
%   This function depends on ADJUST's helper functions — compute_GD_feat,
%   computeSED_NOnorm, computeSAD, trim_and_mean, trim_and_max, EM, and
%   kurt — which live in the separate 'auto-ica-checking' toolbox folder
%   (added to the path in sct_pipeline.m), not in this repository. As
%   this reuses a published method, it's worth citing the ADJUST paper
%   above in any write-up that uses this function.
%
%   Input:
%       components     - FieldTrip component data structure, as returned
%                        by sct_runICA
%       layoutFilename - (string) full path to the electrode positions
%                        (BIDS electrodes.tsv) file
%
%   Output:
%       components - same structure as input, with added fields:
%           components.hdr.blinks    - indices of components flagged as blinks
%           components.hdr.eyes      - indices flagged as eye movements
%           components.hdr.muscle    - indices flagged as muscle activity
%           components.hdr.disc      - indices flagged as generic discontinuities
%           components.hdr.suggested - indices suggested for rejection
%                                      (capped at 15% of nICs; see note above)
%
%   Example:
%       components = sct_autoInspectICA(components, layoutFilename);
%
%   See also SCT_INSPECTICA, SCT_RUNICA, SCT_CREATELAYOUT

    %% Parameters
    Fs = components.fsample;
    thresBlink   = 2.5;  % z-score threshold for blink topography
    thresLateral = 4;    % z-score threshold for lateral eye movement asymmetry
    thresMuscle  = 0.5;  % fraction of power in muscle band to flag as muscle artifact

    freqRange = [0 150];      % Hz, range over which PSD is evaluated
    muscleFreqRange = [31 100];  % Hz, "muscle" band for the muscle-activity ratio

    % Frontal/lateral channels used for blink and eye-movement detection
    fp1 = find(strcmp(components.topolabel, 'Fp1'));
    fp2 = find(strcmp(components.topolabel, 'Fp2'));
    f7  = find(strcmp(components.topolabel, 'F7'));
    f8  = find(strcmp(components.topolabel, 'F8'));

    nICs    = size(components.topo, 2);
    nTrials = numel(components.trial);

    %% Power spectral density (computed once, trial-independent)
    psd = [];
    for ic = 1:nICs
        [p, f] = pwelch(components.trial{1}(ic,:), Fs, Fs/2, Fs, Fs);
        freqIdx = f >= freqRange(1) & f <= freqRange(2);
        psd(ic,:) = p(freqIdx);
    end
    f = f(freqIdx);

    %% Topography z-scores
    zTopo = zscore(components.topo, 0, 1);

    %% Blink detection
    blinkMean = mean(zTopo([fp1, fp2],:), 1);
    blinks = find(abs(blinkMean) > thresBlink);

    %% Lateral eye movements
    lateral = find(abs(zTopo(f7,:) - zTopo(f8,:)) > thresLateral);

    %% Muscle activity
    muscleActivity = zeros(1, nICs);
    muscleIdx = f >= muscleFreqRange(1) & f <= muscleFreqRange(2);
    for ic = 1:nICs
        muscleActivity(ic) = sum(psd(ic, muscleIdx)) / sum(psd(ic,:));
    end
    muscle = find(muscleActivity > thresMuscle);

    %% Topography normalization
    % Each component's topography is scaled to unit norm, with the
    % corresponding IC activation rescaled to compensate, so that the
    % spatial (GDSF/SED/SAD) and temporal (kurtosis/variance) features
    % below are comparable across components regardless of ICA's
    % arbitrary component scaling.
    topografie = components.topo';

    for ic = 1:nICs
        scale = norm(topografie(ic,:));
        topografie(ic,:) = topografie(ic,:) / scale;

        for t = 1:nTrials
            components.trial{t}(ic,:) = scale * components.trial{t}(ic,:);
        end
    end

    %% Load channel positions
    [elec, ~] = sct_createLayout(layoutFilename);

    nChans = numel(elec.label);
    chanlocs = struct([]);

    for i = 1:nChans
        chanlocs(i).labels = elec.label{i};
        x = elec.chanpos(i,1);
        y = elec.chanpos(i,2);
        z = elec.chanpos(i,3);

        chanlocs(i).X = x;
        chanlocs(i).Y = y;
        chanlocs(i).Z = z;
        chanlocs(i).theta  = atan2d(y, x);
        chanlocs(i).radius = sqrt(x^2 + y^2);
    end

    [found, reorderIdx] = ismember(components.topolabel, {chanlocs.labels});
    if ~all(found)
        error('sct_autoInspectICA:channelNotFound', ...
            'Some channels in components.topolabel were not found in the layout.');
    end
    chanlocs = chanlocs(reorderIdx);

    %% Spatial feature extraction (ADJUST features — see header)
    GDSF = compute_GD_feat(topografie, chanlocs, nICs);
    [SED, medieLeft, medieRight] = computeSED_NOnorm(topografie, chanlocs, nICs);
    [SAD, varFront, varBack, ~, ~] = computeSAD(topografie, chanlocs, nICs);
    diffVar = varFront - varBack;

    %% Temporal metrics (kurtosis and variance per trial, per component)
    K    = zeros(nTrials, nICs);
    Vmax = zeros(nTrials, nICs);

    for t = 1:nTrials
        data = components.trial{t};  % [nICs x nSamples_t]
        for ic = 1:nICs
            Vmax(t,ic) = var(data(ic,:));
            K(t,ic)    = kurt(data(ic,:));
        end
    end

    meanK   = zeros(1, nICs);
    maxVar  = zeros(1, nICs);
    meanVar = zeros(1, nICs);

    for ic = 1:nICs
        if nTrials > 100
            meanK(ic)   = trim_and_mean(K(:,ic));
            maxVar(ic)  = trim_and_max(Vmax(:,ic)');
            meanVar(ic) = trim_and_mean(Vmax(:,ic)');
        else
            meanK(ic)   = mean(K(:,ic));
            maxVar(ic)  = max(Vmax(:,ic));
            meanVar(ic) = mean(Vmax(:,ic));
        end
    end

    maxVarRatio = maxVar ./ meanVar;  % "MEV": max epoch variance relative to mean

    %% Adaptive thresholds (ADJUST's EM method — see header)
    thresK    = EM(meanK);
    thresSED  = EM(SED);
    thresSAD  = EM(SAD);
    thresGDSF = EM(GDSF);
    thresV    = EM(maxVarRatio);

    %% Classification
    horiz = intersect(intersect(find(SED >= thresSED), find(medieLeft .* medieRight < 0)), ...
        find(maxVarRatio >= thresV));

    vert = intersect(intersect(find(SAD >= thresSAD), find(medieLeft .* medieRight > 0)), ...
        intersect(find(diffVar > 0), find(maxVarRatio >= thresV)));

    blink = intersect(intersect(find(SAD >= thresSAD), find(medieLeft .* medieRight > 0)), ...
        intersect(find(meanK >= thresK), find(diffVar > 0)));

    disc = intersect(find(GDSF >= thresGDSF), find(maxVarRatio >= thresV));

    art = unique([blink, horiz, vert, disc]);
    icLimit = round(nICs * 0.15);

    if numel(art) >= icLimit
        % Rank flagged components by severity, so truncation keeps 
        % the most-likely artifacts. Severity is (1) how many of the four 
        % criteria a component triggered, and, as a tiebreaker, (2) how
        % far above each triggered criterion's threshold it scored 
        % (relative excess, summed across triggered criteria).
        nCriteria = zeros(size(art));
        severity  = zeros(size(art));

        for k = 1:numel(art)
            ic = art(k);
            if ismember(ic, blink)
                nCriteria(k) = nCriteria(k) + 1;
                severity(k)  = severity(k) + (SAD(ic)/thresSAD - 1) + (meanK(ic)/thresK - 1);
            end
            if ismember(ic, horiz)
                nCriteria(k) = nCriteria(k) + 1;
                severity(k)  = severity(k) + (SED(ic)/thresSED - 1);
            end
            if ismember(ic, vert)
                nCriteria(k) = nCriteria(k) + 1;
                severity(k)  = severity(k) + (SAD(ic)/thresSAD - 1);
            end
            if ismember(ic, disc)
                nCriteria(k) = nCriteria(k) + 1;
                severity(k)  = severity(k) + (GDSF(ic)/thresGDSF - 1);
            end
        end

        [~, rankOrder] = sortrows([-nCriteria(:), -severity(:)]);
        suggComps = art(rankOrder(1:icLimit));
    else
        suggComps = art;
    end

    %% Output
    components.hdr.blinks    = unique([blinks, blink]);
    components.hdr.eyes      = unique([lateral, horiz, vert]);
    components.hdr.muscle    = muscle;
    components.hdr.disc      = disc;
    components.hdr.suggested = suggComps;

    %% Display summary
    allArt = unique([blink, blinks, lateral, horiz, vert, muscle, disc]);

    fprintf('\n\t--> Automated ICA artifact detection:\n');
    fprintf('\t--> All flagged components: %s\n', num2str(allArt));
    fprintf('\t--> Suggested (top 15%% of nICs by severity): %s\n', num2str(suggComps));

end
