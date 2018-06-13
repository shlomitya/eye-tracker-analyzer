function []=edf2mat(name)
%input is a struct with filenames to convert, e.g.
%         edf2mat({'s6_1','s6_2'})
names1=name;

for i=1:length(names1)
    
    eval([names1{i},'=' ,'readEDF(','''',names1{i},'.edf','''',')']);
    save(names1{i})
    eval(['clear',' ', names1{i}])
end

