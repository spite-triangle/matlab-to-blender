function [ output_args ] = ascII2int( decimACA )
%ASC2INT formate the ascII code of decimalism array to int
 
value = 0;
    for i = 1:1:length(decimACA)
        temp = decimACA(i) - 48;
        value = value*10 + temp;
    end
output_args = value;
end

