function eyeTrackerAnalyzer()
%====================================%
%=== GUI PARAMETERS AND CONSTANTS ===%
%====================================%
%test
GUI_BACKGROUND_COLOR= [0.8, 0.8, 0.8];
READ_EDF_PATH= fullfile('readEDF');
ETAS_FOLDER_NAME = 'Eye Tracking Analysis Files';
ANALYSIS_RESULTS_FOLDER_NAME= 'Analysis Figures';

DPP= 1/60;

EXE_PLOT_CURVES= false;
MAX_SUBJECTS_NR_FOR_ETAS_CREATION= 10;

MAIN_FIGURE_TITLE= 'Eye Tracker Analyzer';
TRIAL_ONSET_TRIGGERS= [];
TRIAL_OFFSET_TRIGGERS = [];
TRIAL_REJECTION_TRIGGERS = [];
TRIAL_DURATION= [];
BASELINE= [];
POST_OFFSET_TRIGGERS_SEGMENT = [];
FILES_SAVE_DESTINATION= [];
FILES_FORMATS_CONVERSION_SAVE_DESTINATION= [];
ANALYSIS_RESULTS_FILE_DESTINATION= [];
BLINKS_DELTA= [];
PERFORM_EYEBALLING= 1;
EYE_EEG_DATA_SYNC_SAVE_FOLDER= [];
CURR_FILE_LOAD_FOLDER= pwd; 
MICROSACCADES_PARAMETERS_FIG= [];
BLINKS_PARAMETERS_FIG= [];

%ERROR MESSAGES
ERROR_MSG_NO_TRIGGERS= 'Please specify trial start triggers';
ERROR_MSG_NO_TRIAL_DUR= 'Please specify trial duration';
ERROR_MSG_NO_SUBJECTS= 'Please load at least one eye tracker data file';
ERROR_MSG_NO_BASELINE= 'Please specify baseline';
ERROR_MSG_NO_INPUT_FILES= 'Please specify at least one input file';
ERROR_MSG_NO_OUTPUT_FOLDER= 'Please specify output folder';
ERROR_MSG_NO_CHOSEN_ANALYSES= 'Please choose at least one analysis to save';
ERROR_MSG_NO_BLINKS_DELTA= 'Please specify blinks''s delta';
ERROR_MSG_NO_VEL_THRESHOLD= 'Please specify microsaccade''s velocity threshold';
ERROR_MSG_NO_AMP_LIM= 'Please specify microsaccade''s amplitude limit';
ERROR_MSG_MISSING_ETA_SAVE_FILE_NAMES= 'Please choose save names for all .ETA files';

MICROSACCADES_ANALYSIS_PARAMETERS.rate= 1;
MICROSACCADES_ANALYSIS_PARAMETERS.amplitudes= 1;
MICROSACCADES_ANALYSIS_PARAMETERS.directions= 1;
MICROSACCADES_ANALYSIS_PARAMETERS.main_sequence= 1;
MICROSACCADES_ANALYSIS_PARAMETERS.smoothing_window_len= 50;

ENGBERT_ALGORITHM_DEFAULTS.amp_lim= 1;
ENGBERT_ALGORITHM_DEFAULTS.amp_low_lim = 0.1;
ENGBERT_ALGORITHM_DEFAULTS.vel_vec_type= 1; 
ENGBERT_ALGORITHM_DEFAULTS.vel_threshold= 6;
ENGBERT_ALGORITHM_DEFAULTS.saccade_dur_min= 6;
ENGBERT_ALGORITHM_DEFAULTS.frequency_max= 50;
ENGBERT_ALGORITHM_DEFAULTS.filter_bandpass= 60;

%==================%
%=== UICONTROLS ===%
%==================%
%CREATE MAIN FIGURE
screen_size= get(0,'monitorpositions');
if any(screen_size(1)<0)
    screen_size= get(0,'ScreenSize');
end

screen_size= screen_size(1,:);
main_figure_positions= round([0.2*screen_size(3), -0.2*screen_size(4), 0.6*screen_size(3), 0.8*screen_size(4)]);

gui= figure('Visible', 'off', 'name', MAIN_FIGURE_TITLE, 'NumberTitle', 'off', 'units', 'pixels', ...
    'Position', main_figure_positions, ... 
    'MenuBar', 'none', ...  
    'color', GUI_BACKGROUND_COLOR, ...
    'DeleteFcn', @guiCloseCallback, ...
    'userdata', pwd);

menu_bar= uimenu(gui,'Label','Action');
analyze_micro_saccades_uimenu_handle= uimenu(menu_bar,'Label','Eye Data Analysis', 'checked', 'on', 'callback', @guiActionSelectedAnalyzeMicroSaccades);
etas_creation_uimenu_handle= uimenu(menu_bar,'Label','Create .ETAs', 'callback', @guiActionSelectedCreateEtas);
convert_files_formats_uimenu_handle= uimenu(menu_bar,'Label','Extract Eye Data As .MAT', 'callback', @guiActionSelectedConvertFileFormats);
%eye_eeg_data_sync_uimenu_handle= uimenu(menu_bar,'Label','Eye & EEG Data Merged Analysis - primal', 'callback', @guiActionSelectedEyeEegDataSync);

analyze_microsaccades_panel= uipanel(gui, 'tag', 'p1', 'units', 'normalized', ...
    'Position',[0.0026    0.0093    0.9928    0.9851], ...
    'visible', 'on', ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

uicontrol(analyze_microsaccades_panel, 'Style','text', 'tag', 'c15', 'units', 'normalized', ...
    'String', 'Eye Data Analyzer', ...
    'Position', [0.2984    0.9030    0.4158    0.0818], ...
    'FontSize', 24.0, ...    
    'BackgroundColor', GUI_BACKGROUND_COLOR);

%LOAD SUBJECTS' .ETAs FOR ANALYSIS UICONTROLS
img = imread('resources/Folder-Explorer-icon.png','png');
folder_icon_img_data= imresize(img, 0.25);
%img= imread('resources/numbers_column.png','png');
%numbers_list_img_data= imresize(img, 0.13);
img= imread('resources/X-icon.png','png');
x_icon_img_data= imresize(img, 0.4);
subjects_nr= 0;

uicontrol(analyze_microsaccades_panel, 'Style', 'text', 'tag', 'c5', 'units', 'normalized', ...
    'String', 'Subjects'' .ETAs', ...
    'Position', [0.3498    0.8490    0.3000    0.0425], ...
    'FontSize', 16.0, ...    
    'BackgroundColor', GUI_BACKGROUND_COLOR);

uicontrol(analyze_microsaccades_panel, 'Style', 'pushbutton', 'tag', 'c6', 'units', 'normalized', ...
    'Position', [0.0699    0.7839    0.0494    0.0551], ...
    'CData', imresize(folder_icon_img_data,1.2), ...
    'callback', {@loadEtasForAnalysisBtnCallback});

uicontrol(analyze_microsaccades_panel, 'Style', 'pushbutton', 'tag', 'c7', 'units', 'normalized', ...
    'Position', [0.0699    0.7225    0.0494    0.0551], ...
    'CData', imresize(x_icon_img_data,1.2), ...
    'callback', {@clearEtasForAnalysisBtnCallback});

load_etas_for_analysis_display_pane= uicontrol(analyze_microsaccades_panel, 'Style', 'listbox', 'tag', 'c99', 'units', 'normalized', ...
    'max', 2, 'string', {}, 'FontSize', 12.0, ...
    'Position', [0.1235    0.5773    0.7792    0.2626]);

uicontrol(analyze_microsaccades_panel, 'Style', 'text', 'tag', 'c70', 'units', 'normalized', ...
    'String', 'Data Segmentation Parameters', ...
    'Position', [0.3468    0.4430    0.3000    0.0425], ...
    'FontSize', 16.0, ...    
    'BackgroundColor', GUI_BACKGROUND_COLOR);

segmentation_panel= uipanel(analyze_microsaccades_panel, 'tag', 'p4', 'units', 'normalized', ...
    'Position', [0.0273    0.2570    0.9416    0.1714], ...
    'visible', 'on', ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

trials_onset_triggers_button_group= uipanel(segmentation_panel, 'tag', 'c9', ...
    'Position', [0.0028788     0.1424     0.20007     0.71903], ...
    'Background', GUI_BACKGROUND_COLOR, ...
    'BorderWidth', 0);

uicontrol(trials_onset_triggers_button_group, 'Style','text', 'units', 'normalized', ...
    'String', 'Trials Onset Triggers', ...
    'Position', [0.032, 0.25, 0.175, 0.5], ...
    'FontSize', 10.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

trials_onset_triggers_display= uicontrol(trials_onset_triggers_button_group, 'Style', 'listbox', 'units', 'normalized', ...
    'max', 2, 'string', {}, 'FontSize', 12.0, ...
    'Position', [0.65, 0.05, 0.325, 0.9]);

uicontrol(trials_onset_triggers_button_group, 'Style', 'pushbutton', 'units', 'normalized', ...
    'String', 'delete', ...
    'Position', [0.425, 0.2, 0.2, 0.6], ...
    'FontSize', 10.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR, ....
    'callback', {@deleteNumFromGroupCallback, trials_onset_triggers_display});

uicontrol(trials_onset_triggers_button_group, 'Style', 'edit', 'units', 'normalized', ...
    'Position', [0.25, 0.2, 0.15, 0.6], 'FontSize', 12.0, ...
    'callback', {@addStrToGroupCallback, trials_onset_triggers_display});

trials_offset_triggers_button_group= uipanel(segmentation_panel, 'tag', 'c72', ...
    'Position', [0.22635     0.1424     0.20007     0.71903], ...
    'Background', GUI_BACKGROUND_COLOR, ...
    'BorderWidth', 0);

uicontrol(trials_offset_triggers_button_group, 'Style','text', 'units', 'normalized', ...
    'String', 'Trials Offset Triggers', ...
    'Position', [0.032, 0.25, 0.175, 0.5], ...
    'FontSize', 10.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

trials_offset_triggers_display= uicontrol(trials_offset_triggers_button_group, 'Style', 'listbox', 'units', 'normalized', ...
    'max', 2, 'string', {}, 'FontSize', 12.0, ...
    'Position', [0.65, 0.05, 0.325, 0.9]);

uicontrol(trials_offset_triggers_button_group, 'Style', 'pushbutton', 'units', 'normalized', ...
    'String', 'delete', ...
    'Position', [0.425, 0.2, 0.2, 0.6], ...
    'FontSize', 10.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR, ....
    'callback', {@deleteNumFromGroupCallback, trials_offset_triggers_display});

uicontrol(trials_offset_triggers_button_group, 'Style', 'edit', 'units', 'normalized', ...
    'Position', [0.25, 0.2, 0.15, 0.6], 'FontSize', 12.0, ...
    'callback', {@addStrToGroupCallback, trials_offset_triggers_display});

trials_rejection_triggers_button_group= uipanel(segmentation_panel, 'tag', 'c75', ...
    'Position', [0.4494    0.1424    0.2001    0.7190], ...
    'Background', GUI_BACKGROUND_COLOR, ...
    'BorderWidth', 0);

uicontrol(trials_rejection_triggers_button_group, 'Style','text', 'units', 'normalized', ...
    'String', 'Trials Rejection Triggers', ...
    'Position', [0.02, 0.25, 0.22, 0.5], ...
    'FontSize', 10.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

trials_rejection_triggers_display= uicontrol(trials_rejection_triggers_button_group, 'Style', 'listbox', 'units', 'normalized', ...
    'max', 2, 'string', {}, 'FontSize', 12.0, ...
    'Position', [0.65, 0.05, 0.325, 0.9]);

uicontrol(trials_rejection_triggers_button_group, 'Style', 'pushbutton', 'units', 'normalized', ...
    'String', 'delete', ...
    'Position', [0.425, 0.2, 0.2, 0.6], ...
    'FontSize', 10.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR, ....
    'callback', {@deleteNumFromGroupCallback, trials_rejection_triggers_display});

uicontrol(trials_rejection_triggers_button_group, 'Style', 'edit', 'units', 'normalized', ...
    'Position', [0.25, 0.2, 0.15, 0.6], 'FontSize', 12.0, ...
    'callback', {@addStrToGroupCallback, trials_rejection_triggers_display});

uicontrol(segmentation_panel, 'Style', 'text', 'tag', 'c12', 'units', 'normalized', ...
    'String', 'Pre-onset-trigger segment duration (ms)', ...
    'Position', [0.67987     0.60328      0.1198      0.1901], ...
    'FontSize', 10.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

uicontrol(segmentation_panel, 'Style', 'edit', 'tag', 'c13', 'units', 'normalized', ...
    'Position', [0.8081     0.57667    0.0304      0.2556], ...
    'callback', {@baseLineEditedCallback});

post_offset_trigger_segment_txt_uicontrol = uicontrol(segmentation_panel, 'Style', 'text', 'tag', 'c73', 'units', 'normalized', ...
    'String', 'Post-offset-trigger segment duration (ms)', ...
    'Position', [0.6799    0.2275    0.1198    0.1901], ...
    'FontSize', 10.0, ...
    'Enable', 'off', ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

post_offset_trigger_segment_edit_uicontrol = uicontrol(segmentation_panel, 'Style', 'edit', 'tag', 'c74', 'units', 'normalized', ...
    'Position', [0.8081    0.1882    0.0304    0.2556], ...
    'Enable', 'off', ...
    'callback', {@postOffsetTriggerTimeEditedCallback});

analysis_segment_dur_txt_uicontrol = uicontrol(segmentation_panel, 'Style', 'text', 'tag', 'c10', 'units', 'normalized', ...
    'String', 'Analysis segment duration (ms)', ...
    'Position', [0.8534    0.5947    0.0896    0.2158], ...
    'FontSize', 10.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

uicontrol(segmentation_panel, 'Style', 'edit', 'tag', 'c11', 'units', 'normalized', ...
    'Position', [0.95691      0.57667    0.0304      0.2556], ...
    'callback', {@trialDurationEditedCallback});

uicontrol(segmentation_panel, 'Style', 'text', 'tag', 'c80', 'units', 'normalized', ...
    'String', 'Blinks Delta (ms)', ...
    'Position', [0.8623    0.2014    0.0699    0.2008], ...
    'FontSize', 10.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

uicontrol(segmentation_panel, 'Style', 'edit', 'tag', 'c811', 'units', 'normalized', ...
    'Position', [0.95691      0.1882    0.0304      0.2556], ...
    'callback', {@blinksDeltaEditedCallback});

%ANALYSIS SAVE FOLDER UICONTROLS
uicontrol(analyze_microsaccades_panel, 'Style', 'text', 'tag', 'c95', 'units', 'normalized', ...
    'String', 'Save Folder', ...
    'Position', [0.1499    0.1495    0.1486    0.0271], ...
    'FontSize', 12.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

uicontrol(analyze_microsaccades_panel, 'Style', 'pushbutton', 'tag', 'c16', 'units', 'normalized', ...
    'String', 'Browse', ...
    'Position', [0.72702      0.1467      0.0908       0.031], ...
    'FontSize', 12.0, ...
    'callback', {@saveFolderBtnCallback});

save_file_folder_etext= uicontrol(analyze_microsaccades_panel, 'Style', 'edit', 'tag', 'c17', 'units', 'normalized', ...
    'enable', 'inactive', 'Position', [0.27532      0.1465      0.4149      0.0316]);

%RUN ANALYSES UICONTROLS
uicontrol(analyze_microsaccades_panel, 'Style', 'checkbox', 'tag', 'c14', 'units', 'normalized', ...
    'FontSize', 12.0, 'String', 'Display Curves', 'Position', [0.0654    0.0347    0.1074    0.0269], ...
    'BackgroundColor', GUI_BACKGROUND_COLOR, ...
    'value', EXE_PLOT_CURVES, ...
    'callback', {@plotCurvesToggledCallback});

uicontrol(analyze_microsaccades_panel, 'Style', 'pushbutton', 'tag', 'msb', 'units', 'normalized', ...
    'String', 'Analyze Saccades', ...
    'Position', [0.2197    0.0212    0.2066    0.0519], ...
    'FontSize', 12.0, ...
    'callback', {@runAnalysisBtnCallback, @analyzeMicrosaccades, @microsaccadesParametersFigCreator, 'analyzing saccades'});

uicontrol(analyze_microsaccades_panel, 'Style', 'pushbutton', 'tag', 'bb', 'units', 'normalized', ...
    'String', 'Analyze Blinks', ...
    'Position', [0.4417    0.0212    0.2066    0.0519], ...
    'FontSize', 12.0, 'visible', 'off', ...
    'callback', {@runAnalysisBtnCallback, @analyzeBlinks, @blinksParametersFigCreator, 'analyzing blinks'});

uicontrol(analyze_microsaccades_panel, 'Style', 'pushbutton', 'tag', 'fb', 'units', 'normalized', ...
    'String', 'Analyze Pupils Diameters', ...
    'Position', [0.6636    0.0212    0.2066    0.0519], ...
    'FontSize', 12.0, ...
    'callback', {@runAnalysisBtnCallback, @analyzePupilsSz, [], 'Analyzing Pupils Size'});

uicontrol(analyze_microsaccades_panel, 'Style', 'pushbutton', 'tag', 'fb', 'units', 'normalized', ...
    'String', 'Analyze Fixations', ...
    'Position', [0.4417    0.0212    0.2066    0.0519], ...
    'FontSize', 12.0, ...
    'callback', {@runAnalysisBtnCallback, @analyzeFixations, [], 'Analyzing Fixations'});

%CREATE ETAS PRIMAL UICONTROLS
img = imread('resources/save_file.png','png');
save_file_icon_img_data= imresize(img, 0.2);

requested_etas_nr= 0;
etas_creation_panel= uipanel(gui, 'tag', 'p2', 'units', 'normalized', ...
    'Position',[0.0026    0.0093    0.9928    0.9851], ...
    'visible', 'off', ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

uicontrol(etas_creation_panel, 'Style', 'text', 'tag', 'c100', 'units', 'normalized', ...
    'String', 'Create .ETAs From Eye tracking Files', ...
    'Position', [0.2438    0.9138    0.4957    0.0530], ...
    'FontSize', 24.0, ...    
    'BackgroundColor', GUI_BACKGROUND_COLOR);

data_files_listbox_primal= uicontrol(etas_creation_panel, 'Style', 'listbox', 'tag', 'c101', 'units', 'normalized', ...
    'Position', [0.0751    0.7426    0.3828    0.0921], 'max', 2, 'string', {});

eta_save_file_etext_primal= uicontrol(etas_creation_panel, 'Style', 'edit', 'tag', 'c201', 'units', 'normalized', ...
    'enable', 'inactive', 'max', 2, 'FontSize', 12, ...
    'HorizontalAlignment', 'left', ...
    'Position', [0.0751    0.8353    0.3828    0.0450]);

% eta_save_file_etext_primal_jcp= findjobj(eta_save_file_etext_primal);
% eta_save_file_etext_primal_jcp_java_internal_edit_control= eta_save_file_etext_primal_jcp.getComponent(0).getComponent(0);
% set(eta_save_file_etext_primal_jcp_java_internal_edit_control,'Editable',0);

eta_save_btn_primal= uicontrol(etas_creation_panel, 'Style', 'pushbutton', 'tag', 'c301', 'units', 'normalized', 'Enable', 'off', ...    
    'Position', [0.0368    0.8353    0.0340    0.0450], ...
    'CData', save_file_icon_img_data, ...
    'callback', {@etaSaveBtnCallback}, ...
    'UserData', eta_save_file_etext_primal);
        
load_data_file_btn_primal= uicontrol(etas_creation_panel, 'Style', 'pushbutton', 'tag', 'c401', 'units', 'normalized', ...
    'Position', [0.0368    0.7886    0.0340    0.0450], ...
    'CData', folder_icon_img_data, ...
    'callback', {@loadFileForEtaCreationBtnCallback}, ...
    'UserData', {data_files_listbox_primal, eta_save_btn_primal, eta_save_file_etext_primal} );

clear_data_file_btn_primal= uicontrol(etas_creation_panel, 'Style', 'pushbutton', 'tag', 'c501', 'units', 'normalized', ...
    'Position', [0.0368    0.7426    0.0340    0.0450], ...
    'CData', x_icon_img_data, ...
    'callback', {@clearFileForEtaCreationBtnCallback}, ...
    'UserData', {data_files_listbox_primal, eta_save_btn_primal} );

set(data_files_listbox_primal, 'UserData', 1);
load_data_files_uicontrols(requested_etas_nr+1, 1:5)= {data_files_listbox_primal, eta_save_file_etext_primal, eta_save_btn_primal, load_data_file_btn_primal, clear_data_file_btn_primal};

uicontrol(etas_creation_panel, 'Style', 'pushbutton', 'tag', 'cefeb', 'units', 'normalized', ...
    'String', 'Create', ...
    'Position', [0.5521    0.0504    0.2781    0.0730], ...
    'FontSize', 20.0, ...    
    'callback', {@createEtasFromEyeTrackerFilesBtnCallback});

%RECORDING PARAMETERS UICONTROLS
%recording_parameters_buttons_group= uipanel(etas_creation_panel, 'tag', 'p10', 'units', 'normalized', ...
%    'Position',[0.1796    0.0170    0.2772    0.1096], ...
%    'visible', 'on', ...
%    'BackgroundColor', GUI_BACKGROUND_COLOR);

uicontrol(etas_creation_panel, 'Style','text', 'tag', 'c4.0', 'units', 'normalized', ...
    'String', 'Experiment Screen''s Pixels Per Visual Degree', ...
    'Position', [0.1620    0.0777    0.2192    0.0310], ...
    'FontSize', 14.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

uicontrol(etas_creation_panel, 'Style', 'edit', 'tag', 'c4.1', 'units', 'normalized', ...
    'string', 1/DPP, ...
    'Position', [0.3954    0.0643    0.0668    0.0486], 'FontSize', 12.0, ...
    'callback', @dppEditedCallback);

%EXTRACT EYE DATA .MAT FILE UICONTROLS
convert_files_formats_panel= uipanel(gui, 'tag', 'p3', 'units', 'normalized', ...
    'Position', [0.0026    0.0093    0.9928    0.9851], ...
    'visible', 'off', ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

uicontrol(convert_files_formats_panel, 'Style', 'text', 'tag', 'c708', 'units', 'normalized', ...
    'String', 'Extract Eye Data As .mat', ...
    'Position', [0.2710    0.9101    0.4158    0.0425], ...
    'FontSize', 24.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

uicontrol(convert_files_formats_panel, 'Style', 'text', 'tag', 'c46', 'units', 'normalized', ...
    'String', '.edf -> .mat extraction', ...
    'Position', [0.0228    0.5796    0.3184    0.0378], ...
    'FontSize', 20.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

convert_edf_listbox= uicontrol(convert_files_formats_panel, 'Style', 'listbox', 'tag', 'c40', 'units', 'normalized', ...
    'Position', [0.4018    0.5349    0.3965    0.1156], 'FontSize', 12, 'max', 2, 'string', {});

uicontrol(convert_files_formats_panel, 'Style', 'pushbutton', 'tag', 'c41', 'units', 'normalized', ...
    'Position', [0.3473    0.5938    0.0525    0.0569], ...
    'CData', imresize(folder_icon_img_data,1.35), ...
    'callback', {@loadEDFConversionFileBtnCallback});

uicontrol(convert_files_formats_panel, 'Style', 'pushbutton', 'tag', 'c42', 'units', 'normalized', ...
    'Position', [0.3473    0.5349    0.0525    0.0569], ...
    'CData', imresize(x_icon_img_data,1.35), ...
    'callback', {@clearEDFConversionFileBtnCallback});

uicontrol(convert_files_formats_panel, 'Style', 'text', 'tag', 'c804', 'units', 'normalized', ...
    'String', '.eta -> .mat extraction', ...
    'Position', [0.0228    0.7673    0.3184    0.0378], ...
    'FontSize', 20.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

convert_eta_listbox= uicontrol(convert_files_formats_panel, 'Style', 'listbox', 'tag', 'c805', 'units', 'normalized', ...
    'Position', [0.4018    0.7202    0.3965    0.1156], 'FontSize', 12, 'max', 2, 'string', {});

uicontrol(convert_files_formats_panel, 'Style', 'pushbutton', 'tag', 'c806', 'units', 'normalized', ...
    'Position', [0.3473    0.7792    0.0525    0.0569], ...
    'CData', imresize(folder_icon_img_data,1.35), ...
    'callback', {@loadEtaConversionFileBtnCallback});

uicontrol(convert_files_formats_panel, 'Style', 'pushbutton', 'tag', 'c807', 'units', 'normalized', ...
    'Position', [0.3473    0.7202    0.0525    0.0569], ...
    'CData', imresize(x_icon_img_data,1.35), ...
    'callback', {@clearEtaConversionFileBtnCallback});

uicontrol(convert_files_formats_panel, 'Style', 'text', 'tag', 'c43', 'units', 'normalized', ...
    'String', 'Save Folder', ...
    'Position', [0.0517    0.2550    0.1266    0.0373], ...
    'FontSize', 14.0, ...
    'BackgroundColor', GUI_BACKGROUND_COLOR);

convert_edf_save_folder_etext= uicontrol(convert_files_formats_panel, 'Style', 'edit', 'tag', 'c44', 'units', 'normalized', ...
    'Position', [0.1772    0.2526    0.6193    0.0411], 'FontSize', 12.0);

uicontrol(convert_files_formats_panel, 'Style', 'pushbutton', 'tag', 'c45', 'units', 'normalized', ...
    'String', 'Browse', ...
    'Position', [0.8148    0.2514    0.1247    0.0431], ...
    'FontSize', 14.0, ...
    'callback', {@convertFilesFormatsSaveFolderBtnCallback});

uicontrol(convert_files_formats_panel, 'Style', 'pushbutton', 'tag', 'cffb', 'units', 'normalized', ...
    'String', 'Extract', ...
    'Position', [0.3219    0.0932    0.3070    0.0832], ...
    'FontSize', 20.0, ...    
    'callback', {@convertFilesFormatsBtnCallback});

%SHOW THE GUI
set(gui, 'Visible', 'on');

%=================%
%=== CALLBACKS ===%
%=================%
    function guiActionSelectedAnalyzeMicroSaccades(~,~)        
        setEtasCreationScreenVisiblity(false);
        setConvertFilesFormatsScreenVisiblity(false);         
        setAnalyzeMicrosaccadesScreenVisiblity(true);
    end
        
    function guiActionSelectedConvertFileFormats(~,~)
        setAnalyzeMicrosaccadesScreenVisiblity(false);
        setEtasCreationScreenVisiblity(false);                 
        setConvertFilesFormatsScreenVisiblity(true);
    end
    
    function guiActionSelectedCreateEtas(~,~)
        setAnalyzeMicrosaccadesScreenVisiblity(false);        
        setConvertFilesFormatsScreenVisiblity(false);          
        setEtasCreationScreenVisiblity(true);
    end        
    
    function setAnalyzeMicrosaccadesScreenVisiblity(is_visible)
        controls_state_str= logical2OnOff(is_visible);        
        set(analyze_microsaccades_panel, 'visible', controls_state_str);
        set(analyze_micro_saccades_uimenu_handle, 'Checked', controls_state_str); 
        set(segmentation_panel, 'visible', controls_state_str);
    end

    function setEtasCreationScreenVisiblity(is_visible)        
        controls_state_str= logical2OnOff(is_visible);
        set(etas_creation_panel, 'visible', controls_state_str);
        set(etas_creation_uimenu_handle, 'checked', controls_state_str);        
    end

    function setConvertFilesFormatsScreenVisiblity(is_visible)        
        controls_state_str= logical2OnOff(is_visible);        
        set(convert_files_formats_panel, 'visible', controls_state_str);
        set(convert_files_formats_uimenu_handle, 'checked', controls_state_str);
    end
    
    function on_off= logical2OnOff(logical)
        if logical
            on_off= 'on';
        else
            on_off= 'off';
        end
    end  
    
    function dppEditedCallback(hObject, ~)
        input= get(hObject,'string');
        if isStrAPositiveRealNumber(input) 
            DPP= 1/str2double(input);            
        else
            set(hObject,'string', DPP);
        end
    end        

    function etaSaveBtnCallback(hObject, ~)
        corresponding_etext_h= get(hObject, 'UserData');
        [~, file_name, ~] = fileparts(get(corresponding_etext_h, 'string'));
        [save_file_name, save_path, ~] = uiputfile({'*.eta','Eye Tracker Analyzer file'}, 'Choose the save location and a name for the Eye Tracker Analyzer file', fullfile(CURR_FILE_LOAD_FOLDER, file_name));
        if ~ischar(save_file_name)
            return;
        end
        
        CURR_FILE_LOAD_FOLDER= save_path;        
        set(corresponding_etext_h, 'string', fullfile(save_path, save_file_name));
    end

    function loadFileForEtaCreationBtnCallback(hObject,~)
        load_file_btn_user_data= get(hObject,'UserData');
        corresponding_listbox= load_file_btn_user_data{1};
        listbox_string= get(corresponding_listbox,'string');                        
        [requested_files_names, path_name, ~] = uigetfile({'*.edf;*.mat;*.set','eyelink data containers'}, 'Choose eye tracker data files', CURR_FILE_LOAD_FOLDER, 'MultiSelect','on');
        if ~iscell(requested_files_names) && ~ischar(requested_files_names)
            return;        
        end                
        
        CURR_FILE_LOAD_FOLDER= path_name;                                                  
        if isempty(listbox_string)
            requested_etas_nr= requested_etas_nr + 1;
            if requested_etas_nr<MAX_SUBJECTS_NR_FOR_ETAS_CREATION
                createNewFileLoadingUicontrols();
            end                        
        end
                
        addFilesNamesToFilesListBox(corresponding_listbox, requested_files_names, path_name)                        
        corresponding_save_file_btn= load_file_btn_user_data{2};
        set(corresponding_save_file_btn, 'Enable', 'on');
                
        corresponding_save_file_etext= load_file_btn_user_data{3};
        requested_files_full_paths = get(corresponding_listbox, 'string');                
        if numel(requested_files_full_paths) == 1
            [~, file_name, ~] = fileparts(requested_files_full_paths{1});
            set(corresponding_save_file_etext, 'string', fullfile(CURR_FILE_LOAD_FOLDER, [file_name, '.eta']));   
        elseif requested_etas_nr > 1
            prev_eta_file_name = get(load_data_files_uicontrols{requested_etas_nr - 1, 2}, 'string');    
            was_serial_digit_found = false;
            for prev_eta_serial_num_last_char_i = numel(prev_eta_file_name):-1:1
                if isstrprop(prev_eta_file_name(prev_eta_serial_num_last_char_i), 'digit')
                    was_serial_digit_found = true;
                    break;
                end
            end
            if ~was_serial_digit_found
                return;
            end
            
            for prev_eta_serial_num_pre_first_char_i = prev_eta_serial_num_last_char_i - 1:-1:1
                if ~isstrprop(prev_eta_file_name(prev_eta_serial_num_pre_first_char_i), 'digit')
                    break;
                end
            end
            
            prev_eta_serial_num = str2num(prev_eta_file_name(prev_eta_serial_num_pre_first_char_i+1:prev_eta_serial_num_last_char_i));
            curr_eta_auto_file_name = [prev_eta_file_name(1:prev_eta_serial_num_pre_first_char_i), ...
                num2str(prev_eta_serial_num + 1),  ...
                prev_eta_file_name(prev_eta_serial_num_last_char_i + 1:end)];
            set(corresponding_save_file_etext, 'string', curr_eta_auto_file_name);
        end
    end

    function clearFileForEtaCreationBtnCallback(hObject, ~)
        clear_edf_btn_user_data= get(hObject,'UserData');
        corresponding_listbox= clear_edf_btn_user_data{1};
        listbox_string= get(corresponding_listbox,'string');
        if numel(listbox_string)==0
            return;
        elseif numel(listbox_string)==1
            if requested_etas_nr==MAX_SUBJECTS_NR_FOR_ETAS_CREATION
                for load_data_file_controls_group_i= get(corresponding_listbox, 'UserData'):requested_etas_nr-1                                                  
                    [curr_data_files_listbox, next_data_files_listbox]= load_data_files_uicontrols{load_data_file_controls_group_i:load_data_file_controls_group_i+1, 1};                    
                    set(curr_data_files_listbox, 'string', get(next_data_files_listbox,'string'));                    
                end
                
                set(load_data_files_uicontrols{requested_etas_nr, 1}, 'string', []);
                set(load_data_files_uicontrols{requested_etas_nr, 3}, 'Enable', 'on');
            else
                listbox_i= get(corresponding_listbox, 'UserData');                
                for eta_creation_uicontrols_group_i= requested_etas_nr:-1:listbox_i 
                    for eta_creation_uicontrol_i= 1:5
                        exchangeEtaCreationUicontrolsPosAndTag(eta_creation_uicontrols_group_i, eta_creation_uicontrols_group_i+1, eta_creation_uicontrol_i);
                    end
                    
                    curr_group_listbox_h= load_data_files_uicontrols{eta_creation_uicontrols_group_i, 1};
                    next_group_listbox_h= load_data_files_uicontrols{eta_creation_uicontrols_group_i+1, 1};
                    set(next_group_listbox_h, 'UserData', get(curr_group_listbox_h, 'UserData'));
                end
                
                delete([load_data_files_uicontrols{listbox_i, :}]);
                load_data_files_uicontrols(listbox_i, :)= [];
            end                                                                        
            requested_etas_nr= requested_etas_nr-1;
        else
            listbox_string(get(corresponding_listbox,'value'))= [];
            set(corresponding_listbox, 'value', 1);
            set(corresponding_listbox, 'string', listbox_string);
        end
        
        function exchangeEtaCreationUicontrolsPosAndTag(src_group_i, dst_group_i, uicontrols_i)            
            [src_uicontrol, dst_uicontrol]= load_data_files_uicontrols{src_group_i:dst_group_i, uicontrols_i};            
            
            set(dst_uicontrol, 'tag', get(src_uicontrol,'tag'));
            set(dst_uicontrol, 'position', get(src_uicontrol,'position'));            
        end
    end           

    function createEtasFromEyeTrackerFilesBtnCallback(~,~)          
        if ~areAllEtaSaveFileNameEtextsFilled()
            errordlg(ERROR_MSG_MISSING_ETA_SAVE_FILE_NAMES);
            return;
        else
            cd(get(gui,'userdata'));
        end
        
        progress_screen= SingleBarProgressScreen('Creating .ETAs', [0.8, 0.8, 0.8], 0.4, 0.4);
        for requested_eta_i= 1:requested_etas_nr
            curr_subject_eye_tracker_files_list_box= load_data_files_uicontrols{requested_eta_i,1};
            curr_subject_eye_tracker_files_list= get(curr_subject_eye_tracker_files_list_box, 'string');
            curr_subject_eta_save_file_etext= load_data_files_uicontrols{requested_eta_i,2};
            [~, curr_subject_eta_save_file_name, ~]= fileparts(get(curr_subject_eta_save_file_etext, 'string'));
            progress_screen.displayMessage(['creating subject #', num2str(requested_eta_i), ' .ETA:']);
            try
                curr_eta= EyeTrackerAnalysisRecord(progress_screen, 0.9/requested_etas_nr, curr_subject_eta_save_file_name, curr_subject_eye_tracker_files_list, DPP);
            catch exception                
                progress_screen.displayMessage([exception.message, ' skipping subject.']);
                continue;
            end
            
            progress_screen.displayMessage(['saving .ETA for subject #', num2str(requested_eta_i)]);
            curr_eta.save(get(curr_subject_eta_save_file_etext, 'string'));
            progress_screen.addProgress(0.1/requested_etas_nr);
        end
        
        if ~progress_screen.isCompleted();
            progress_screen.updateProgress(1);
        end
        
        progress_screen.displayMessage('Done.');
        
        function res= areAllEtaSaveFileNameEtextsFilled()            
            for uicontrol_group_i= 1:requested_etas_nr
                curr_eta_save_file_etext_h= load_data_files_uicontrols{uicontrol_group_i, 2};
                if isempty(get(curr_eta_save_file_etext_h, 'string'))
                    res= false;
                    return;
                end
            end
            
            res= true;
        end
    end

    function createNewFileLoadingUicontrols()
         [new_pos_mat, new_tags_cell_arr]= calcNewUicontrolsPosAndTags();            
        
        data_files_listbox= uicontrol(etas_creation_panel, 'Style', 'listbox', 'tag', new_tags_cell_arr{1}, 'units', 'normalized', ...
            'max', 2, 'string', {}, 'Position', new_pos_mat(1,:));
                
        eta_save_file_etext= uicontrol(etas_creation_panel, 'Style', 'edit', 'tag', new_tags_cell_arr{2}, 'units', 'normalized', ...
            'enable', 'inactive', 'max', 2, 'FontSize', 12.0, ...
            'HorizontalAlignment', 'left', ...
            'Position', new_pos_mat(2,:));       

        eta_save_btn= uicontrol(etas_creation_panel, 'Style', 'pushbutton', 'tag', new_tags_cell_arr{3}, 'units', 'normalized', 'Enable', 'off', ...
            'Position', new_pos_mat(3,:), ...
            'CData', save_file_icon_img_data, ...
            'callback', {@etaSaveBtnCallback}, ...
            'UserData', eta_save_file_etext);
        
        load_data_file_btn= uicontrol(etas_creation_panel, 'Style', 'pushbutton', 'tag', new_tags_cell_arr{4}, 'units', 'normalized', ...
            'Position', new_pos_mat(4,:), ...
            'CData', folder_icon_img_data, ...
            'callback', {@loadFileForEtaCreationBtnCallback}, ...
            'UserData', {data_files_listbox, eta_save_btn, eta_save_file_etext} );      
        
        clear_data_file_btn= uicontrol(etas_creation_panel, 'Style', 'pushbutton', 'tag', new_tags_cell_arr{5}, 'units', 'normalized', ...
            'Position', new_pos_mat(5,:), ...
            'CData', x_icon_img_data, ...
            'callback', {@clearFileForEtaCreationBtnCallback}, ...
            'UserData', {data_files_listbox, eta_save_btn} );
        
        set(data_files_listbox, 'UserData', requested_etas_nr+1);
        load_data_files_uicontrols(requested_etas_nr+1, 1:5)= {data_files_listbox, eta_save_file_etext, eta_save_btn, load_data_file_btn, clear_data_file_btn};
        
        function [new_pos_mat, new_tags_cell_arr]= calcNewUicontrolsPosAndTags()            
            new_pos_mat= zeros(5,4);
            new_tags_cell_arr= cell(1,5);            
            if (mod(requested_etas_nr,2)==1) %creating uicontrols on the right column                
                prev_listbox_pos= extractPrevUicontrolPos(requested_etas_nr, 1);            
                prev_save_etext_pos= extractPrevUicontrolPos(requested_etas_nr, 2);                         
                new_listbox_pos= [1-(prev_listbox_pos(1)+prev_listbox_pos(3)), prev_listbox_pos(2:4)]; 
                new_id_etext_pos= [new_listbox_pos(1), prev_save_etext_pos(2:4)];
                new_pos_mat(1:2,1:4)= [new_listbox_pos; new_id_etext_pos];
                new_tags_cell_arr(1:2)= {generateNextUicontrolTag(1),generateNextUicontrolTag(2)};
                for uicontrol_i= 3:5  
                    prev_uicontrol_pos= extractPrevUicontrolPos(requested_etas_nr, uicontrol_i);
                    new_pos_mat(uicontrol_i,1:4)= [new_listbox_pos(1)-(prev_listbox_pos(1)-prev_uicontrol_pos(1)), prev_uicontrol_pos(2:4)];
                    new_tags_cell_arr{uicontrol_i}= generateNextUicontrolTag(uicontrol_i);                         
                end
            else %creating uicontrols on the left column 
                prev_listbox_pos= extractPrevUicontrolPos(requested_etas_nr-1, 1);            
                prev_save_etext_pos= extractPrevUicontrolPos(requested_etas_nr-1, 2);                         
                uicontrols_group_height= prev_listbox_pos(4)+prev_save_etext_pos(4);
                %in the name of shorter code and lack of care for performance here - extract listbox and id etext positions again
                for uicontrol_i= 1:5  
                    prev_uicontrol_pos= extractPrevUicontrolPos(requested_etas_nr-1, uicontrol_i);
                    new_pos_mat(uicontrol_i,1:4)= [prev_uicontrol_pos(1), prev_uicontrol_pos(2)-uicontrols_group_height-0.01, prev_uicontrol_pos(3:4)];                    
                    new_tags_cell_arr{uicontrol_i}= generateNextUicontrolTag(uicontrol_i);
                end
            end
                                    
            function prev_uicontrol_pos= extractPrevUicontrolPos(uicontrols_group_i, uicontrol_i)
                prev_uicontrol_h= load_data_files_uicontrols{uicontrols_group_i, uicontrol_i};
                prev_uicontrol_pos= get(prev_uicontrol_h, 'position');                
            end
            
            function  next_uicontrol_tag= generateNextUicontrolTag(uicontrol_i)
                prev_uicontrol_h= load_data_files_uicontrols{requested_etas_nr, uicontrol_i};
                prev_uicontrol_tag= get(prev_uicontrol_h, 'tag');
                next_uicontrol_tag= [prev_uicontrol_tag(1), num2str(str2num(prev_uicontrol_tag(2:end))+1)];
            end
        end
    end
          
    function loadEtasForAnalysisBtnCallback(~,~)               
        [files_names, path_name, ~] = uigetfile({'*.eta','Eye Tracker Analyzer file'}, 'Choose an Eye Tracker Analyzer file', CURR_FILE_LOAD_FOLDER, 'MultiSelect', 'on');
        if ~iscell(files_names) && ~ischar(files_names)
            return;        
        end
        
        CURR_FILE_LOAD_FOLDER= path_name;                                              
        addFilesNamesToFilesListBox(load_etas_for_analysis_display_pane, files_names, path_name); 
        subjects_nr= numel(get(load_etas_for_analysis_display_pane,'string'));
    end   
    
    function clearEtasForAnalysisBtnCallback(~,~)
        clearFileNameFromListBox(load_etas_for_analysis_display_pane);
        load_etas_for_analysis_display_pane_string= get(load_etas_for_analysis_display_pane,'string');
        subjects_nr= numel(load_etas_for_analysis_display_pane_string);
    end

    function addStrToGroupCallback(hObject, ~, triggers_display)
        input= get(hObject,'string');      
        %if (~isempty(input) && isempty(find(~isstrprop(input,'digit'),1)) && ~strcmp(input(1),'0'))
            set(triggers_display, 'string', [get(triggers_display,'string')', input]) ;           
        %end
        
        if triggers_display == trials_offset_triggers_display && numel(get(triggers_display,'string')) == 1   
            set(analysis_segment_dur_txt_uicontrol, 'string', 'analysis segment duration max (ms)');        
            set(post_offset_trigger_segment_txt_uicontrol, 'Enable', 'on');
            set(post_offset_trigger_segment_edit_uicontrol, 'Enable', 'on');            
        end
        
        set(hObject, 'string', '');
        set(triggers_display, 'value', numel(get(triggers_display, 'string'))); 
    end

    function deleteNumFromGroupCallback(~, ~, triggers_display)
        triggers_display_str= get(triggers_display, 'string');
        if isempty(triggers_display_str)
            return;
        end        
        triggers_display_value= get(triggers_display, 'value');        
        
        triggers_display_str(triggers_display_value)= [];
        set(triggers_display, 'string', triggers_display_str, 'value', 1); 
        
        if triggers_display == trials_offset_triggers_display && isempty(triggers_display_str)
            set(analysis_segment_dur_txt_uicontrol, 'string', 'analysis segment duration (ms)');
            set(post_offset_trigger_segment_txt_uicontrol, 'Enable', 'off');
            set(post_offset_trigger_segment_edit_uicontrol, 'Enable', 'off');
        end
    end

    function trialDurationEditedCallback(hObject,~)
        input= get(hObject,'string');
        if isStrAValidPositiveInteger(input)
            TRIAL_DURATION= str2double(input);
        else            
            set(hObject,'string', TRIAL_DURATION);
        end
    end

    function baseLineEditedCallback(hObject,~)
        input= get(hObject,'string');
        if isStrAValidNonNegativeInteger(input) 
            BASELINE= str2double(input);            
        else
            set(hObject,'string', BASELINE);
        end
    end
    
    function postOffsetTriggerTimeEditedCallback(hObject, ~)
        input= get(hObject,'string');
        if isStrAValidNonNegativeInteger(input) 
            POST_OFFSET_TRIGGERS_SEGMENT= str2double(input);            
        else
            set(hObject,'string', POST_OFFSET_TRIGGERS_SEGMENT);
        end        
    end


    function saveFolderBtnCallback(~,~)
        FILES_SAVE_DESTINATION = uigetdir(FILES_SAVE_DESTINATION, 'Choose Analysis Save Location');
        if FILES_SAVE_DESTINATION==0
            FILES_SAVE_DESTINATION= [];
        end
        set(save_file_folder_etext,'string',FILES_SAVE_DESTINATION);
        ANALYSIS_RESULTS_FILE_DESTINATION= fullfile(FILES_SAVE_DESTINATION, ANALYSIS_RESULTS_FOLDER_NAME);
    end
     
    function plotCurvesToggledCallback(hObject, ~)
        EXE_PLOT_CURVES= get(hObject,'value');
    end
    
    function blinksDeltaEditedCallback(hObject, ~)
        input= get(hObject,'string');
        if isStrAValidNonNegativeInteger(input)
        	BLINKS_DELTA= str2double(input);    
        else            
            set(hObject,'string', BLINKS_DELTA);
        end
    end   

    function runAnalysisBtnCallback(~, ~, analysis_func, analysisParametersFigCreator, progress_screen_message_during_analysis)
        if subjects_nr==0
            errordlg(ERROR_MSG_NO_SUBJECTS);  
            return;
        end
        
        TRIAL_ONSET_TRIGGERS= get(trials_onset_triggers_display, 'string')' ;           
        if isempty(TRIAL_ONSET_TRIGGERS)
            errordlg(ERROR_MSG_NO_TRIGGERS);
            return;
        end                
                
        TRIAL_OFFSET_TRIGGERS= get(trials_offset_triggers_display, 'string')' ;           
        TRIAL_REJECTION_TRIGGERS = get(trials_rejection_triggers_display, 'string')' ;                           
        
        if isempty(TRIAL_DURATION)
            errordlg(ERROR_MSG_NO_TRIAL_DUR);
            return;
        end
        
        if isempty(BASELINE)
            errordlg(ERROR_MSG_NO_BASELINE);
            return;
        end
        
        if isempty(BLINKS_DELTA)
            errordlg(ERROR_MSG_NO_BLINKS_DELTA);
            return;
        end       
                        
        if ~createOutputFolders()
            return;
        end                                                                     
                        
        analysis_go= analysisParametersFigCreator();        
        if ~analysis_go    
            return;
        else
            cd(get(gui,'userdata'));
        end
        
        %profile on
        progress_amounts_of_stages= [0.8362, 0.0660, 0.0978];
        stages_names= {'loading data structures', progress_screen_message_during_analysis, 'saving figures'};
        progress_screen= DualBarProgressScreen('Analysis Progress', [0.8, 0.8, 0.8], 0.4, 0.4, progress_amounts_of_stages, stages_names);                         
        %try
            etas= loadEtasSegmentized(progress_screen);            
            [subjects_figs, statistisized_figs, analysis_struct]= analysis_func(etas, progress_screen);
            
            if isempty(analysis_struct)
                progress_screen.addProgress(1);  
                progress_screen.displayMessage('Done.');
                return;
            end            
            save(fullfile(ANALYSIS_RESULTS_FILE_DESTINATION,'analysis_struct.mat'), 'analysis_struct');
                        
            subjects_figs_nr= size(subjects_figs,2)*size(subjects_figs,3);
            if subjects_figs_nr == 0
                progress_screen.addProgress(1);  
                progress_screen.displayMessage('Done.');
                return;
            end            
            for subject_fig_i= 1:size(subjects_figs,2)
                progress_screen.displayMessage(['saving figures for variable #', num2str(subject_fig_i)]);
                for subject_i= 1:size(subjects_figs,3)
                    if ~EXE_PLOT_CURVES                        
                    	set(subjects_figs{2,subject_fig_i,subject_i},'visible','on');                        
                    end                                            
                    savefig(subjects_figs{2,subject_fig_i,subject_i},fullfile(ANALYSIS_RESULTS_FILE_DESTINATION,subjects_figs{1,subject_fig_i,subject_i}));    
                    if ~EXE_PLOT_CURVES                        
                    	set(subjects_figs{2,subject_fig_i,subject_i},'visible','off');                        
                    end
                    
                    progress_screen.addProgress(0.65/subjects_figs_nr);    
                end           
            end
            
            statistisized_figs_nr= size(statistisized_figs,2);
            for statistisized_fig_i=1:statistisized_figs_nr
                if ~isempty(statistisized_figs)
                    if ~EXE_PLOT_CURVES                        
                    	set(statistisized_figs{2,statistisized_fig_i},'visible','on');                        
                    end 
                    savefig(statistisized_figs{2,statistisized_fig_i}, fullfile(ANALYSIS_RESULTS_FILE_DESTINATION,statistisized_figs{1,statistisized_fig_i}));                        
                    if ~EXE_PLOT_CURVES                        
                    	set(statistisized_figs{2,statistisized_fig_i},'visible','off');                        
                    end 
                end
                
                progress_screen.addProgress(0.35/statistisized_figs_nr); 
            end

            %profile viewer;
            progress_screen.displayMessage('Done.');
%         catch exception
%             exception_identifier= strsplit(exception.identifier,':');
%             exception_identifier= exception_identifier{2};
%             if strcmp(exception_identifier, 'BadFileFormat')
%                 progress_screen.displayMessage(['<<ERROR>> ', exception.message, '.']);
%             elseif strcmp(exception_identifier, 'ProgressScreenClosed')
%                 disp('Analysis canceled.');
%             else            
%                 progress_screen.displayMessage(['<<ERROR>> Exception: ', exception.message, '. (tell omer)']);
%                 progress_screen.displayMessage('Stack Trace:');
%                 disp(exception.message);
%                 for call_depth= 1:length(exception.stack)                    
%                     progress_screen.displayMessage(['file: ', exception.stack(call_depth).file]);                                        
%                     progress_screen.displayMessage(['name: ', exception.stack(call_depth).name]);
%                     progress_screen.displayMessage(['line: ', num2str(exception.stack(call_depth).line)]);                    
%                     disp(exception.stack(call_depth));
%                 end
%             end
%         end
    end             

    function loadEDFConversionFileBtnCallback(~, ~)                
        [file_name, path_name, ~] = uigetfile({'*.edf','eye tracker data files'}, 'Choose eyelink data file', CURR_FILE_LOAD_FOLDER, 'MultiSelect', 'on');
        if ~iscell(file_name) && ~ischar(file_name)
            return;
        end
        
        CURR_FILE_LOAD_FOLDER= path_name;                     
        addFilesNamesToFilesListBox(convert_edf_listbox, file_name, path_name);        
    end

    function clearEDFConversionFileBtnCallback(~, ~)                
        clearFileNameFromListBox(convert_edf_listbox);        
    end   
    
    function convertFilesFormatsSaveFolderBtnCallback(~,~)
        FILES_FORMATS_CONVERSION_SAVE_DESTINATION = uigetdir(FILES_FORMATS_CONVERSION_SAVE_DESTINATION, 'Choose Conversion Save Location');
        if FILES_FORMATS_CONVERSION_SAVE_DESTINATION==0
            FILES_FORMATS_CONVERSION_SAVE_DESTINATION= [];
        end
        
        set(convert_edf_save_folder_etext, 'string', FILES_FORMATS_CONVERSION_SAVE_DESTINATION);
    end   
        
    function loadEtaConversionFileBtnCallback(~, ~)        
        [file_name, path_name, ~] = uigetfile({'*.eta','Eye Tracker Analyzer file'}, 'Choose an Eye Tracker Analyzer file', CURR_FILE_LOAD_FOLDER, 'MultiSelect', 'on');
        if ~iscell(file_name) && ~ischar(file_name)
            return;
        end
        
        CURR_FILE_LOAD_FOLDER= path_name;                             
        addFilesNamesToFilesListBox(convert_eta_listbox, file_name, path_name);         
    end

    function clearEtaConversionFileBtnCallback(~, ~)        
        clearFileNameFromListBox(convert_eta_listbox);
    end          

    function convertFilesFormatsBtnCallback(~,~)
        if isempty(get(convert_edf_save_folder_etext,'string'))            
            errordlg(ERROR_MSG_NO_OUTPUT_FOLDER);  
            return;
        else
            cd(get(gui,'userdata'));
        end
        
        if exist(FILES_FORMATS_CONVERSION_SAVE_DESTINATION, 'dir')~=7
            mkdir(FILES_FORMATS_CONVERSION_SAVE_DESTINATION);        
        end
               
        eta_listbox_string= get(convert_eta_listbox, 'string');
        edf_listbox_string= get(convert_edf_listbox, 'string');
        if isempty(eta_listbox_string) && isempty(edf_listbox_string)
            return;
        else
            progress_screen= SingleBarProgressScreen('EDF Conversion Progress', [0.8, 0.8, 0.8], 0.4, 0.4); 
        end                
        
        if ~isempty(eta_listbox_string)
            if ischar(eta_listbox_string)
                eta_listbox_string= {eta_listbox_string};
            end
            
            eta_files_nr= numel(eta_listbox_string);
        else
            eta_files_nr= 0;
        end
        
        if ~isempty(edf_listbox_string)
            if ischar(edf_listbox_string)
                edf_listbox_string= {edf_listbox_string};
            end
            
            edf_files_nr= numel(edf_listbox_string);
        else
            edf_files_nr= 0;
        end
        
        total_files_nr= eta_files_nr + edf_files_nr;                    
                
        if eta_files_nr~=0                                    
            for file_i= 1:eta_files_nr                
                progress_screen.displayMessage(['Extracting: ', eta_listbox_string{file_i}]);
                eta_loaded_struct= load(eta_listbox_string{file_i}, '-mat');                
                if ~isfield(eta_loaded_struct, 'eta') || ~isa(eta_loaded_struct.eta, 'EyeTrackerAnalysisRecord')
                    progress_screen.displayMessage(['failed to extract: ', eta_listbox_string{file_i},'. file is not a valid .eta file!']);
                    continue;
                end
                
                eye_tracking_data_structs= eta_loaded_struct.eta.getEyeTrackerDataStructs(); %#ok<NASGU>
                [~, orig_file_name, ~]= fileparts(eta_listbox_string{file_i});
                save(fullfile(FILES_FORMATS_CONVERSION_SAVE_DESTINATION, [orig_file_name,'.mat']), 'eye_tracking_data_structs'); 
                progress_screen.addProgress(1/total_files_nr);
            end
        end
                                
        if edf_files_nr~=0            
            for file_i=1:edf_files_nr
                progress_screen.displayMessage(['Extracting: ', edf_listbox_string{file_i}]);
                full_file_path= edf_listbox_string{file_i};            
                convertEdfToMat(full_file_path, FILES_FORMATS_CONVERSION_SAVE_DESTINATION);  
                progress_screen.addProgress(1/total_files_nr);
            end
        end
        
        if ~progress_screen.isCompleted();
            progress_screen.updateProgress(1);
        end
        
        progress_screen.displayMessage('Done.');                                   
    end

    function addFilesNamesToFilesListBox(listbox, files_names, path_name)  
        if ~iscell(files_names)
            files_names= {files_names};
        end
        
        for file_i= 1:numel(files_names)                   
            listbox_string= get(listbox, 'string');
            full_file_name= [path_name, files_names{file_i}];
                        
            if numel(listbox_string)==0                
                new_listbox_string= {full_file_name};                            
            elseif any(ismember(full_file_name, listbox_string))
            	continue;
            else
            	new_listbox_string= [listbox_string; {full_file_name}];                
            end

            set(listbox, 'string', new_listbox_string);
            set(listbox, 'value', 1);
        end        
    end
    
    function clearFileNameFromListBox(listbox)
        listbox_string= get(listbox,'string');
        if numel(listbox_string)==0
            return;        
        else
            listbox_string(get(listbox,'value'))= [];
            if any(numel(listbox_string)<get(listbox,'value'))
                set(listbox, 'value', numel(listbox_string));
            end
            set(listbox, 'string', listbox_string);
        end
    end

    function [subjects_figs, statistisized_figs, analysis_struct_with_results]= analyzeMicrosaccades(subjects_etas, progress_screen)        
        saccades_extractor= SaccadesExtractor(subjects_etas);        
        progress_screen.displayMessage('extracting saccades');
        [eye_data_struct, analysis_structs, eyeballing_stats]= saccades_extractor.extractSaccadesByEngbert( ...
            ENGBERT_ALGORITHM_DEFAULTS.vel_vec_type, ...
            ENGBERT_ALGORITHM_DEFAULTS.vel_threshold, ...
            ENGBERT_ALGORITHM_DEFAULTS.amp_lim, ...
            ENGBERT_ALGORITHM_DEFAULTS.amp_low_lim, ...
            ENGBERT_ALGORITHM_DEFAULTS.saccade_dur_min, ...
            ENGBERT_ALGORITHM_DEFAULTS.frequency_max, ...
            ENGBERT_ALGORITHM_DEFAULTS.filter_bandpass, ...
            PERFORM_EYEBALLING, BASELINE, ...
            get(load_etas_for_analysis_display_pane, 'string'), 0.2, progress_screen);    
                
        progress_screen.giveFocus();  
        progress_screen.displayMessage('saving updated eeg files');
        saveUpdatedEegStructs(0.6, progress_screen);
        progress_screen.displayMessage('generating analyses plots');
        reformated_analysis_structs= reformatAnalysisStruct();
        [subjects_figs, statistisized_figs, analysis_struct_with_results]= performMicrosaccadesAnalyses(reformated_analysis_structs, EXE_PLOT_CURVES, [MICROSACCADES_ANALYSIS_PARAMETERS.rate, MICROSACCADES_ANALYSIS_PARAMETERS.amplitudes, MICROSACCADES_ANALYSIS_PARAMETERS.directions, MICROSACCADES_ANALYSIS_PARAMETERS.main_sequence], BASELINE, MICROSACCADES_ANALYSIS_PARAMETERS.smoothing_window_len, TRIAL_DURATION, progress_screen, 0.2);                        
        analysis_struct_with_results.saccades_analsysis_parameters = ENGBERT_ALGORITHM_DEFAULTS;
                
        function saveUpdatedEegStructs(progress_contribution, progress_screen)
            etas_full_paths = get(load_etas_for_analysis_display_pane, 'string');
            for subject_i= 1:subjects_nr
                subject_eta= subjects_etas{subject_i};
                if ~subject_eta.isEegInvolved()
                    progress_screen.addProgress(progress_contribution/subjects_nr);
                    continue;
                end
                segmentized_data_struct= subject_eta.getSegmentizedData(ENGBERT_ALGORITHM_DEFAULTS.filter_bandpass); 
                conds_names= fieldnames(segmentized_data_struct);
                EEG= subject_eta.getEyeTrackerDataStructs();
                EEG= EEG{1};

                %create the blinks channel
                EEG.data(end+1,:)= boolean(zeros(1,length(EEG.times)));
                EEG.chanlocs(end+1).labels='blinks';
                EEG.chanlocs(end).type='EYE';
                EEG.nbchan=EEG.nbchan+1;
                for cond_i= 1:numel(conds_names)
                    curr_cond_segmentized_struct= segmentized_data_struct.(conds_names{cond_i});
                    for trial_i= 1:numel(curr_cond_segmentized_struct)
                        curr_trial_onset= curr_cond_segmentized_struct(trial_i).onset_from_session_start;
                        curr_trial_offset= curr_trial_onset+curr_cond_segmentized_struct(trial_i).trial_dur-1;
                        EEG.data(end, curr_trial_onset:curr_trial_offset)= curr_cond_segmentized_struct(trial_i).blinks;
                    end
                end    

                %create the saccades channel
                EEG.data(end+1,:)=boolean(zeros(1,length(EEG.times)));
                EEG.nbchan=EEG.nbchan+1;
                EEG.chanlocs(EEG.nbchan)=EEG.chanlocs(EEG.nbchan-1);
                EEG.chanlocs(EEG.nbchan).labels='sac onset bool';                 
                analysis_stuct= analysis_structs{subject_i};        
                for cond_i= 1:numel(conds_names)
                    curr_cond_name= conds_names{cond_i};
                    for trial_i= 1:numel(analysis_stuct.(curr_cond_name))
                        curr_trial_saccades_struct= analysis_stuct.(curr_cond_name)(trial_i);
                        for saccade_i= 1:numel(curr_trial_saccades_struct.onsets)        
                            EEG.data(end, curr_trial_saccades_struct.onset_from_session_start(saccade_i))=1;
                            if curr_trial_saccades_struct.user_codes(saccade_i)==Eyeballer.ENUM_ALGORITHM_GENERATED_SACCADE_CODE
                                generator_str= 'algorithm';
                            elseif curr_trial_saccades_struct.user_codes(saccade_i)==Eyeballer.ENUM_USER_GENERATED_SACCADE_CODE
                                generator_str= 'manual';
                            elseif curr_trial_saccades_struct.user_codes(saccade_i)==Eyeballer.ENUM_REJECTED_SACCADE_CODE
                                continue;
                            end                    
                            EEG.event(end+1).type= ['saccade. generator: ', generator_str];
                            EEG.event(end).latency= curr_trial_saccades_struct.onset_from_session_start(saccade_i);
                            EEG.event(end).duration= curr_trial_saccades_struct.durations(saccade_i);
                            EEG.event(end).endtime= curr_trial_saccades_struct.onset_from_session_start(saccade_i) + curr_trial_saccades_struct.offsets(saccade_i) - curr_trial_saccades_struct.onsets(saccade_i);
                            EEG.event(end).sac_amplitude= curr_trial_saccades_struct.amplitudes(saccade_i);
                        end
                    end
                end    
                
                [eta_file_path, eta_file_name, ~] = fileparts(etas_full_paths{subject_i});
                pop_saveset(EEG, 'filename', [eta_file_name, '.set'], 'filepath', eta_file_path);                
                progress_screen.addProgress(1/subjects_nr*progress_contribution)
            end
        end
        
        function reformated_analysis_structs= reformatAnalysisStruct()
            reformated_analysis_structs= cell(1, subjects_nr);
            for subject_i= 1:subjects_nr
                curr_subject_conds_names= fieldnames(analysis_structs{subject_i});
                for cond_i= 1:numel(curr_subject_conds_names)
                    curr_cond_trials_nr= numel( analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}) );
                    if ~isempty(eyeballing_stats)
                        reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).eyeballing_stats= ...
                            eyeballing_stats{subject_i}.(curr_subject_conds_names{cond_i});
                    else
                        reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).eyeballing_stats= [];
                    end
                    
                    reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).number_of_saccades= zeros(1, curr_cond_trials_nr);
                    reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).durations= cell(1, curr_cond_trials_nr);
                    reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).amplitudes= cell(1, curr_cond_trials_nr);
                    reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).directions= cell(1, curr_cond_trials_nr);
                    reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).onsets= cell(1, curr_cond_trials_nr);
                    reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).velocities= cell(1, curr_cond_trials_nr);
                    reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).was_trial_rejected= false(1, curr_cond_trials_nr);
                    
                    max_trial_dur = 0;
                    for trial_i= 1:curr_cond_trials_nr
                        curr_trial_dur = numel(eye_data_struct{subject_i}.(curr_subject_conds_names{cond_i})(trial_i).non_nan_times_logical_vec);
                        if max_trial_dur < curr_trial_dur
                            max_trial_dur = curr_trial_dur;
                        end                                                    
                    end                    
                    reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).logical_onsets_mat= zeros(curr_cond_trials_nr, max_trial_dur);                    
                    reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).vergence.x = NaN(curr_cond_trials_nr, max_trial_dur);
                    reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).vergence.y = NaN(curr_cond_trials_nr, max_trial_dur);
                    reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).non_nan_times= NaN(curr_cond_trials_nr, max_trial_dur);                                        
                    for trial_i= 1:curr_cond_trials_nr
                        curr_trial_saccades_struct= analysis_structs{subject_i}.(curr_subject_conds_names{cond_i})(trial_i);       
                        curr_trial_eye_data_struct = eye_data_struct{subject_i}.(curr_subject_conds_names{cond_i})(trial_i); 
                        if curr_trial_saccades_struct.is_trial_accepted
                            if ~isempty(curr_trial_eye_data_struct) && ~isempty(curr_trial_eye_data_struct.non_nan_times_logical_vec)
                                curr_trial_dur = numel(curr_trial_eye_data_struct.non_nan_times_logical_vec);
                                reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).vergence.x(trial_i, 1:curr_trial_dur)  = ...
                                    curr_trial_eye_data_struct.vergence(:,1)';
                                reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).vergence.y(trial_i, 1:curr_trial_dur) = ...
                                    curr_trial_eye_data_struct.vergence(:,2)';                                
                                reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).non_nan_times(trial_i, 1:curr_trial_dur)= ...
                                    curr_trial_eye_data_struct.non_nan_times_logical_vec';
                            end

                            if ~isempty(curr_trial_saccades_struct.onsets) && any( ~isnan(curr_trial_saccades_struct.onsets) )
                                reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).logical_onsets_mat(trial_i, curr_trial_saccades_struct.onsets)= 1; 
                                reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).logical_onsets_mat(trial_i, curr_trial_dur+1:max_trial_dur) = NaN;
                                reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).number_of_saccades(trial_i)= ...
                                    numel(curr_trial_saccades_struct.onsets);
                                reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).durations{trial_i}= ...
                                    curr_trial_saccades_struct.durations';
                                reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).amplitudes{trial_i}= ...
                                    curr_trial_saccades_struct.amplitudes';                        
                                reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).directions{trial_i}= ...
                                    curr_trial_saccades_struct.directions';
                                reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).onsets{trial_i}= ...
                                    curr_trial_saccades_struct.onsets';
                                reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).velocities{trial_i}= ...
                                    curr_trial_saccades_struct.velocities';
                            end
                        else
                            reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).logical_onsets_mat(trial_i, :) = NaN;
                            reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).number_of_saccades(trial_i)= NaN;                            
                            reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).durations{trial_i}= NaN;                            
                            reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).amplitudes{trial_i}= NaN;                            
                            reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).directions{trial_i}= NaN;                            
                            reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).onsets{trial_i}= NaN;                            
                            reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).velocities{trial_i}= NaN;                            
                            reformated_analysis_structs{subject_i}.(curr_subject_conds_names{cond_i}).was_trial_rejected(trial_i) = true;
                        end
                    end
                end                                
            end                        
        end
    end        

    function analysis_go= microsaccadesParametersFigCreator()
        if ~isempty(MICROSACCADES_PARAMETERS_FIG)
            close(MICROSACCADES_PARAMETERS_FIG);
        end
        
        MICROSACCADES_PARAMETERS_FIG= figure('Visible', 'on', 'name', 'Microsaccades Analysis Parameters', 'NumberTitle', 'off', 'units', 'pixels', ...
            'Position', [main_figure_positions(1:2)+0.25*main_figure_positions(3:4), 0.7*main_figure_positions(3), 0.5*main_figure_positions(4)], ...
            'MenuBar', 'none', ... 
            'DeleteFcn', @microsaccadesParametersFigCloseCallback, ...
            'color', GUI_BACKGROUND_COLOR);
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'text', 'tag', 'c202', 'units', 'normalized', ...
            'String', 'Saccade Amplitude Upper Limit (deg)', ...
            'Position', [0.6008    0.7338    0.2069    0.0918], ...
            'FontSize', 10.0, ...
            'BackgroundColor', GUI_BACKGROUND_COLOR);

        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'edit', 'tag', 'c203', 'units', 'normalized', ...
            'Position', [0.8797     0.73611      0.0673    0.1009], ...
            'string', num2str(ENGBERT_ALGORITHM_DEFAULTS.amp_lim), ...
            'callback', {@amplitudeLimitEditedCallback});
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'text', 'tag', 'c500', 'units', 'normalized', ...
            'String', 'Saccade Amplitude Lower Limit (deg)', ...
            'Position', [0.2542    0.7147    0.2069    0.0918], ...
            'FontSize', 10.0, ...
            'BackgroundColor', GUI_BACKGROUND_COLOR);
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'edit', 'tag', 'c501', 'units', 'normalized', ...
            'Position', [0.4780    0.7361    0.0673    0.1009], ...
            'string', num2str(ENGBERT_ALGORITHM_DEFAULTS.amp_low_lim), ...
            'callback', {@amplitudeLowerLimitEditedCallback});
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'text', 'tag', 'c204', 'units', 'normalized', ...
            'String', 'Velocity Threshold (deg/ms)', ...
            'Position', [0.58778     0.86111      0.2366    0.082474], ...
            'FontSize', 10.0, ...
            'BackgroundColor', GUI_BACKGROUND_COLOR);
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'edit', 'tag', 'c205', 'units', 'normalized', ...
            'Position', [0.8797    0.8611    0.0673    0.1009], ...
            'string', num2str(ENGBERT_ALGORITHM_DEFAULTS.vel_threshold), ...
            'callback', {@velThresholdEditedCallback});        
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'checkbox', 'tag', 'c206', 'units', 'normalized', ...
            'FontSize', 10.0, 'String', 'Save Rate', 'Position', [0.0665     0.87463      0.2828      0.0925], ...
            'BackgroundColor', GUI_BACKGROUND_COLOR, ...
            'value', MICROSACCADES_ANALYSIS_PARAMETERS.rate, ...
            'callback', {@analyzeRateToggledCallback});
        
        smoothing_window_len_edit_text= uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'text', 'tag', 'c2061', 'units', 'normalized', ...
            'String', 'smoothing window length for saccadic rate (ms)', ...
            'Position', [0.2717     0.86106      0.1861      0.0917], ...
            'FontSize', 10.0, ...
            'BackgroundColor', GUI_BACKGROUND_COLOR);
        
        smoothing_window_len_edit= uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'edit', 'tag', 'c2062', 'units', 'normalized', ...
            'Position', [0.4772    0.8611    0.0673    0.1018], ...
            'string', MICROSACCADES_ANALYSIS_PARAMETERS.smoothing_window_len, ...
            'callback', {@smoothingWindowLenEditedCallback}); 
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'checkbox', 'tag', 'c207', 'units', 'normalized', ...
            'FontSize', 10.0, 'String', 'Save Amplitudes', 'Position', [0.0665    0.7721    0.1387    0.0925], ...
            'BackgroundColor', GUI_BACKGROUND_COLOR, ...
            'value', MICROSACCADES_ANALYSIS_PARAMETERS.amplitudes, ...
            'callback', {@analyzeAmplitudesToggledCallback});

        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'checkbox', 'tag', 'c208', 'units', 'normalized', ...
            'FontSize', 10.0, 'String', 'Save Directions', 'Position', [0.0665    0.6683    0.1354    0.0925], ...
            'BackgroundColor', GUI_BACKGROUND_COLOR, ...
            'value', MICROSACCADES_ANALYSIS_PARAMETERS.directions, ... 
            'callback', {@analyzeDirectionsToggledCallback});
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'checkbox', 'tag', 'c400', 'units', 'normalized', ...
            'FontSize', 10.0, 'String', 'Save Main Sequence', 'Position', [0.0665    0.5677    0.2828    0.04], ...
            'BackgroundColor', GUI_BACKGROUND_COLOR, ...
            'value', MICROSACCADES_ANALYSIS_PARAMETERS.main_sequence, ... 
            'callback', {@analyzeMainSeqToggledCallback});
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'checkbox', 'tag', 'c209', 'units', 'normalized', ...
            'FontSize', 10.0, 'String', 'Perform Eyeballing', 'Position', [0.0665    0.4633    0.2828    0.04], ...
            'BackgroundColor', GUI_BACKGROUND_COLOR, ...
            'value', PERFORM_EYEBALLING, ...
            'callback', {@eyeballMicrosaccadesToggledCallback});                        
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'text', 'tag', 'c210', 'units', 'normalized', ...
            'String', 'minimum duration for a saccade (ms)', ...
            'Position', [0.59523     0.49074      0.2313    0.091789], ...
            'FontSize', 10.0, ...
            'BackgroundColor', GUI_BACKGROUND_COLOR);

        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'edit', 'tag', 'c211', 'units', 'normalized', ...
            'Position', [0.8797     0.48842      0.0673    0.1009], ...
            'string', num2str(ENGBERT_ALGORITHM_DEFAULTS.saccade_dur_min), ...
            'callback', {@samplesNumberMinEditedCallback});
        
         uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'text', 'tag', 'c212', 'units', 'normalized', ...
            'String', 'minimum time between saccades (ms)', ...
            'Position', [0.5730    0.6111    0.2682    0.0987], ...
            'FontSize', 10.0, ...
            'BackgroundColor', GUI_BACKGROUND_COLOR);

        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'edit', 'tag', 'c213', 'units', 'normalized', ...
            'Position', [0.8797     0.61343      0.0673    0.1009], ...
            'string', num2str(ENGBERT_ALGORITHM_DEFAULTS.frequency_max), ...
            'callback', {@frequencyMaxEditedCallback});
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'text', 'tag', 'c214', 'units', 'normalized', ...
            'String', 'lowpass filter (hz)', ...
            'Position', [0.60447     0.38426     0.21438    0.047807], ...
            'FontSize', 10.0, ...
            'BackgroundColor', GUI_BACKGROUND_COLOR);

        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'edit', 'tag', 'c215', 'units', 'normalized', ...
            'Position', [0.8797      0.3588      0.0673    0.1009], ...
            'string', num2str(ENGBERT_ALGORITHM_DEFAULTS.filter_bandpass), ...
            'callback', {@filterBandpassEditedCallback});
        
        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'pushbutton', 'tag', 'c216', 'units', 'normalized', ...
            'String', 'Go', ...
            'Position', [0.1949      0.0796      0.2457      0.1965], ...    
            'FontSize', 10.0, ...            
            'callback', {@doneEnteringMicrosaccadesAnalysisParametersBtnCallback});

        uicontrol(MICROSACCADES_PARAMETERS_FIG, 'Style', 'pushbutton', 'tag', 'c217', 'units', 'normalized', ...
            'String', 'Cancel', ...
            'Position', [0.525      0.0796      0.2457      0.1965], ...    
            'FontSize', 10.0, ...
            'callback', {@cancelMicrosaccadesAnalysisBtnCallback});
        
        analysis_go= false;                      
        
        waitfor(MICROSACCADES_PARAMETERS_FIG);
        function amplitudeLimitEditedCallback(hObject, ~)
            input= get(hObject,'string');
            if isStrAPositiveRealNumber(input)
                ENGBERT_ALGORITHM_DEFAULTS.amp_lim= str2double(input);   
            else
                set(hObject,'string', ENGBERT_ALGORITHM_DEFAULTS.amp_lim);
            end
        end        
        
        function amplitudeLowerLimitEditedCallback(hObject, ~)
            input= get(hObject,'string');
            if isStrAValidNonNegativeReal(input)
                ENGBERT_ALGORITHM_DEFAULTS.amp_low_lim= str2double(input);   
            else
                set(hObject,'string', ENGBERT_ALGORITHM_DEFAULTS.amp_low_lim);
            end
        end
        
        function velThresholdEditedCallback(hObject, ~)
            input= get(hObject,'string');
            if isStrAPositiveRealNumber(input)
                ENGBERT_ALGORITHM_DEFAULTS.vel_threshold= str2double(input);   
            else
                set(hObject,'string', ENGBERT_ALGORITHM_DEFAULTS.vel_threshold);
            end
        end        
        
        function analyzeRateToggledCallback(hObject, ~)                        
            MICROSACCADES_ANALYSIS_PARAMETERS.rate= get(hObject,'value');
            if MICROSACCADES_ANALYSIS_PARAMETERS.rate
                set(smoothing_window_len_edit, 'enable', 'on');
                set(smoothing_window_len_edit_text, 'enable', 'on');                
            else
                set(smoothing_window_len_edit, 'enable', 'off');
                set(smoothing_window_len_edit_text, 'enable', 'off');
            end
        end
    
        function smoothingWindowLenEditedCallback(hObject, ~)
            MICROSACCADES_ANALYSIS_PARAMETERS.smoothing_window_len= str2double(get(hObject,'string'));
        end
        
        function analyzeAmplitudesToggledCallback(hObject, ~)
            MICROSACCADES_ANALYSIS_PARAMETERS.amplitudes= get(hObject,'value');        
        end

        function analyzeDirectionsToggledCallback(hObject, ~)
            MICROSACCADES_ANALYSIS_PARAMETERS.directions= get(hObject,'value');        
        end
        
        function analyzeMainSeqToggledCallback(hObject, ~)
            MICROSACCADES_ANALYSIS_PARAMETERS.main_sequence= get(hObject,'value');
        end
        
        function eyeballMicrosaccadesToggledCallback(hObject, ~)
            PERFORM_EYEBALLING= get(hObject,'value');          
        end
        
        function samplesNumberMinEditedCallback(hObject, ~)
            ENGBERT_ALGORITHM_DEFAULTS.saccade_dur_min= str2double(get(hObject,'string'));
        end
        
        function frequencyMaxEditedCallback(hObject, ~)
            ENGBERT_ALGORITHM_DEFAULTS.frequency_max= str2double(get(hObject,'string'));
        end
        
        function filterBandpassEditedCallback(hObject, ~)
            ENGBERT_ALGORITHM_DEFAULTS.filter_bandpass= str2double(get(hObject,'string'));            
        end                                                
        
        function doneEnteringMicrosaccadesAnalysisParametersBtnCallback(~, ~)        
            if ~MICROSACCADES_ANALYSIS_PARAMETERS.rate && ~MICROSACCADES_ANALYSIS_PARAMETERS.amplitudes && ~MICROSACCADES_ANALYSIS_PARAMETERS.directions && ~MICROSACCADES_ANALYSIS_PARAMETERS.main_sequence
                errordlg(ERROR_MSG_NO_CHOSEN_ANALYSES);                
            elseif isempty(ENGBERT_ALGORITHM_DEFAULTS.amp_lim)
                errordlg(ERROR_MSG_NO_AMP_LIM);                
            elseif isempty(ENGBERT_ALGORITHM_DEFAULTS.vel_threshold)
                errordlg(ERROR_MSG_NO_VEL_THRESHOLD);
            else
                analysis_go= true;                
                close(MICROSACCADES_PARAMETERS_FIG);   
                MICROSACCADES_PARAMETERS_FIG= [];
            end
        end

        function cancelMicrosaccadesAnalysisBtnCallback(~, ~)             
            close(MICROSACCADES_PARAMETERS_FIG);           
            MICROSACCADES_PARAMETERS_FIG= [];
        end
        
        function microsaccadesParametersFigCloseCallback(~, ~)                                    
            MICROSACCADES_PARAMETERS_FIG= [];
        end
    end

    function analysis_go= blinksParametersFigCreator()                
        if ~isempty(BLINKS_PARAMETERS_FIG)
            close(BLINKS_PARAMETERS_FIG);
        end
                        
        BLINKS_PARAMETERS_FIG= figure('Visible', 'on', 'name', 'Blinks Analysis Parameters', 'NumberTitle', 'off', 'units', 'pixels', ...
            'Position', [main_figure_positions(1:2)+0.3*main_figure_positions(3:4), 0.47*main_figure_positions(3), 0.3*main_figure_positions(4)], ...
            'MenuBar', 'none', ... 
            'DeleteFcn', @blinksParametersFigCloseCallback, ...
            'color', GUI_BACKGROUND_COLOR);                                                             
        
        uicontrol(BLINKS_PARAMETERS_FIG, 'Style', 'text', 'tag', 'c300', 'units', 'normalized', ...
            'String', 'UNDER CONSTRUCTION - PRESS GO', ...
            'Position', [0.1984    0.5792    0.5816    0.1013], ...
            'FontSize', 10.0, ...
            'BackgroundColor', GUI_BACKGROUND_COLOR);
        
        uicontrol(BLINKS_PARAMETERS_FIG, 'Style', 'pushbutton', 'tag', 'c210', 'units', 'normalized', ...
            'String', 'Go', ...
            'Position', [0.1949      0.0796      0.2457      0.1965], ...    
            'FontSize', 10.0, ...            
            'callback', {@doneEnteringBlinksAnalysisParametersBtnCallback});

        uicontrol(BLINKS_PARAMETERS_FIG, 'Style', 'pushbutton', 'tag', 'c211', 'units', 'normalized', ...
            'String', 'Cancel', ...
            'Position', [0.525      0.0796      0.2457      0.1965], ...    
            'FontSize', 10.0, ...
            'callback', {@cancelBlinksAnalysisBtnCallback});
        
        analysis_go= false;                                
        waitfor(BLINKS_PARAMETERS_FIG);        
        function doneEnteringBlinksAnalysisParametersBtnCallback(~, ~)                   
            analysis_go= true;
            close(BLINKS_PARAMETERS_FIG);
            BLINKS_PARAMETERS_FIG= [];            
        end

        function cancelBlinksAnalysisBtnCallback(~, ~)             
            close(BLINKS_PARAMETERS_FIG);           
            BLINKS_PARAMETERS_FIG= [];
        end
        
        function blinksParametersFigCloseCallback(~, ~)                                    
            BLINKS_PARAMETERS_FIG= [];
        end
    end
    
    function [subjects_figs, statistisized_figs, analysis_struct]= analyzeFixations(subjects_etas, progress_screen)               
        MAX_FIXATION_DUR_COLOR = [1,0,0];
        statistisized_figs = [];
        subjects_figs = [];     
        
        saccades_extractor= SaccadesExtractor(subjects_etas);        
        progress_screen.displayMessage('extracting saccades');
        [~, saccades_structs]= saccades_extractor.extractSaccadesByEngbert( ...
            ENGBERT_ALGORITHM_DEFAULTS.vel_vec_type, ...
            ENGBERT_ALGORITHM_DEFAULTS.vel_threshold, ...
            1000, 1.0, ...
            ENGBERT_ALGORITHM_DEFAULTS.saccade_dur_min, ...
            ENGBERT_ALGORITHM_DEFAULTS.frequency_max, ...
            ENGBERT_ALGORITHM_DEFAULTS.filter_bandpass, ...
            false, [], get(load_etas_for_analysis_display_pane, 'string'), 0.2, progress_screen);    
        
        progress_screen.displayMessage('extracting fixations');
        analysis_struct = cell(1,subjects_nr);
        for subject_i = 1:subjects_nr
            eta = subjects_etas{subject_i}.getSegmentizedData(ENGBERT_ALGORITHM_DEFAULTS.filter_bandpass);
            conds = fieldnames(eta);
            conds_nr = numel(conds);
            analysis_struct{subject_i}.total.fixations_count = 0;
            analysis_struct{subject_i}.total.fixations_durations_mean = [];
            for cond_i = 1:conds_nr
                cond = conds{cond_i};   
                analysis_struct{subject_i}.(cond).saccades = saccades_structs{subject_i}.(cond);
                trials_nr = numel(eta.(cond));
                for trial_i = 1:trials_nr  
                    if isempty(eta.(cond)(trial_i).blinks)
                        progress_screen.addProgress(0.8/(trials_nr*conds_nr*subjects_nr));
                        continue;
                    end
                    d = [(1:eta.(cond)(trial_i).samples_nr)', ...
                        eta.(cond)(trial_i).gazeRight.x', ...
                        eta.(cond)(trial_i).gazeRight.y', ...
                        eta.(cond)(trial_i).gazeLeft.x', ...
                        eta.(cond)(trial_i).gazeLeft.y', ...
                        eta.(cond)(trial_i).blinks'];      
                    
                    fixations_struct = getFixationsFromSaccadesDetection(d, ...
                        saccades_structs{subject_i}.(cond)(trial_i).onsets', ...
                        saccades_structs{subject_i}.(cond)(trial_i).offsets', ...
                        saccades_structs{subject_i}.(cond)(trial_i).amplitudes', ...
                        20, BLINKS_DELTA, false);

                    fixations_nr = numel(fixations_struct.onsets);
                    analysis_struct{subject_i}.total.fixations_count = analysis_struct{subject_i}.total.fixations_count + fixations_nr;
                    fixations_durs_ratios = min(fixations_struct.durations/TRIAL_DURATION,1);
                    analysis_struct{subject_i}.total.fixations_durations_mean = ...
                        [analysis_struct{subject_i}.total.fixations_durations_mean, mean(fixations_struct.durations)];                  
%                     f = figure('name', [fig_title, ' - trial #', num2str(trial_i)], 'MenuBar', 'none', 'numbertitle', 'off', 'units', 'pixels');
%                     for fixation_i = 1:fixations_nr
%                         plot(fixations_coords(fixation_i,1),fixations_coords(fixation_i,2),'.','color',MAX_FIXATION_DUR_COLOR*fixations_durs_ratios(fixation_i),'markersize',20);
%                     end
                    analysis_struct{subject_i}.(cond).fixations(trial_i).fixations_onsets = fixations_struct.onsets;
                    analysis_struct{subject_i}.(cond).fixations(trial_i).fixations_coordinates_left = [fixations_struct.Hpos(:,1), fixations_struct.Vpos(:,1)];
                    analysis_struct{subject_i}.(cond).fixations(trial_i).fixations_coordinates_right = [fixations_struct.Hpos(:,2), fixations_struct.Vpos(:,2)];
                    analysis_struct{subject_i}.(cond).fixations(trial_i).fixations_durations = fixations_struct.durations;                        
                    progress_screen.addProgress(0.8/(trials_nr*conds_nr*subjects_nr));
                end
                
%                 savefig(f, fullfile(ANALYSIS_RESULTS_FILE_DESTINATION, ['sub',num2str(subject_i),cond]));    
%                 set(f,'visible','off');                                
            end                        
        end
        
        function full_files_names = extractFilesNamesFromFolder(path, files_ext)
            files_struct = dir([path, filesep, '*.', files_ext]);
            files_nr = numel(files_struct);
            full_files_names = cell(1, files_nr);
            for file_i = 1:files_nr
                full_files_names{file_i} = [path, filesep, files_struct(file_i).name];
            end
        end
    end

    function [subjects_figs, statistisized_figs, analysis_struct]= analyzePupilsSz(subjects_etas, progress_screen)  
        %===============%
        %=== analyze ===%
        %===============%                                     
        for subject_i= 1:subjects_nr
            curr_subject_data_struct= subjects_etas{subject_i}.getSegmentizedData(ENGBERT_ALGORITHM_DEFAULTS.filter_bandpass);
            if subject_i == 1
                conds_names = fieldnames(curr_subject_data_struct);
                conds_nr = numel(conds_names);
            end            
            for cond_i= 1:conds_nr
                curr_cond= conds_names{cond_i};                                                                
                curr_cond_trials_nr= numel(curr_subject_data_struct.(curr_cond));                            
                analysis_struct.single_subject_analyses{subject_i}.(curr_cond).right_eye = NaN(curr_cond_trials_nr, TRIAL_DURATION);
                nalysis_struct.single_subject_analyses{subject_i}.(curr_cond).left_eye = NaN(curr_cond_trials_nr, TRIAL_DURATION);
                for trial_i= 1:curr_cond_trials_nr
                    if isempty(curr_subject_data_struct.(curr_cond)(trial_i).gazeRight)                
                        continue;
                    end
                    analysis_struct.single_subject_analyses{subject_i}.(curr_cond).right_eye(trial_i, 1:curr_subject_data_struct.(curr_cond)(trial_i).samples_nr) = ...
                        curr_subject_data_struct.(curr_cond)(trial_i).gazeRight.pupil;
                    analysis_struct.single_subject_analyses{subject_i}.(curr_cond).left_eye(trial_i, 1:curr_subject_data_struct.(curr_cond)(trial_i).samples_nr) = ...
                        curr_subject_data_struct.(curr_cond)(trial_i).gazeLeft.pupil;
                    
                    % baseline_period_mean_pupil= mean(mean([curr_subject_data_struct.(curr_cond)(trial_i).gazeRight.pupil(1:BASELINE);...
                    %                                       curr_subject_data_struct.(curr_cond)(trial_i).gazeLeft.pupil(1:BASELINE)],1));
                    % analysis_period_max_pupil= max(mean([curr_subject_data_struct.(curr_cond)(trial_i).gazeRight.pupil((BASELINE+1):TRIAL_DURATION);
                    %                                      curr_subject_data_struct.(curr_cond)(trial_i).gazeLeft.pupil((BASELINE+1):TRIAL_DURATION)],1));                    
                    % analysis_struct.single_subject_analyses{subject_i}.(curr_cond).ratios(trial_i, :)= pupils_szs(trial_i, :)/baseline_period_mean_pupil;                    
                    
                end
               
                progress_screen.addProgress(0.8/(subjects_nr*conds_nr));
            end                        
        end
        
        subjects_figs = [];
        statistisized_figs = [];
        progress_screen.addProgress(0.2);
%         for cond_i = 1:conds_nr
%             analysis_struct.grand_analysis.(conds_names{cond_i}).pupils_szs = [];
%             for subject_i = 1:subjects_nr
%                 analysis_struct.grand_analysis.(conds_names{cond_i}).pupils_szs = ...
%                     [analysis_struct.grand_analysis.(conds_names{cond_i}).pupils_szs; analysis_struct.single_subject_analyses{subject_i}.(curr_cond).pupils_szs];
%             end
%             analysis_struct.grand_analysis.(conds_names{cond_i}).pupils_szs = nanmean(analysis_struct.grand_analysis.(conds_names{cond_i}).pupils_szs, 1);
%         end
%         
%         %======================%
%         %=== generate plots ===%
%         %======================%
%         subjects_figs= cell(2,1,subjects_nr);
%         if EXE_PLOT_CURVES
%             figure_visible_prop= 'on';
%         else
%             figure_visible_prop= 'off';
%         end
%         for subject_i= 1:subjects_nr                        
%             subjects_figs{1,1,subject_i}= ['pupils_dilation_time_line',num2str(subject_i)];
%             subjects_figs{2,1,subject_i}= figure('name','Pupils Dilation Time Line', 'NumberTitle', 'off', 'visible', figure_visible_prop);            
%             for cond_i= 1:conds_nr
%                 plot(-BASELINE + 1 : TRIAL_DURATION - BASELINE, analysis_struct.single_subject_analyses{subject_i}.(conds_names{cond_i}).ratios);
%                 set(gca, 'XLim', [-BASELINE, TRIAL_DURATION - BASELINE]);
%                 xlabel('Time [ms]');
%                 ylabel('Pupils Dilation [?]');
%             end
%             legend(TRIAL_ONSET_TRIGGERS{:});
%             progress_screen.addProgress(0.2/subjects_nr);
%         end
%                         
%         statistisized_figs{1,1}= 'grand_average - pupils_dilation_time_line';
%         statistisized_figs{2,1}= figure('name','grand average: Pupils Dilation Time Line', 'NumberTitle', 'off', 'visible', figure_visible_prop);        
%         for cond_i= 1:conds_nr
%             plot(-BASELINE + 1 : TRIAL_DURATION - BASELINE, analysis_struct.grand_analysis.(conds_names{cond_i}).pupils_szs);
%             set(gca, 'XLim', [-BASELINE, TRIAL_DURATION-BASELINE]);
%             xlabel('Time [ms]');
%             ylabel('Pupils Dilation [?]');        
%         end
%         legend(TRIAL_ONSET_TRIGGERS{:});
    end

    function [subjects_figs, statistisized_figs, analysis_struct]= analyzeBlinks(subjects_etas, progress_screen)
        subjects_figs= [];
        statistisized_figs= [];                    
        blinks_analysis_subjects_nr= numel(subjects_etas);         
        analysis_struct= cell(1, blinks_analysis_subjects_nr);
        progress_screen.displayMessage('analyzing blinks');
        for subject_i= 1:blinks_analysis_subjects_nr
            curr_subject_data_struct= subjects_etas{subject_i}.getSegmentizedData();
            conds_names= fieldnames(curr_subject_data_struct);
            conds_nr= numel(conds_names);
            for cond_i= 1:conds_nr
                curr_cond_name= conds_names{cond_i};
                curr_cond_struct= curr_subject_data_struct.(curr_cond_name);
                analysis_struct{subject_i}.(curr_cond_name)= [];
                trials_nr= numel(curr_cond_struct);                
                for trial_i= 1:trials_nr                    
                    curr_trial_blinks= curr_cond_struct(trial_i).blinks;                                                                    
                    analysis_struct{subject_i}.(curr_cond_name)(trial_i).non_nan_times_logical_vec= ...
                        ~isnan(curr_cond_struct(trial_i).gazeRight.x) & ~isnan(curr_cond_struct(trial_i).gazeRight.y) & ~curr_trial_blinks;
                    non_nan_times_logical_vec_diffed= diff(analysis_struct{subject_i}.(curr_cond_name)(trial_i).non_nan_times_logical_vec);
                    analysis_struct{subject_i}.(curr_cond_name)(trial_i).non_nan_blocks_nr= sum(non_nan_times_logical_vec_diffed==-1) + ~analysis_struct{subject_i}.(curr_cond_name)(trial_i).non_nan_times_logical_vec(1);                    
                end
                progress_screen.addProgress(1/(blinks_analysis_subjects_nr*conds_nr));
            end
        end 
        
        if ~progress_screen.isCompleted()
            progress_screen.updateProgress(1);
        end
    end


    % TODO: <<continue here: test eta.segmentizeData>>
    %TODO: check file existance    
    function etas= loadEtasSegmentized(progress_screen)     
        etas= cell(1,subjects_nr); 
        etas_files_list= get(load_etas_for_analysis_display_pane, 'string');  
        for subject_i= 1:subjects_nr                                     
            progress_screen.displayMessage(['loading subject #', num2str(subject_i), ' .eta file']);                                        
            eta= EyeTrackerAnalysisRecord.load(etas_files_list{subject_i});          
            progress_screen.addProgress(0.5/subjects_nr);
            was_previous_segmentation_loaded= eta.segmentizeData(progress_screen, 0.4/subjects_nr, TRIAL_ONSET_TRIGGERS, TRIAL_OFFSET_TRIGGERS, TRIAL_REJECTION_TRIGGERS, BASELINE, POST_OFFSET_TRIGGERS_SEGMENT, TRIAL_DURATION, BLINKS_DELTA);
            if was_previous_segmentation_loaded
                progress_screen.displayMessage(['previous segmentation loaded for subject #', num2str(subject_i)]);
            else 
                progress_screen.displayMessage(['updating .ETA for subject #', num2str(subject_i)]);
                eta.save(etas_files_list{subject_i});
            end
            progress_screen.addProgress(0.1/subjects_nr);
            etas{subject_i}= eta;
        end                                                
    end
    
    function convertEdfToMat(full_file_path, save_folder)        
        curr_path= pwd;
        cd(READ_EDF_PATH);
        copyfile(full_file_path, pwd);
        [~, edf_file_name]= fileparts(full_file_path);
        eye_tracking_data_mat= readEDF([edf_file_name, '.edf']); %#ok<NASGU>
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
        save(fullfile(save_folder, [edf_file_name, '.mat']), 'eye_tracking_data_mat');
        delete([edf_file_name, '.edf']);
        cd(curr_path);
    end
    
    function has_succeeded= createOutputFolders()
        if (subjects_nr==0)
            has_succeeded= false;
            return;
        end
        
        if areInputFilesPanesEmpty()
            has_succeeded= false;
            errordlg(ERROR_MSG_NO_INPUT_FILES);
            return;
        end
        
        if isOutputFolderEmpty()
            has_succeeded= false;
            errordlg(ERROR_MSG_NO_OUTPUT_FOLDER);  
            return;
        end                
        
        if exist(FILES_SAVE_DESTINATION, 'dir')~=7
            mkdir(FILES_SAVE_DESTINATION);        
        end               
        
        if exist(ANALYSIS_RESULTS_FILE_DESTINATION, 'dir')~=7
            mkdir(ANALYSIS_RESULTS_FILE_DESTINATION);        
        end
        
        has_succeeded= true;
    end   

    function guiCloseCallback(~,~)        
        if ~isempty(MICROSACCADES_PARAMETERS_FIG)
            close(MICROSACCADES_PARAMETERS_FIG);
        end
        
        if ~isempty(BLINKS_PARAMETERS_FIG)
            close(BLINKS_PARAMETERS_FIG);
        end        
    end

    

    %USER INPUT VERIFIERS 
    function res= isStrAValidPositiveInteger(str)
        res= ~isempty(str) && isempty(find(~isstrprop(str,'digit'),1)) && ~strcmp(str(1),'0');
    end

    function res= isStrAValidNonNegativeInteger(str)
        if ~isempty(str) && isempty(find(~isstrprop(str,'digit'),1))
            if numel(str)==1 || ~strcmp(str(1),'0')
                res= true;
            else
                res= false;
            end
        else
            res= false;
        end
    end
    
    function res= isStrAPositiveRealNumber(str)
        non_digit_chars_is= find(~isstrprop(str,'digit'));
        if numel(non_digit_chars_is)==0 || (numel(non_digit_chars_is)==1 && strcmp(str(non_digit_chars_is),'.') && non_digit_chars_is~=1 && non_digit_chars_is~=numel(str))
            res= true;
        else
            res= false;
        end
    end
    
    function res= isStrAValidNonNegativeReal(str)
        if isempty(str)
            res= false;
            return;
        end
        
        non_digit_chars_is= find(~isstrprop(str,'digit'));
        if isStrAValidNonNegativeInteger(str) || ...
                strHasOnlyAValidDecimalPoint(str, non_digit_chars_is) && (non_digit_chars_is==2 || ~strcmp(str(1),'0'))
            res= true;
        else
            res= false;
        end
    end
    
    function res= strHasOnlyAValidDecimalPoint(str, non_digit_chars_is)
        res= numel(non_digit_chars_is)==1 && ...
            strcmp(str(non_digit_chars_is),'.') && ...
            non_digit_chars_is~=1 && ...
            non_digit_chars_is~=numel(str);
    end

    function ret_val= areInputFilesPanesEmpty()
        if subjects_nr==0
           ret_val= true;
        else
            ret_val= false;
        end
    end

    function ret_val= isOutputFolderEmpty()
        if isempty(get(save_file_folder_etext,'string'))
             ret_val= true;
        else
            ret_val= false;
        end
    end
end


