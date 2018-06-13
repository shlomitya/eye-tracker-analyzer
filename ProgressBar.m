classdef ProgressBar  
    properties (Access= private)
        parent_figure= [];                
        bar_axes= [];
        bar_progress_text= [];
        bar_progress= 0;
        progress_bar= [];
    end
    
    methods
        function obj= ProgressBar(parent_figure, relative_pos, color)
            obj.parent_figure= parent_figure;
            parent_figure_color= get(parent_figure,'color');
            obj.bar_axes= axes('Units','normalized', ...
                               'Position', relative_pos,...
                               'XLim',[0 1],'YLim',[0 1],...
                               'XTick',[],'YTick',[],...
                               'Color', parent_figure_color, 'xcolor', parent_figure_color, 'ycolor', parent_figure_color);
                        
            bar_progress_text_height= relative_pos(4)*0.9;            
            patch([0.0, 0.0, 1.0, 1.0], [0.0, 1.0, 1.0, 0.0], [1 1 1], 'parent', obj.bar_axes);
            obj.progress_bar= patch([0.0, 0.0, 0.0, 0.0], [0.0, 1.0, 1.0, 0.0], color, 'parent', obj.bar_axes);
            obj.bar_progress_text= text(0.475, 0.475, '0%', ...
                                        'parent', obj.bar_axes, ...
                                        'FontSize', 150*bar_progress_text_height); 
            obj.bar_progress= 0;
        end
        
        function obj= updateProgress(obj, new_progress)  
            if abs(new_progress-1.0)<=0.0001
                new_progress=1.0;
            end
            curr_progress_bar_xdata= get(obj.progress_bar, 'XData')';
            set(obj.progress_bar, 'XData', [curr_progress_bar_xdata(1:2), new_progress, new_progress]);
            set(obj.bar_progress_text, 'string', [num2str(100*new_progress, '%5.2f'),'%']);
            
            text_position_adjustment= 0;
            curr_bar_progress_text_pos= get(obj.bar_progress_text, 'position');
            if (obj.bar_progress<0.1 && 0.1<=new_progress && new_progress<1.0) || (0.1<=obj.bar_progress && obj.bar_progress<1.0 && 1.0==new_progress)                   
                text_position_adjustment= -0.0075;
            elseif obj.bar_progress<0.1 && 1.0==new_progress
                text_position_adjustment= -0.015;
            elseif (1.0==obj.bar_progress && 0.1<= new_progress && new_progress<1.0) || (0.1<=obj.bar_progress && obj.bar_progress<1.0 && new_progress<0.1)              
                text_position_adjustment= 0.0075;
            elseif 1.0==obj.bar_progress && new_progress<0.1
                text_position_adjustment= 0.015;
            end
                            
            set(obj.bar_progress_text, 'position', [curr_bar_progress_text_pos(1)+text_position_adjustment, curr_bar_progress_text_pos(2)]);                 
            
            obj.bar_progress= new_progress;            
        end
        
        function obj= addProgress(obj, added_progress)
            new_progress= obj.bar_progress+added_progress;
            obj= obj.update(new_progress);
        end
        
        function progress= getProgress(obj)
            progress= obj.bar_progress;
        end
    end       
end

