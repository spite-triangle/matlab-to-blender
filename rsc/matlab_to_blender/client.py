import socket as service
import time

def m_client():
    # new a client
    mClient = service.socket(service.AF_INET,service.SOCK_STREAM)
    # link server
    mClient.connect(("127.0.0.1",20208))

    print("send str")
    mClient.send("frame\\to\\meet\\you".encode("utf-8"))
    
    data = mClient.recv(1024)
    print("receive: {}".format(data.decode("utf-8")))

    frame = 0

    for i in range(40):
        print("num: ",i)

        time.sleep(0.1)

        sendData = ""
        for j in range(5):
            sendData = sendData + str(frame) + "\\"+str(j)+"\\9\\"+str(frame*0.1+1)+"\n"
            sendData = sendData + "@"
            frame += 1
            print("frame: ",frame)

        print("{}".format(sendData))
        mClient.send(sendData.encode("utf-8"))
        data = mClient.recv(1024)
        print(data.decode("utf-8"))

    # close client
    mClient.close()

if __name__ == "__main__":
    print('client start!!!')
    m_client()