classdef enumDetectionType < double
    enumeration
        Binocular(1), Monocular_L(2), Monocular_R(3)
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

