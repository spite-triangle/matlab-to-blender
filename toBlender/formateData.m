function [ output_args ] = formateData(x,n,cachetimes)
%DATATOSTR create str from data
%t : time
%x : cache data
%n : length of a group data
%cachetimes : cache times of data
% totalDimen : length(u) + time
%%%  1\2@2\3\@3\7\@4\7\@

totalDimen = n + 1;

dataStrs = '';

for i = 1 :1: cachetimes
    str = '';
    nodeEnd = i*totalDimen;
    nodeStart = nodeEnd - totalDimen + 1;
    
    for j = nodeStart :1: nodeEnd
            str = sprintf('%s%0.6f\\',str,x(j));
    end
 
    dataStrs = sprintf('%s@%s',str,dataStrs);
    assignin('base','str',dataStrs);
end

output_args = dataStrs;

end

