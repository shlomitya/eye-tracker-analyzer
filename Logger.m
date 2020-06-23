classdef Logger < handle     
    properties (Access = private)
        fileID;
    end
    
    methods (Access = public)
        function obj = Logger(log_file_full_path)            
            obj.fileID = fopen(log_file_full_path, 'w');
            if obj.fileID == -1
                throw('couldn''t create the log file');
            end
        end
        
        function loge(obj, msg)
            fprintf(obj.fileID, '[ERROR] %s\n', msg);            
        end
        
        function logi(obj, msg)           
            fprintf(obj.fileID, '[INFO]  %s\n', msg);
        end
        
        function delete(obj)
            fclose(obj.fileID);
        end
    end
end

