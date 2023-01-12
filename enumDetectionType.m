classdef enumDetectionType < double
    enumeration
        Binocular(0), Monocular_L(1), Monocular_R(2)
    end
        
    methods (Static)
        function str= asstr(detection_type)
            switch (detection_type)
                case enumDetectionType.Binocular    
                    str= 'Binocular';
                case enumDetectionType.Monocular_L
                    str= 'Monocular_L';
                case enumDetectionType.Monocular_R
                    str= 'Monocular_R';
            end
        end
    end
end

