function convertEdfToMat(full_file_path, save_folder)      
    [code_folder, ~, ~] = fileparts(mfilename('fullpath'));
    read_edf_folder = fullfile(code_folder, 'readEDF'); 
    addpath(read_edf_folder);
    copyfile(full_file_path, pwd);
    [~, edf_file_name]= fileparts(full_file_path);
    eye_tracking_data_mat= readEDF([edf_file_name, '.edf']);
    eye_tracking_data_mat = rmfield(eye_tracking_data_mat, 'fixations');
    eye_tracking_data_mat = rmfield(eye_tracking_data_mat, 'saccades');
    eye_tracking_data_mat.gazeLeft = rmfield(eye_tracking_data_mat.gazeLeft, 'pix2degX');
    eye_tracking_data_mat.gazeLeft = rmfield(eye_tracking_data_mat.gazeLeft, 'pix2degY');
    eye_tracking_data_mat.gazeLeft = rmfield(eye_tracking_data_mat.gazeLeft, 'velocityX');
    eye_tracking_data_mat.gazeLeft = rmfield(eye_tracking_data_mat.gazeLeft, 'velocityY');
    eye_tracking_data_mat.gazeLeft = rmfield(eye_tracking_data_mat.gazeLeft, 'whichEye');
    eye_tracking_data_mat.gazeRight = rmfield(eye_tracking_data_mat.gazeRight, 'pix2degX');
    eye_tracking_data_mat.gazeRight = rmfield(eye_tracking_data_mat.gazeRight, 'pix2degY');
    eye_tracking_data_mat.gazeRight = rmfield(eye_tracking_data_mat.gazeRight, 'velocityX');
    eye_tracking_data_mat.gazeRight = rmfield(eye_tracking_data_mat.gazeRight, 'velocityY');
    eye_tracking_data_mat.gazeRight = rmfield(eye_tracking_data_mat.gazeRight, 'whichEye');
    save(fullfile(save_folder, [edf_file_name, '.mat']), 'eye_tracking_data_mat', '-v7.3');
    delete([edf_file_name, '.edf']);
    rmpath(read_edf_folder);
end