classdef SingleBarProgressScreen < handle
    properties (Access= 'private')        
        fig= [];        
        progress_bar= [];                                        
        messages_pane= [];
        message_pane_java_internal_edit_control= [];
        msgs_nr= 0;
        close_btn= [];        
        parent_close_btn_callback= [];
        parent_close_btn_callback_args= [];               
        curr_stage_i= 1;
        is_completed= false;
    end
    
    methods
        function obj= SingleBarProgressScreen(figure_title, figure_color, width_proportion, height_proportion, parent_close_btn_callback, parent_close_btn_callback_args)
            if nargin<6            
                parent_close_btn_callback_args= [];
                if nargin<5
                    parent_close_btn_callback= [];
                end
            end
            screen_size= get(0,'monitorpositions');
            screen_size= screen_size(1,3:4);                    
            fig_size= screen_size.*[width_proportion, height_proportion];
            fig_left_edge= (screen_size-fig_size)/2; %[(screen_size(1)-fig_size(1))/2, (screen_size(2)-fig_size(2))/2];
            
            obj.fig= figure('name', figure_title, 'MenuBar', 'none', 'numbertitle', 'off', 'resize', 'off', ...
                            'units', 'pixels', 'Position', [fig_left_edge, fig_size], ...
                            'color', figure_color, 'DeleteFcn', @obj.onFigureCloseCallback);
                        
            uicontrol('parent', obj.fig, 'Style', 'text', 'units', 'normalized', ...
                        'String', 'Overall Progress', ...
                        'Position', [0.2    0.9    0.6    0.075], ...
                        'FontSize', 12.0, ...
                        'BackgroundColor', figure_color);
                                                     
            obj.progress_bar= ProgressBar(obj.fig, [0.1, 0.8, 0.8, 0.1], [0, 1, 0]);                                           
                                                                   
            obj.messages_pane= uicontrol('Style', 'edit', 'units', 'normalized', 'enable', 'on', 'max', 2, 'FontSize', 10, ...                                                
                                         'HorizontalAlignment', 'left', 'Position', [0.1   0.2    0.8    0.55]);                                                         
            
            message_pane_jcp= findjobj(obj.messages_pane); 
            obj.message_pane_java_internal_edit_control= message_pane_jcp.getComponent(0).getComponent(0);
            set(obj.message_pane_java_internal_edit_control,'Editable',0);
            obj.close_btn= uicontrol('parent', obj.fig, 'Style', 'pushbutton', 'units', 'normalized', ...
            'String', 'Cancel', ...
            'Position', [0.35, 0.05, 0.3, 0.1], ...
            'FontSize', 14.0, ...
            'callback', @obj.closeBtnCallback); 
        
            obj.parent_close_btn_callback= parent_close_btn_callback;
            obj.parent_close_btn_callback_args= parent_close_btn_callback_args;            
        end                
        
        function updateProgress(obj, progress)
            if ~ishghandle(obj.fig)
                error('SingleBarProgressScreen:ProgressScreenClosed', 'SingleBarProgressScreen''s window has been closed');   
            end
            
            if obj.is_completed
                error('SingleBarProgressScreen:ProgressMaxed', 'SingleBarProgressScreen was finished and yet was called to update progress');                
            end                        
            
            if abs(progress-1.0)<=0.0001
                progress=1.0;
            end
                        
            obj.progress_bar= obj.progress_bar.updateProgress(progress);            
            
            if progress==1.0              
                set(obj.close_btn, 'string', 'close');                
                obj.is_completed= true;
            end                        
            
            drawnow;
        end
        
        function addProgress(obj, progress)
            obj.updateProgress(obj.progress_bar.getProgress() + progress);                                                          
        end                
        
        function displayMessage(obj, msg)    
            if ~ishghandle(obj.fig) || ~ishghandle(obj.messages_pane)
                error('SingleBarProgressScreen:ProgressScreenClosed', 'SingleBarProgressScreen''s window has been closed');   
            end
            
            messages_pane_string= get(obj.messages_pane,'string');
            if isempty(messages_pane_string)
                messages_pane_string= msg;                
            else                
                messages_pane_string= char(messages_pane_string(1:end-1,:), msg);                
            end
            messages_pane_string= char(messages_pane_string, ' ');
            set(obj.messages_pane,'string',messages_pane_string);
            displayed_msg_len= obj.message_pane_java_internal_edit_control.getDocument.getLength;
            pause(0.1*(floor(displayed_msg_len/3000)+1));
            set(obj.message_pane_java_internal_edit_control,'Editable',1);
            obj.message_pane_java_internal_edit_control.setCaretPosition(displayed_msg_len);            
            set(obj.message_pane_java_internal_edit_control,'Editable',0);
            drawnow;
        end           
        
        function is_completed= isCompleted(obj)
            is_completed= obj.is_completed;
        end
        
        function giveFocus(obj)
            if ~ishghandle(obj.fig)
                error('SingleBarProgressScreen:ProgressScreenClosed', 'SingleBarProgressScreen''s window has been closed');   
            end
            
            figure(obj.fig);
        end
    end 
    
    methods (Access= private)
        function closeBtnCallback(obj, ~, ~)
            close(obj.fig);            
        end       
    
        function onFigureCloseCallback(obj, ~, ~)            
            if ~isempty(obj.parent_close_btn_callback)
                if isempty(obj.parent_close_btn_callback_args)
                    obj.parent_close_btn_callback();           
                else
                    obj.parent_close_btn_callback(obj.parent_close_btn_callback_args);     
                end
            end
        end
    end
end

