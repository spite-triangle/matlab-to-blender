import bpy
from . import classes

# version info
bl_info = {
    "name": "data from matlab to blender",
    "description": "this is a addon that implements the function of data transport from matlab to blender",
    "author": "triangle",
    "version": (0, 0, 2),
    "blender": (2, 80, 0), 
    "location": "View3D",
    "warning": "This addon is still in development.",
    "wiki_url": "https://space.bilibili.com/27206875",
    "category": "Import-Export" }


# initialize RNA properties
def initRNA(scene):
    #port 属性
    scene.tcpPortTri = bpy.props.IntProperty(
        name="Port",
        max=65535,min=5001,
        default=20208,
        description='set port of tcp server')

    # ip
    scene.tcpIpTri = bpy.props.StringProperty(
        default="127.0.0.1",
        description='set address of tcp server')


    # 是否更新当前帧
    scene.isUpdateFrame = bpy.props.BoolProperty(
        default=False,
        description='do you want to let blender update current frame in real-time?'
    )

    # time on server auto shutdown, when no operate
    scene.outTime = bpy.props.IntProperty(
        name='outTime',
        default=100,
        max=1000,min=100,
        description='time on server auto shutdown, when no operate.max=1000 second,min=100 second'
    )


def register():
    # register all class
    for classe in classes.mClasses:
        bpy.utils.register_class(classe)

    # register properties
    initRNA(bpy.types.Scene)


def unregister():
    # unregister all class
    for classe in classes.mClasses:
        bpy.utils.unregister_class(classe)

    # unregister RNA properties
    del bpy.types.Scene.tcpIpTri
    del bpy.types.Scene.tcpPortTri
    del bpy.types.Scene.isUpdateFrame
    del bpy.types.Scene.outTime

if __name__ == "__main__":
    register()