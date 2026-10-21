function filename = sct_saveResult(data, subjectDIR, name)
%SCT_SAVERESULT Saves a pipeline variable to a subject's .mat file, with
%   consistent naming and logging.
%
%   The saved .mat file contains a variable named exactly 'name' (not
%   'data'), so existing load calls like load(filename, 'icaCleanTrials')
%   keep working unchanged.
%
%   Input:
%       data       - the variable to save
%       subjectDIR - (string) full path to the subject's results
%                    directory
%       name       - (string) both the variable name to store inside the
%                    .mat file, and the filename suffix (e.g.
%                    'preprocessed', 'cleanTrials', 'components',
%                    'icaCleanTrials', 'erp')
%
%   Output:
%       filename - full path to the saved .mat file (for logging/
%                  chaining by the caller, if needed)
%
%   Example:
%       sct_saveResult(icaCleanTrials, subjectDIR, 'icaCleanTrials');
%
%   See also SCT_PREPROCESS, SCT_AUTOINSPECTTRIALS, SCT_RUNICA,
%   SCT_REJECTARTIFACTS, SCT_COMPUTEERP

    [~, subjectID] = fileparts(subjectDIR);
    filename = fullfile(subjectDIR, [subjectID '_' name '.mat']);

    % Store 'data' inside the .mat file under the variable name 'name',
    % via a struct field (save() would otherwise use the literal
    % workspace variable name 'data').
    toSave = struct();
    toSave.(name) = data;
    save(filename, '-struct', 'toSave');

    fprintf('\t--> Saved %s to %s\n', name, filename);

end
