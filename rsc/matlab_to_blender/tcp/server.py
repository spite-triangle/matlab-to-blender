from threading import Thread
import socket 
import time
import bpy
import inspect
import ctypes


# network state

class TCPServer:

    STATE = {
    "ERRO":0,
    "OK":1,
    "END":2,
    "TIMEOUT":0
    }
   


    mThread = None
    service_tcp = None
    service_client = None

    IP = "127.0.0.1"
    port = 20208

    info = ""
    state = STATE['OK']
    isRun = False

    client_timeout = 10
    service_timeout = 100

    context = None #当前上下文
    currentTime = 0  #当前动画的时间
    currentFrame = -1

    dataName = []

    #初始化服务器
    def initServer(self,IP:str ,port: int,context:context):
        print("initserver")
        # 初始化IP,端口
        self.IP = IP
        self.port = port
        self.service_timeout = context.scene.outTime
        # 获取上下文
        self.context = context
        print("initserver:",self.IP,": ",self,port)
        
    # 启动服务器
    def startServer(self):
        try:
            self.isRun = True
            self.mThread = Thread(target=TCPServer.server, args=(self,) )
            self.state = self.STATE['OK']
            self.mThread.start()
            print("startingserver:",self.IP,": ",self.port)
        except Exception as e:
            self.isRun = False
            self.state = self.STATE['ERRO']
            self.info = str(repr(e))
    
    # 停止服务器
    def stopServer(self):
        self.state = ['END']
        self.isRun = False
        if not self.service_tcp == None and not self.service_client == None:
            
            if not self.service_client._closed:
                self.service_client.close()
                print("client close")

            if not self.service_tcp._closed:
                self.service_tcp.close()
                print("listen close")


    # 读取字符数组
    def readData_str(self,service_clien:socket):

        strDatas = ""
        for i in range(4):
            # print("recv loop :",i)
            data = service_clien.recv(1024).decode("utf-8")
            strDatas = strDatas + data
            
            if  len(data) < 1024:
                break

        # 没有值
        if strDatas == "":
            self.state = self.STATE['END']
            return None

        #字符串转化
        strLists = [] #存放字符串 数组 的 数组
        dataBuffer = strDatas.strip("\n").strip("@").split("@")

        for strDatas in dataBuffer:
            strLists.append(strDatas.strip("\\").strip("\\").split("\\"))

            if not self.isRun:
                return None

        self.state = self.STATE['OK']
        return strLists

    # 读取float数组
    def readData_float(self,service_clien:socket):
        strLists = self.readData_str(service_clien)

        if strLists == None:
            return None

        floatLists = [] # 存放float数组 的 数组

        try:
            for strList in strLists:

                floatList = []
                for strTemp in strList:
                    floatList.append(float(strTemp))

                floatLists.append(floatList)

                if not self.isRun:
                    return None

        except Exception as e:
            self.state = self.STATE['ERRO']
            self.isRun = False
            self.info = str(repr(e))

        return floatLists


    # 服务器
    def server(self):
        print ("server start!!!")

        ip = self.IP      # Symbolic name meaning the local host  
        port = self.port           # Arbitrary non-privileged port 

        self.service_tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM) 
        self.service_tcp.bind((ip, port)) 

        # time out
        self.service_tcp.settimeout(self.service_timeout)

        self.service_tcp.listen(1)
        print("listening!!!")
        # change client
        while self.isRun and self.state:
            print("waiting connect.....")

            try:
                self.service_client,addr = self.service_tcp.accept()
                #设置client的等待时间
                self.service_client.settimeout(self.client_timeout)
                self.state = self.STATE['OK']
            except Exception as e:
                self.info = "server time out ,auto shut down: " + str(repr(e))
                self.state = self.STATE["TIMEOUT"]
                break

            self.processData(self.service_client,addr)

        if not self.service_tcp._closed:
            self.service_tcp.close()
            self.isRun = False
            self.state = self.STATE['END']

    # 数据处理
    def processData(self,service_client:socket,addr:str):
        print ('connected: ', addr)

        # 初始
        self.context.scene.frame_start = 0
        self.currentFrame = -1
        self.dataName.clear()

        #ID properties name
        try:
            names = self.readData_str(service_client)
            self.context.scene['name'] = names[0]
            print('data name:',names[0])
            self.dataName = names[0]
        except:
            self.state = self.STATE['ERRO']
        else:
            self.state = self.STATE['OK']

        # 发送frameRate
        sendData = str(self.context.scene.render.fps)
        service_client.send(sendData.encode("utf-8"))
           
        # deal with data
        while self.isRun and self.state:

            # float
            floatlists = self.readData_float(service_client)
            # 终止
            if not floatlists:
                senData = str(self.state)
                service_client.send(senData.encode("utf-8"))
                break

            # updata float ID properties
            if not self.updataIDpropDatas(floatlists):
                senData = str(self.state)
                service_client.send(senData.encode("utf-8"))
                break
            else:
                self.state = self.STATE['OK']

            senData = str(self.state)
            service_client.send(senData.encode("utf-8"))

        if not self.service_client._closed:
            service_client.close()

    # updata IDprop
    def updataIDpropDatas(self,floatLists:list):
        
        names = self.dataName
        for datas in floatLists:
            if not len(datas) == len(names):
                self.info = "the dimension of data names do not match to data !!! "
                self.isRun = False
                return False

            for i in range(len(datas)):
                #记录时间
                if i == 0:
                    self.currentTime = datas[i]
                    self.currentFrame += 1

                    if self.context.scene.isUpdateFrame:
                        self.context.scene.frame_current = self.currentFrame

                key = names[i]
                self.context.scene[key] = datas[i]
                key = '["{}"]'.format(key)

                # 设置关键帧
                if not self.context.scene.keyframe_insert(
                    data_path=key,index=-1,frame=self.currentFrame):
                    self.info = "keyframe fault"
                    self.isRun = False
                    self.state = self.STATE['ERRO']
                    return False 
               
                if not self.isRun:
                    self.state = self.STATE['END']
                    return False

            if not self.isRun:
                self.state = self.STATE['END']
                return False
            
        return True

if __name__ == '__main__':
    strDatas = "1\\2@2\\3\\@6\\7\\@" # 数据格式
    mtcp = TCPServer()
    mtcp.initServer('127.0.0.1',20208,None)
    mtcp.startServer()