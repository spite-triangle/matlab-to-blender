import bpy
import matlab_to_blender.tcp.server as server
from . import classes

# define server 
mTCPserver = server.TCPServer()

# 在panel中显示数据
class Button_OT_clearData(bpy.types.Operator):
    bl_idname = "triangle.cleardata"
    bl_label = "print data"

    def execute(self, context):
        self.report({"INFO"},"clear data from matlab")

        scene = context.scene
        try:
            names = scene['name']
        except KeyError as e:
            name_exit = False
            self.report({"ERRO"},repr(e))
        else:
            name_exit = True
        if name_exit:
            for name in names:
                del scene[name]
            del scene['name']
            self.report({"INFO"},"clear success")

        return {"FINISHED"}


# start server
class Button_OT_serverStart(bpy.types.Operator):
    global mTCPserver

    bl_idname = "triangle.serverstart"
    bl_label = "start TCP server"

    def execute(self, context):
        # self.report({"INFO"},"start TCP server")

        port = context.scene.tcpPortTri
        IP = context.scene.tcpIpTri
        mTCPserver.initServer(IP,port,context)
        mTCPserver.startServer()

        print("run: ",mTCPserver.isRun,"state : ",mTCPserver.state)
        # 禁用启动start button
        # context.scene.isRunTCP = mTCPserver.isRun
        return {"FINISHED"}

# stop server
class Button_OT_serverStop(bpy.types.Operator):
    global mTCPserver

    bl_idname = "triangle.serverstop"
    bl_label = "stop TCP server"

    def execute(self, context):
        self.report({"INFO"},"stop  TCP server")

        mTCPserver.stopServer()

        # 禁用启动stop button
        # context.scene.isRunTCP = mTCPserver.isRun
        return {"FINISHED"}

# TCP panel
class UIpanel_PT_TCP(bpy.types.Panel):
    bl_label = "TCP"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_context = "objectmode"
    bl_category = "MTB"

    # poll检测
    @classmethod
    def poll(cls, context):
        return (context.object is not None)
    
    # UI绘制
    def draw(self, context):
        global mTCPserver
        layout = self.layout
        scene = context.scene
        isRunTCP = mTCPserver.isRun

        tcpBox = layout.box()
        tcpBox.use_property_split = True # text 与参数分离
        tcpBox.use_property_decorate = False

        tcpBox.alignment = 'RIGHT'
        tcpBox.label(text="TCP Server")
        tcpBox.prop(scene,'tcpIpTri',text="IP:")
        tcpBox.prop(scene,'tcpPortTri',text="Port:")
        tcpBox.prop(scene,'outTime',text='time out:')

        tcpBox.separator()

        row = tcpBox.row()
        row.use_property_split = True # text 与参数分离
        row.alignment = 'RIGHT'
        row.enabled = not isRunTCP
        row.prop(scene,'isUpdateFrame',text='update frame')

        tcpBox.separator()

        row = tcpBox.row()
        # start server button
        subCol = row.column()
        subCol.enabled = not isRunTCP
        subCol.operator("triangle.serverstart",text="start")
        
        # stop server button
        subCol = row.column()
        subCol.enabled = isRunTCP
        subCol.operator("triangle.serverstop",text="stop")

        if mTCPserver.state == 0:
            print('ERRO: ',mTCPserver.info)
            mTCPserver.state = 1


# data panel
class UIpanel_PT_data(bpy.types.Panel):
    bl_label = "Data"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_context = "objectmode"
    bl_category = "MTB"

        # poll检测
    @classmethod
    def poll(cls, context):
        return (context.object is not None)
    
    # UI绘制
    def draw(self, context):
        layout = self.layout
        scene = context.scene

        dataBox = layout.box()
        dataBox.operator("triangle.cleardata",text="clear Data")

        try:
            names = scene['name']
        except KeyError:
            name_exit = False
        else:
            name_exit =True

        # 存储数据的名字
        if name_exit:
            try:
                for name in names:
                    if name in scene.keys():
                        key = '["{}"]'.format(name)
                        dataBox.prop(scene,key)
                    else:
                        break
            except KeyError:
                pass

            

if __name__ == "__main__":
    # unregister all class
    for classe in classes.mClasses:
        bpy.utils.unregister_class(classe)
