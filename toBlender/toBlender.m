function [sys,x0,str,ts,simStateCompliance] = toBlender(t,x,u,flag,n,cachetimes)

% n: dimension of u
% cachetimes : declare how many times prevous data should be stored 


switch flag,

  %%%%%%%%%%%%%%%%%%
  % Initialization % 
  %%%%%%%%%%%%%%%%%%
  case 0,
    [sys,x0,str,ts,simStateCompliance]=mdlInitializeSizes(n,cachetimes);
  case 1,
    sys=mdlDerivatives(t,x,u);
  case 2,
    sys=mdlUpdate(t,x,u,n,cachetimes);
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

function [sys,x0,str,ts,simStateCompliance]=mdlInitializeSizes(n,cachetimes)

% here,you can change!!!!!!!!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    host = '127.0.0.1';     % ip address is the same of blender

    port = 20208;           % port address is the same of blender
    
    outTime = 5;            % in client, Seconds of waiting to receive data
    
    InputBufferSize=512;    %if you dont know, this is ok
    
    OutputBufferSize=2048;  %if you dont know, this is ok
    
%data name : these must be matched with n 
%      or your all dimension of input data (u) 

    name = [string('a'),string('b'),string('c')];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




% Warring: if you dont understand the below content,
%                $$${dont touch they}$$$

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% dimension of data addition time
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

    if ~isempty(client_tcp)
        if client_tcp.Status
            fclose(client_tcp);
        end
    end
    client_tcp = tcpip(host,port,'NetworkRole','client');
   
    % config inputbuffer that is necessary for fread in simulink.
    % if not exist,fread() will crash!!!
    
    set(client_tcp,'InputBufferSize',InputBufferSize);
    set(client_tcp,'OutputBufferSize',OutputBufferSize);
    set(client_tcp,'Timeout',outTime);
    fopen(client_tcp);
    
%send data names
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if length(name) ~= n
        fprintf('ERRO:your name is not equal to input dimension of u \r');
        fclose(client_tcp);
    end

    str = 'time';
    for item = name
        str = sprintf('%s\\%s',str,item);
    end
    fprintf(client_tcp,str);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%get sample time about frame
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% frameRate: it is equal to blender settings in render panel
    frameRate = tcpRecvInt(2);
    fprintf('frameRate: %d \r',frameRate);
    ts = 1/frameRate;
    
    if rem(ts,0.00001) ~= 0
        fprintf('ERRO:frameRate is bad!!!\rplease set 25 or 50 likely,then let mod(1/frameRate,0.00001) equal 0');
        fclose(client_tcp);
    end
    
    ts  = [ts 0];

% record sample time
    global interval;
    interval = ts(1,1);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    global INFO;
    INFO = [string('ERROR: blender server become bad!!!'),...
            string('OK: blender server work well!!!'),...
            string('END: that tcp transfer data is over!!!')];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    simStateCompliance = 'UnknownSimState';

% end mdlInitializeSizes


function sys=mdlDerivatives(t,x,u)

    sys = [];

% end mdlDerivatives


function sys=mdlUpdate(t,x,u,n,cachetimes)
    global client_tcp;
    global interval;

    if n ~= length(u)
        fprintf('ERRO:settings dimension is not equal to input dimension of u');
        fclose(client_tcp);
    end

% let old cache data in x move down
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    totalDimen = n + 1;
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
        str = formateData(x,n,cachetimes);
        fprintf(client_tcp,str);
        %recv flag from blender server
        flag = tcpRecvInt(1);
        fprintf('at time: %0.6f \r %s \r',t,INFO(flag+1));
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
    %close client
    fclose(client_tcp);
    
    fprintf('Terminate tcp client \r');
    sys = [];

% end mdlTerminate

% read int that denpen on your size.if size=1,it is integer of 0~9
% if size=2,it is integer of 0~99
function value=tcpRecvInt(size)
    global client_tcp;
    a = fread(client_tcp,size,'char');
    b = ascII2int(a);
    value = b;
