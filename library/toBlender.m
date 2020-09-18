function [sys,x0,str,ts,simStateCompliance] = toBlender(t,x,u,flag,cachetimes,host,port,nameStr)

% n: dimension of u
% cachetimes : declare how many times prevous data should be stored 
% name :define data name in the base workplace
% frameRate: it is equal to blender settings in render panel

switch flag,

  %%%%%%%%%%%%%%%%%%
  % Initialization % 
  %%%%%%%%%%%%%%%%%%
  case 0,
    [sys,x0,str,ts,simStateCompliance]=mdlInitializeSizes(cachetimes,host,port,nameStr);
  case 1,
    sys=mdlDerivatives(t,x,u);
  case 2,
    sys=mdlUpdate(t,x,u,cachetimes);
  case 3,
    sys=mdlOutputs(t,x,u);
  case 4,
    sys=mdlGetTimeOfNextVarHit(t,x,u);
  case 9,
    sys=mdlTerminate(t,x,u);
  otherwise
    DAStudio.error('Simulink:blocks:unhandledFlag', num2str(flag));

end

% end sfuntmpl

function [sys,x0,str,ts,simStateCompliance]=mdlInitializeSizes(cachetimes,host,port,nameStr)

% here,you can change!!!!!!!!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%     host = '127.0.0.1';     % ip address is the same of blender
% 
%     port = 20208;           % port address is the same of blender
%     
    outTime = 2;            % in client, Seconds to wait to receive data
    
    InputBufferSize=512;    %if you dont know, this is ok
    
    OutputBufferSize=2048;  %if you dont know, this is ok
    
%data name : these must be matched with n 
%      or your all dimension of input data (u) 

    names = strsplit(nameStr,{' ' , ','});

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Warring: if you dont understand the below content,
%                $$${dont touch they}$$$
    sampleTime = 0;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    n = length(names);
    if n < 1
        n = 1;
    end
    
    % dimension of data plus time
    totalDimen = n + 1;
    sizes = simsizes;
    sizes.NumContStates  = 0;
    sizes.NumDiscStates  = totalDimen*cachetimes;   % temp store size
    sizes.NumOutputs     = 0;   %outputs count
    sizes.NumInputs      = n;  %dynamic inputs count
    sizes.DirFeedthrough = 0;
    sizes.NumSampleTimes = 1;   % at least one sample time is needed
    sys = simsizes(sizes);

% cache size : ( input data + time ) * cachetimes
    x0  = zeros(totalDimen*cachetimes,1); 
    str = [];

% initialize client
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    global client_tcp;
    
    client_tcp = tcpip(char(host),port,'NetworkRole','client');
   
    % config inputbuffer that is necessary for fread in simulink.
    % if not exist,fread() will crash!!!
    
    set(client_tcp,'InputBufferSize',InputBufferSize);
    set(client_tcp,'OutputBufferSize',OutputBufferSize);
    set(client_tcp,'Timeout',outTime);
    
    try
        fopen(client_tcp);
%send data names
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        str = 'time';
        for item = names
            str = sprintf('%s\\%s',str,string(strtrim(item)));
        end
        fprintf(client_tcp,str);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%get sample time about frame
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        frameRate =tcpRecvInt(client_tcp,2);
        fprintf('frameRate: %d \r',frameRate);
        sampleTime = 1/frameRate;

        if rem(sampleTime,0.00001) ~= 0
            errordlg('ERRO:frameRate is bad!!!\rplease set 25 or 50 likely,then let mod(1/frameRate,0.00001) equal 0');
            fclose(client_tcp);
            sampleTime = 0;
        end

% record sample time
        global interval;
        interval = sampleTime;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        global INFO;
        INFO = [string('ERROR: blender server become bad!!!'),...
                string('OK: blender server work well!!!'),...
                string('END: that tcp transfer data is over!!!')];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    catch 
        error('不要紧张，请重启一下blender的sever');
    end
    
    ts  = [sampleTime 0];
    simStateCompliance = 'UnknownSimState';

% end mdlInitializeSizes


function sys=mdlDerivatives(t,x,u)

    sys = [];

% end mdlDerivatives


function sys=mdlUpdate(t,x,u,cachetimes)
    global client_tcp;
    global interval;
    
% let old cache data in x move down
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    totalDimen = length(u) + 1;
    
% let old data move down
    for i = (cachetimes-1):-1:1
        copyNodeEnd = i*totalDimen;
        pasteNodeEnd = copyNodeEnd + totalDimen;

        for j = 0:1:(totalDimen - 1)
            x(pasteNodeEnd - j) = x(copyNodeEnd - j);      
        end
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% place new data (u) from x(2) to x(totalDimen) : n is length(u)
% x(1) is time
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    x(1) = t;
    for i = 2:1:totalDimen
        x(i) = u(i-1);
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    assignin('base','data_update',x);

% formate data to str for sending to blender
% once sending size are cachetimes sets of data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    global INFO;
    if rem((t+interval),interval*(cachetimes)) == 0
        % send data to blender server
        str = formateData(x,length(u),cachetimes);
        fprintf(client_tcp,str);
        %recv flag from blender server
        flag = tcpRecvInt(client_tcp,1);
%         fprintf('at time: %0.6f \r %s \r',t,INFO(flag+1));
        if flag == 0
            fclose(client_tcp);
        end
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    sys = x;
% end mdlUpdate

% mdlOutputs is not a good place to send data, due to loss of once update.
% but in simulink ,this work right.I dont know why 
function sys=mdlOutputs(t,x,u)
    sys = [];
    
% end mdlOutputs


function sys=mdlGetTimeOfNextVarHit(t,x,u)
    fprintf('NextVarHit \r');
    sampleTime = 1;    
    sys = t + sampleTime;

% end mdlGetTimeOfNextVarHit

function sys=mdlTerminate(t,x,u)
    global client_tcp;

    fclose(client_tcp);
    delete(client_tcp);
    clear client_tcp;
    
    fprintf('Terminate tcp client \r');
    sys = [];

% end mdlTerminate

% read int form 0 to 999
function value=tcpRecvInt(client_tcp,size) 
    a = fread(client_tcp,size,'char');
    b = ascII2int(a);
    value = b;
    
function output_args = ascII2int( decimACA )
%ASC2INT formate the ascII code of decimalism array to int
 
value = 0;
    for i = 1:1:length(decimACA)
        temp = decimACA(i) - 48;
        value = value*10 + temp;
    end
output_args = value;


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
