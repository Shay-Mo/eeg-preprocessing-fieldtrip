function components = sct_inspectICA(components, layoutFilename)
%SCT_INSPECTICA Interactive GUI for manually reviewing and marking ICA components
%
%   components = SCT_INSPECTICA(components, layoutFilename) first runs
%   sct_autoInspectICA to get suggested artifact labels (for display
%   only), then shows each ICA component one at a time — topography,
%   time series, continuous data (raster plot), and power spectrum — so 
%   bad components can be marked manually. Use the Previous/Next buttons 
%   (or the "Go to component" box) to move between components, the slider 
%   below the time-series plot to step between trials within a component, 
%   "Mark as Artifact" to toggle a component, and "Done" (or close the 
%   window) to finish.
%
%   Only manually marked components (components.artComps) are kept in
%   the returned structure; the auto-detected labels from sct_autoInspectICA
%   are shown on-screen as a hint during review but are not saved into 
%   the output.
%
%   Input:
%       components     - FieldTrip component data structure, as returned
%                        by sct_runICA
%       layoutFilename - (string) full path to the electrode positions
%                        (BIDS electrodes.tsv) file
%
%   Output:
%       components - same structure as input, with an added field:
%           components.artComps - vector of component indices manually
%                                 marked as artifacts
%
%   Example:
%       components = sct_inspectICA(components, layoutFilename);
%
%   See also SCT_AUTOINSPECTICA, SCT_REJECTARTIFACTS, SCT_RUNICA

    %% Run automatic inspection (for display only — does not affect components)
    auto = sct_autoInspectICA(components, layoutFilename);

    % Extract detected sets of artifacts
    detectedArtifacts = struct();
    detectedArtifacts.blinks  = auto.hdr.blinks;
    detectedArtifacts.eyes    = auto.hdr.eyes;
    detectedArtifacts.muscle  = auto.hdr.muscle;
    detectedArtifacts.disc    = auto.hdr.disc;

    %% Prepare GUI 
    [elec, layout] = sct_createLayout(layoutFilename);
    numComps = length(components.label);
    currentComp = 1;
    components.artComps = [];

    % Create the Main figure 
    hFig = figure('Name', 'ICA Component Inspector', ...
                  'NumberTitle', 'off', ...
                  'Color', 'w', ...
                  'Position', [100 100 1100 700], ...
                  'CloseRequestFcn', @onClose);

    % Create a panel for plots 
    hPanel = uipanel('Parent', hFig, ...
                     'Units', 'normalized', ...
                     'Position', [0.05 0.10 0.9 0.84], ...
                     'BackgroundColor', 'w');

    % Create Buttons (outside the panel) 
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Previous', ...
        'Units', 'normalized', 'Position', [0.56 0.02 0.09 0.04], ...
        'FontSize', 9, 'Callback', @(~,~) changeComponent(-1));

    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Next', ...
        'Units', 'normalized', 'Position', [0.66 0.02 0.09 0.04], ...
        'FontSize', 9, 'Callback', @(~,~) changeComponent(1));

    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Mark as Artifact', ...
        'Units', 'normalized', 'Position', [0.76 0.02 0.09 0.04], ...
        'FontSize', 9, 'BackgroundColor', [1 0.6 0.6], ...
        'Callback', @(~,~) markArtifact());

    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Done', ...
        'Units', 'normalized', 'Position', [0.86 0.02 0.09 0.04], ...
        'FontSize', 9, 'BackgroundColor', [0.6 1 0.6], ...
        'Callback', @(~,~) uiresume(hFig));

    % Create Jump-to-component control 
    hJumpPanel = uipanel('Parent', hFig, 'Title', sprintf('Jump to component (1-%d):', numComps), ...
        'FontSize', 9, 'FontWeight', 'bold', 'BorderType', 'none', ...
        'Units', 'normalized', 'Position', [0.05 0.02 0.20 0.065], ...
        'BackgroundColor', 'w');

    hJump = uicontrol('Parent', hJumpPanel, 'Style', 'edit', 'String', num2str(currentComp), ...
        'Units', 'normalized', 'Position', [0.05 0.10 0.40 0.75], ...
        'FontSize', 11, 'Callback', @(src,~) jumpToComponent(src));

    uicontrol('Parent', hJumpPanel, 'Style', 'pushbutton', 'String', 'Go', ...
        'Units', 'normalized', 'Position', [0.50 0.10 0.30 0.75], ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'Callback', @(~,~) jumpToComponent(hJump));

    % Store handles 
    handles.comps = components;
    handles.layout = layout;
    handles.elec = elec;
    handles.numComps = numComps;
    handles.currentComp = currentComp;
    handles.currentTrial = 1;
    handles.detected = detectedArtifacts;
    handles.hPanel = hPanel;
    handles.hJump = hJump;

    % Create persistent text boxes for messages 
    handles.artifactText = annotation(hFig, 'textbox', [0.05 0.93 0.7 0.05], ...
                                      'String','', 'EdgeColor','none', ...
                                      'FontSize',11,'FontWeight','bold','Color',[0.7 0 0]);
    handles.markedText = annotation(hFig, 'textbox', [0.80 0.93 0.18 0.05], ...
                                    'String','', 'EdgeColor','none', ...
                                    'FontSize',11,'FontWeight','bold','Color',[1 0 0]);

    guidata(hFig, handles);

    %% Initial plot 
    updateComponent();
    uiwait(hFig);

    %% Return updated components 
    if isvalid(hFig)
        handles = guidata(hFig);
        components = handles.comps;
        delete(hFig);
    end

    %% Nested Functions 
    function changeComponent(step)
        handles = guidata(hFig);
        handles.currentComp = max(1, min(handles.numComps, handles.currentComp + step));
        handles.currentTrial = 1;  % reset to first trial when switching components
        guidata(hFig, handles);
        updateComponent();
    end

    function jumpToComponent(src)
        handles = guidata(hFig);
        target = round(str2double(get(src, 'String')));
        if isnan(target) || target < 1 || target > handles.numComps
            % Invalid entry — revert the box to the current component
            set(src, 'String', num2str(handles.currentComp));
            return;
        end
        handles.currentComp = target;
        handles.currentTrial = 1;  % reset to first trial when switching components
        guidata(hFig, handles);
        updateComponent();
    end

    function markArtifact()
        handles = guidata(hFig);
        c = handles.currentComp;
        if ~ismember(c, handles.comps.artComps)
            handles.comps.artComps = [handles.comps.artComps c];
        else
            handles.comps.artComps(handles.comps.artComps == c) = [];
        end
        guidata(hFig, handles);
        updateComponent();
    end

    function updateComponent()
        handles = guidata(hFig);
        c = handles.currentComp;

        % Clear only the panel
        delete(allchild(handles.hPanel));

        % The trial label and slider (below the time series plot) live 
        % directly on the figure, not inside hPanel, so they aren't cleared
        % by the line above. Explicitly delete any leftover ones from the 
        % previous redraw, or they'd silently accumulate with each redraw.
        if isfield(handles,'trialLabel') && isvalid(handles.trialLabel)
            delete(handles.trialLabel);
        end
        if isfield(handles,'trialSlider') && isvalid(handles.trialSlider)
            delete(handles.trialSlider);
        end

        % Create axes inside the panel — custom positions (not a uniform 2x2 grid)
        % Topography
        ax1 = axes('Parent',handles.hPanel, 'Position',[0.04 0.55 0.22 0.40]);
        cfg = [];
        cfg.component = c;
        cfg.layout = handles.layout;
        cfg.elec = handles.elec;
        cfg.comment = 'no';
        cfg.figure = 'gca';
        ft_topoplotIC(cfg, handles.comps);
        title(ax1, ['Component ' num2str(c)]);

        % Time series (display one trial at a time) 
        ax2 = axes('Parent',handles.hPanel, 'Position',[0.36 0.62 0.61 0.33]);
        nTrials = numel(handles.comps.trial);
        tr = handles.currentTrial;
        trialData = handles.comps.trial{tr}(c,:);

        % components.time carries absolute time since the start of the
        % recording (not reset per trial), likely because of how ICA's
        % continuous-data step in sct_runICA reshapes it — so it can't
        % be used directly as an onset-relative axis. Reconstruct it
        % instead from what's guaranteed constant: the sampling rate and
        % the prestim (0.5 s) used for every trial in sct_defineTrials.
        prestimSec = 0.5;  % matches cfg.trialdef.prestim in sct_defineTrials
        nSamples = numel(trialData);
        fs = handles.comps.fsample;
        trialTimeMs = (((0:nSamples-1) / fs) - prestimSec) * 1000;
        xRangeMs = [-prestimSec, (nSamples-1)/fs - prestimSec] * 1000;

        plot(ax2, trialTimeMs, trialData, 'b');
        xlabel(ax2, 'Time from stimulus onset (ms)'); ylabel(ax2, 'Amplitude (\muV)');
        title(ax2, sprintf('IC%d Activity', c));
        grid(ax2,'on');
        xlim(ax2, xRangeMs);
        yRange = max(abs(trialData))*1.1;
        if yRange == 0, yRange = 1; end
        ylim(ax2, [-yRange yRange]);
        hold(ax2, 'on');
        xline(ax2, 0, '--k');  % mark stimulus onset
        hold(ax2, 'off');

        % Trial label and trial-navigation slider, placed below the axes.
        axPos = get(ax2,'Position');
        labelHeight = 0.03; sliderHeight = 0.03; 
       
        labelPos = [axPos(1), axPos(2)-0.09, axPos(3)-0.05, labelHeight];
        trialLabel = uicontrol('Parent',hFig, 'Style','text', ...
            'String', sprintf('Trial %d of %d', tr, nTrials), ...
            'Units','normalized','Position',labelPos, ...
            'FontSize',9,'FontWeight','bold','BackgroundColor','w', ...
            'HorizontalAlignment','center');

        sliderPos = [axPos(1)+0.015, axPos(2), axPos(3)-0.064, sliderHeight];
        trialSlider = uicontrol('Parent',hFig, 'Style','slider','Units','normalized','Position',sliderPos, ...
            'Min',1,'Max',nTrials,'Value',tr,'SliderStep',[1/(nTrials-1+eps), 5/(nTrials-1+eps)], ...
            'Callback',@(src,~) changeTrial(round(src.Value)));

        handles.trialLabel = trialLabel;
        handles.trialSlider = trialSlider;

        % Continuous data image 
        ax3 = axes('Parent',handles.hPanel, 'Position',[0.07 0.08 0.37 0.36]);
        numTrials = numel(handles.comps.trial);
        trialLen = cellfun(@(x) size(x,2), handles.comps.trial);
        minLen = min(trialLen);
        allTrials = zeros(numTrials,minLen);
        for t=1:numTrials
            allTrials(t,:) = handles.comps.trial{t}(c,1:minLen);
        end
        timeAxisTrial = handles.comps.time{1}(1:minLen);
        imagesc(ax3,timeAxisTrial,1:numTrials,allTrials);
        xlabel(ax3,'Time (s)'); ylabel(ax3,'Trial #');
        title(ax3,'Continuous data');
        colormap(ax3,jet); colorbar(ax3);
        set(ax3,'YDir','normal');
        clim = max(abs(allTrials(:))); caxis(ax3,[-clim clim]);

        % Power spectrum 
        ax4 = axes('Parent',handles.hPanel, 'Position',[0.56 0.08 0.40 0.36]);
        fs = handles.comps.fsample;
        allTrialData = cellfun(@(x) x(c,:), handles.comps.trial, 'UniformOutput', false);
        allTrialData = cell2mat(allTrialData);
        [p,f] = pwelch(allTrialData,fs,fs/2,fs,fs);
        p = 10*log10(p);
        plot(ax4,f,p,'r','LineWidth',1.5);
        xlabel(ax4,'Frequency (Hz)'); ylabel(ax4,'Power (dB)');
        title(ax4,sprintf('IC%d Activity Power Spectrum (all trials)',c));
        grid(ax4,'on'); xlim(ax4,[0.5 60]);

        % Artifact info & Marked status (update persistent annotations) 
        handles.artifactText.String = getArtifactType(handles.detected, c);
        if ismember(c, handles.comps.artComps)
            handles.markedText.String = 'MARKED';
        else
            handles.markedText.String = '';
        end

        % Keep the jump-to-component box in sync (e.g. after Prev/Next)
        set(handles.hJump, 'String', num2str(c));

        guidata(hFig, handles);
    end

    function changeTrial(trialIdx)
        handles = guidata(hFig);
        handles.currentTrial = trialIdx;
        guidata(hFig, handles);
        updateComponent();
    end

    function artifactType = getArtifactType(detected, compIdx)
        types = {};
        if ismember(compIdx, detected.blinks),  types{end+1} = 'Blink'; end
        if ismember(compIdx, detected.eyes),    types{end+1} = 'Eye'; end
        if ismember(compIdx, detected.muscle),  types{end+1} = 'Muscle'; end
        if ismember(compIdx, detected.disc),    types{end+1} = 'Discontinuity'; end

        if isempty(types)
            artifactType = '✅ Likely clean';
        else
            artifactType = ['⚠️ Potential artifact: ' strjoin(types, ', ')];
        end
    end

    function onClose(~,~)
        uiresume(hFig);
    end
end
