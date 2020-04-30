%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Input: %
%%%%%%%%%%
%   (*) dpp (double): Degrees Per Pixel for the screen with which the eye data was recorded.
%
%   (*) eye_data_full_files_paths_cell_arrays (cell array of cell array of string): 
%           outer cell array: cell per subject. each cell contains a cell array.
%           inner cell array: cell per eye data file. each cell contains a full
%                             path for a data file.
%           example: { {'subject1/eye_data_session1.edf', 'subject1/eye_data_session2.mat'}, 
%                      {'subject2/eye_data_session1.edf', 'subject2/eye_data_session2.mat', 'subject2/eye_data_session3.edf'} }
%
%   (*) etas_full_save_paths_cell_array (cell array of string): cell per subject. each cell contains
%                                                               a full path and a name with which to save 
%                                                               the generated eta for the corresponding subject.
% ************
% * optional *
% ************
%   (*) progress_tracking_callback_func (function handle -> void(double)):
%           callback function which will be called occasionaly with a number in
%           the range (0,1] denoting the progress made since the last call to 
%           progress_tracking_callback_func, or since the beginning if this is
%           the first call to progress_tracking_callback_func.
%
%%%%%%%%%%%
% Output: %
%%%%%%%%%%%
%   None.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function createEtasFromEyeTrackerFiles(dpp, eye_data_full_files_paths_cell_arrays, etas_full_save_paths_cell_array, progress_tracking_callback_func)   
    [code_folder, ~, ~] = fileparts(mfilename('fullpath'));
    addpath(fullfile(code_folder, 'code'));
    requested_etas_nr = numel(eye_data_full_files_paths_cell_arrays);
    if numel(etas_full_save_paths_cell_array) ~= requested_etas_nr
        error('number of cells in [eye_data_full_files_paths_cell_arrays] must equal the number of files names in [etas_files_names_cell_array]');        
    end
    for requested_eta_i= 1:requested_etas_nr        
        [~, curr_subject_eta_save_file_name, ~]= fileparts(etas_full_save_paths_cell_array{requested_eta_i});                
        if nargin == 4 && ~isempty(progress_tracking_callback_func)
            curr_eta= EyeTrackerAnalysisRecord(curr_subject_eta_save_file_name, eye_data_full_files_paths_cell_arrays{requested_eta_i}, dpp, progress_tracking_callback_func, 0.9/requested_etas_nr);
        else
            curr_eta= EyeTrackerAnalysisRecord(curr_subject_eta_save_file_name, eye_data_full_files_paths_cell_arrays{requested_eta_i}, dpp);
        end
        
        curr_eta.save(etas_full_save_paths_cell_array{requested_eta_i});
        if nargin == 4 && ~isempty(progress_tracking_callback_func)
            progress_tracking_callback_func(0.1/requested_etas_nr);
        end
    end  
    rmpath(fullfile(code_folder, 'code'));
end