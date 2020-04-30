function extractEyeDataMatlabStructs(eye_data_full_eta_paths_cell_array, eye_data_full_edf_paths_cell_array, progress_tracking_callback_func)
    [code_folder, ~, ~] = fileparts(mfilename('fullpath'));
    addpath(fullfile(code_folder, 'code'));
    if ~isempty(eye_data_full_eta_paths_cell_array)        
        eta_files_nr= numel(eye_data_full_eta_paths_cell_array);
    else
        eta_files_nr= 0;
    end
    if ~isempty(eye_data_full_edf_paths_cell_array)       
        edf_files_nr= numel(eye_data_full_edf_paths_cell_array);
    else
        edf_files_nr= 0;
    end
    total_files_nr= eta_files_nr + edf_files_nr;

    for file_i= 1:eta_files_nr        
        eta_loaded_struct= load(eye_data_full_eta_paths_cell_array{file_i}, '-mat');
        if ~isfield(eta_loaded_struct, 'eta') || ~isa(eta_loaded_struct.eta, 'EyeTrackerAnalysisRecord')
            error(['failed to extract: ', eye_data_full_eta_paths_cell_array{file_i},'. file is not a valid .eta file!']);            
        end

        eye_tracking_data_structs= eta_loaded_struct.eta.getEyeTrackerDataStructs(); %#ok<NASGU>
        [orig_file_path, orig_file_name, ~]= fileparts(eye_data_full_eta_paths_cell_array{file_i});
        save(fullfile(orig_file_path, [orig_file_name,'.mat']), 'eye_tracking_data_structs');
        if nargin == 3 && ~isempty(progress_tracking_callback_func)
            progress_tracking_callback_func(1/total_files_nr);
        end
    end
      
    for file_i=1:edf_files_nr        
        full_file_path= eye_data_full_edf_paths_cell_array{file_i};
        [orig_file_path, ~, ~]= fileparts(full_file_path);
        convertEdfToMat(full_file_path, orig_file_path);
        if nargin == 3 && ~isempty(progress_tracking_callback_func)
            progress_tracking_callback_func(1/total_files_nr);
        end
    end    
    
    rmpath(fullfile(code_folder, 'code'));
end