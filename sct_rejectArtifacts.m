function icaCleanTrials = sct_rejectArtifacts(components, cleanTrials, subjectDIR)
%SCT_REJECTARTIFACTS Removes marked artifactual ICA components from EEG data.
%   Re-derives the ICA component time courses from the cleaned trial data
%   using the previously computed unmixing matrix, then projects the data
%   back to sensor space with the artifactual components excluded. Also
%   logs the rejected component indices to a text file.
%
%   Input:
%       components  - struct output from ICA decomposition (e.g. from
%                     sct_runICA / sct_inspectICA), containing:
%                       .unmixing  - ICA unmixing matrix
%                       .topolabel - channel labels corresponding to the
%                                    unmixing matrix
%                       .artComps  - indices of components marked as
%                                    artifactual for rejection
%       cleanTrials - FieldTrip data struct (scalar) containing the
%                     trial data to clean
%       subjectDIR  - path to the subject's output directory, used to
%                     derive the subject ID and save output files
%
%   Output:
%       icaCleanTrials - FieldTrip data struct with artifactual
%                        components projected out, plus an added
%                        .artifacts field listing the rejected component
%                        indices
%
%   Example:
%       icaCleanTrials = sct_rejectArtifacts(components, cleanTrials, subjectDIR);
%
%   See also: SCT_RUNICA, SCT_INSPECTICA, SCT_SAVERESULT, FT_REJECTCOMPONENT

    % Reconstruct ICA component time courses from the cleaned trial data
    % using the previously computed unmixing matrix
    cfg = [];
    cfg.unmixing = components.unmixing;
    cfg.topolabel = components.topolabel;
    cfg.channel = components.topolabel;
    compOrig = ft_componentanalysis(cfg, cleanTrials);

    % Project back to sensor space, excluding components marked as
    % artifactual
    cfg = [];
    cfg.component = components.artComps;
    cfg.channel = components.topolabel;
    icaCleanTrials = ft_rejectcomponent(cfg, compOrig, cleanTrials);

    % Store rejected component indices, alongside the cleaned data
    icaCleanTrials.artifacts = components.artComps;

    [~, subjectID] = fileparts(subjectDIR);

    % Save rejected artifactual component indices to a log file
    componentLogFile = fullfile(subjectDIR, [subjectID '_artifactualComponents.txt']);
    fid = fopen(componentLogFile, 'w');
    fprintf(fid, 'Artifactual component indices:\n');
    fprintf(fid, '%d\n', components.artComps);
    fclose(fid);
    fprintf('\n\t--> Saved artifactual components list to: %s\n', componentLogFile);


end
