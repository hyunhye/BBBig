############################################################################
#
# DIM - A Direct Interaction Manager for SAGE
# Copyright (C) 2007 Electronic Visualization Laboratory,
# University of Illinois at Chicago
#
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following disclaimer
#    in the documentation and/or other materials provided with the distribution.
#  * Neither the name of the University of Illinois at Chicago nor
#    the names of its contributors may be used to endorse or promote
#    products derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Direct questions, comments etc about SAGE UI to www.evl.uic.edu/cavern/forum
#
# Author: Ratko Jagodic
#        
############################################################################



import pygame
import os, os.path, xmlrpclib, sys, time, socket, ConfigParser
from math import sqrt
from threading import Thread, RLock
from fileSharing import FileShare
import subprocess as sp
import traceback as tb

global DEBUG
DEBUG = False
def setDebugMode(doDebug):
    global DEBUG
    DEBUG = doDebug

# Helper funtion to parse configuration file:
#    given a section and a key, returns the value found
#    or the default value
def getValue(config, section, key, default):
        result = default
        if config.has_section:
                if config.has_option(section, key):
                        if isinstance(result, bool):
                                result = config.getboolean(section, key)
                        elif isinstance(result, float):
                                result = config.getfloat(section, key)
                        elif isinstance(result, int):
                                result = config.getint(section, key)
                        else:
                                result = config.get(section, key)
        return result


# shortcut
opj = os.path.join

sys.path.append( opj(os.environ["SAGE_DIRECTORY"], "bin" ) )
from sagePath import getUserPath, SAGE_DIR, getPath

# commonly used paths
SAVED_STATES_DIR = getUserPath("saved-states")

FS_CONFIG_FILE = getPath("fsManager.conf")


FILE_SERVER_PORT = "8800"

# play sounds or not...
CAN_PLAY_SOUND = False


# types of overlay plugins
UI_PLUGIN = 0  # contains multiple widgets...
WIDGET_PLUGIN = 1  # a single widget, loaded automatically or through UI_PLUGIN

# hyejung
AGENT_PLUGIN = 2  # contains agents...
USER_PLUGIN = 3  # contains user...
SECTION_TYPE = 4
USERINPUT_TYPE = 5
NOT_DEFINED_TYPE = 6 

# configuration file for DIM
DIM_CONFIG = getPath("dim.conf")

# Read the configuration file
config = ConfigParser.ConfigParser()
config.read(DIM_CONFIG)
# parse DIM options
MAX_SCALE = getValue(config,'dim','MAX_SCALE', 8.0)
MIN_SCALE = getValue(config,'dim','MIN_SCALE', 0.5)
PPI       = getValue(config,'dim','PPI', 50.0)
WALL_NAME = getValue(config,'buttons', 'label', "")
MINIMIZE_BAR_SIZE = getValue(config,'dim','MINIMIZE_BAR_SIZE', 0.05)
COLLAPSE_RATIO    = getValue(config,'dim','COLLAPSE_RATIO', 0.05)
SHARED_MIRRORING  = getValue(config,'dim','SHARED_MIRRORING', False)
SHOW_USER_INTERFACE = getValue(config,'dim','SHOW_USER_INTERFACE', True)

del config


# dynamic scaling of widgets
global ENLARGE_WIDGETS
ENLARGE_WIDGETS = False

global ENLARGE_APP_WIDGETS
ENLARGE_APP_WIDGETS = False # do we enlarge app-requested widgets as well?

global ENLARGE_WIDGETS_DIST
ENLARGE_WIDGETS_MAX = 1.5  # make them at most twice the size
ENLARGE_WIDGETS_DIST = 200 # if pointer is < x pixels away, start resizing...
                           # this should really be changed dynamically based
                           # on the display size



# fonts
DEFAULT_FONT = opj(SAGE_DIR, "fonts", "Vera.ttf")
MIN_FONT_SIZE = 8

# font sizes (this is display dependent and will be changed dyamically)
NORMAL = 20  
SMALLER = 16
SMALLEST = 12
LARGER = 24
LARGEST = 28




#-----------------------------------------------------
#       WIDGET GLOBALS
#-----------------------------------------------------


# overlay types (these are same as SAGEDrawObject types)
OVERLAY_POINTER = "pointer"   
OVERLAY_APP = "app"      # app checker
OVERLAY_BUTTON = "button"
OVERLAY_ICON = "icon"
OVERLAY_LABEL = "label"
OVERLAY_MENU = "menu"
OVERLAY_SIZER = "sizer"
OVERLAY_PANEL = "panel"
OVERLAY_THUMBNAIL = "thumbnail"
OVERLAY_ENDURANCE_THUMBNAIL = "enduranceThumbnail"
OVERLAY_SPLITTER = "splitter"
# hyejung
OVERLAY_DIALOG = "dialog"
OVERLAY_CHECKBOX = "checkbox"
OVERLAY_LISTBOX = "listbox"

# graphics format for widgets
IMAGE_FMT = 0
FILE_FMT  = 1

# object size and position types
ABSOLUTE   = 0
NORMALIZED = 1
ALIGNED    = 2

# object alignment
CENTER, LEFT, RIGHT, TOP, BOTTOM, \
LEFT_OUTSIDE, RIGHT_OUTSIDE, TOP_OUTSIDE, BOTTOM_OUTSIDE = range(9)


# btnIDs
BTN_LEFT   = 1
BTN_RIGHT  = 2
BTN_MIDDLE = 3
BTN_UP = 4 
BTN_DOWN = 5 


# arrow IDs
ARROW_UP    = 1
ARROW_DOWN  = 2
ARROW_LEFT  = 3
ARROW_RIGHT = 4


# pointer orientations
BOTTOM_LEFT  = 1
TOP_LEFT     = 2
TOP_RIGHT    = 3
BOTTOM_RIGHT = 4


# z values
BOTTOM_Z = 99999
TOP_Z    = -1
# offsets from appZ
APP_OVERLAY_Z = -0.1  # the app overlay
APP_WIDGET_Z = -0.2   # app-requested widgets
DIM_WIDGET_Z = -0.3  # dim-requested app widgets (such as appClose btn)

Z_CHILD_DIFF = -0.01  # difference in z between children and parent

# z value types
MIN_Z = 0
APP_Z = 1
MAX_Z = 2


# draw order for SAGE
POST_DRAW = 0
INTER_DRAW = 1   # follows the zvalues defined above
PRE_DRAW = 2


# sizer directions
HORIZONTAL = 0
VERTICAL = 1


# the life of a gesture
GESTURE_LIFE_BEGIN  = 1
GESTURE_LIFE_MIDDLE = 2
GESTURE_LIFE_END    = 3

ACCIDENTAL_TOUCH_THRESHOLD = 0 #0.25  # seconds before we actually consider touches


#-----------------------------------------------------
#       EVENTS  (within DIM)
#-----------------------------------------------------

# EVENT TYPES
DEVICE_EVENT    = 1  # position dependent
GENERIC_EVENT   = 2  # sent to everybody that is listening

# device event IDs
EVT_CLICK   = 0
EVT_DOUBLE_CLICK = 1
EVT_MOVE    = 2
EVT_ANALOG1 = 3
EVT_PAN     = 3 # alias
EVT_DRAG    = 3 # alias
EVT_ANALOG2 = 4
EVT_ROTATE  = 4 # alias
EVT_ANALOG3 = 5
EVT_ZOOM    = 5 # alias
EVT_ARROW   = 6
EVT_KEY     = 7
EVT_CUSTOM  = 8
EVT_ENTERED_WINDOW = 9
EVT_LEFT_WINDOW = 10
EVT_DROP        = 11      # for drop target: something has been dropped on it
EVT_BIG_CLICK   = 12   # such as a fist on a touch screen
EVT_FAST_PAN    = 13
EVT_FAST_DRAG   = 13 # alias
EVT_MULTI_TOUCH_HOLD = 14   # multiple fingers touching at the same time... more than 2
EVT_MULTI_TOUCH_SWIPE = 15   # multiple fingers touching at the same time... more than 2
# hyejung
EVT_TWO_FINGERS_SWIPE = 16
EVT_THREE_FINGERS_SWIPE = 17
EVT_MAGNIFY_FINGERS = 18
EVT_ROTATE_FINGERS = 19
# ksy
EVT_SHIFT_PRESSED = 40

# special device events
EVT_CLICK_SPECIAL   = 20
EVT_DOUBLE_CLICK_SPECIAL = 21
EVT_MOVE_SPECIAL    = 22
EVT_ANALOG1_SPECIAL = 23
EVT_PAN_SPECIAL     = 23 # alias
EVT_DRAG_SPECIAL    = 23 # alias
EVT_ANALOG2_SPECIAL = 24
EVT_ROTATE_SPECIAL  = 24 # alias
EVT_ANALOG3_SPECIAL = 25
EVT_ZOOM_SPECIAL    = 25 # alias
EVT_ARROW_SPECIAL   = 26
EVT_KEY_SPECIAL     = 27
EVT_CUSTOM_SPECIAL  = 28
EVT_ENTERED_WINDOW_SPECIAL = 29
EVT_LEFT_WINDOW_SPECIAL = 30

# generic event IDs
GENERIC_EVT        = 50
EVT_APP_INFO       = GENERIC_EVT + 0
EVT_PERF_INFO      = GENERIC_EVT + 1
EVT_NEW_APP        = GENERIC_EVT + 2
EVT_APP_KILLED     = GENERIC_EVT + 3
EVT_Z_CHANGE       = GENERIC_EVT + 4
EVT_OBJECT_INFO    = GENERIC_EVT + 5
EVT_DISPLAY_INFO   = GENERIC_EVT + 6
EVT_OBJECT_REMOVED = GENERIC_EVT + 7
EVT_OBJECT_CHANGED = GENERIC_EVT + 8
EVT_WALL_CLICKED   = GENERIC_EVT + 9
EVT_SCREENSHOT_SAVED = GENERIC_EVT + 10
EVT_NEW_REMOTEAPP    = GENERIC_EVT + 11

# hyejung 
PREV_EVT        = 60
EVT_ANAL_NO_PATTERN = PREV_EVT + 0 
EVT_ANAL_TO_SESSION = PREV_EVT + 1 
EVT_ANAL_DRAG = PREV_EVT + 2 
EVT_ANAL_RESIZE = PREV_EVT + 3 
EVT_ANAL_DRAG_RESIZE = PREV_EVT + 4 
EVT_ANAL_X_LEFT_DIR = PREV_EVT + 5 
EVT_ANAL_X_RIGHT_DIR = PREV_EVT + 6 
EVT_ANAL_Y_UP_DIR = PREV_EVT + 7 
EVT_ANAL_Y_DOWN_DIR = PREV_EVT + 8 


#-----------------------------------------------------
#      WIDGET MESSAGES / EVENTS (sent by DIM)
#-----------------------------------------------------


####  app widget events
EVT_WIDGET  = 100  # when app widget event happens, this is the msg to the app


####  app events (directly to app... like APP_QUIT in sail)
APP_MINIMIZED =  31101


####  widget events
BUTTON_DOWN = 0
BUTTON_UP   = 1
MENU_ITEM_CLICKED = 2
ENDURANCE_THUMBNAIL_RATING = 3
APP_SHARE     =  11  # app share event
APP_SYNC      =  12  # app sync event
APP_QUIT      =  2000 # quit app

####  common events for widgets
####  (events used by more than one widget)
COMMON_WIDGET_EVENTS = 1000   # the base value for those events
SET_LABEL =       COMMON_WIDGET_EVENTS + 1
SHOW_DIM_BOUNDS = COMMON_WIDGET_EVENTS + 2
TEMP_SCALE =      COMMON_WIDGET_EVENTS + 3
SLIDE_DO_HIDE   = COMMON_WIDGET_EVENTS + 4
SELECT_OVERLAY  = COMMON_WIDGET_EVENTS + 5
SET_SIZE        = COMMON_WIDGET_EVENTS + 6
SET_POS         = COMMON_WIDGET_EVENTS + 7


####  global messages to the display
####  (negative values so that they dont clash with widget specific msgs)
SHOW_SIZERS = -1
SET_APP_BOUNDS = -2  # a hack for now really to update all the nodes with the new bounds
SET_INITIAL_BOUNDS = -3  # a hack for now really to update all the nodes with the new bounds


#-----------------------------------------------------
#       GLOBAL ACCESS VARIABLES
#-----------------------------------------------------

def getSAGEIP():
	# default value returned by OS
	fsip = socket.gethostbyname(socket.gethostname())
	# now looking for the real value
	f = open( FS_CONFIG_FILE, "r")
	for line in f:
		line = line.strip()
		if line.startswith('fsManager'):
			fsip = line.split()[2].strip()
	f.close()
	return fsip

# Log - so that everybody can access it
global logObj
logObj = None
def setLog(l):
    global logObj
    logObj = l

def getLog():
    return logObj


# EventManager - so that everybody can access it
global evtMgr
def setEvtMgr(em):
    global evtMgr
    evtMgr = em

def getEvtMgr():
    return evtMgr



# DeviceManager - so that everybody can access it
global devMgr
def setDevMgr(dm):
    global devMgr
    devMgr = dm

def getDevMgr():
    return devMgr



# OverlayManager - so that everybody can access it
global overlayMgr
def setOverlayMgr(om):
    global overlayMgr
    overlayMgr = om

def getOverlayMgr():
    return overlayMgr

# UserManager - so that everybody can access it
global userMgr
def setUserMgr(sm):
    global userMgr
    userMgr = sm

def getUserMgr():
    return userMgr

# SageGate - so that everybody can access it
global sageGate
def setSageGate(q):
    global sageGate
    sageGate = q

def getSageGate():
    return sageGate


# SageData - so that everybody can access it
global sageData
def setSageData(d):
    global sageData
    sageData = d

def getSageData():
    return sageData


# file server - so that everybody can access it
global fileServer
fileServer = None
global fs
fs = False
def getFileServer():
    global fileServer
    global fs
    if not fs:
        fileServer = xmlrpclib.ServerProxy("http://"+str("localhost")+":"+FILE_SERVER_PORT)
        fs = True
        
    return fileServer


# organization - so that everybody can access it
global organization
def setLayoutOrganization(o):
    global organization
    organization = o

def getLayoutOrganization():
    return organization


# browser
global browser
def setBrowser(b):
    global browser
    browser = b 

def getBrowser():
    return browser

# sections - so that everybody can access it
global sections
def setLayoutSections(s):
    global sections
    sections = s

def getLayoutSections():
    return sections

global analyzer
def setAnalyzer(a):
    global analyzer 
    analyzer = a 

def getAnalyzer():
    return analyzer



def setDefaultFontSize(sz):
    global NORMAL, SMALLER, SMALLEST, LARGER, LARGEST
    NORMAL = sz
    SMALLER = int(round(NORMAL*0.7)) 
    SMALLEST = int(round(SMALLER*0.7)) 
    LARGER = int(round(NORMAL*1.3)) 
    LARGEST = int(round(LARGER*1.3)) 


# global scale factor for display size adjustment
globalScale = 1.0    # this is based on HD resolution 1920x1080 display
def setGlobalScale(scale):
    global globalScale
    globalScale = scale

def getGlobalScale():
    return globalScale


# sage server to connect to    
sageServer = "sage.sl.startap.net"
def setSAGEServer(server):
    global sageServer
    sageServer = server

def getSAGEServer():
    return sageServer


# remote sage to start apps on
#sharedHost = None
#sharedHostName = None
sharedHost = []
sharedHostName = []

def setSharedHost(name, server):
    global sharedHost, sharedHostName
    sharedHost = server
    sharedHostName = name

def getSharedHost():
    return sharedHost

def getSharedHostName():
    return sharedHostName


# The slave host
masterSite = None
# Is master/slave mode on
masterSiteMode = False
def setMasterSite(name):
    global masterSite
    print "Set master site ", name
    masterSite = name
    if masterSite == None:
        setMasterSiteMode(False)
def getMasterSite():
    return masterSite
def getMasterSiteMode():
    return masterSiteMode
def setMasterSiteMode(val):
    global masterSiteMode
    masterSiteMode = val


shareObject = None
def getFileShare():
    global shareObject
    if not shareObject:
        shareObject = FileShare()
    return shareObject



# for enlarging the widgets dynamically
def doEnlarge(d):
    global ENLARGE_WIDGETS
    ENLARGE_WIDGETS = d

def getEnlargeWidgets():
    global ENLARGE_WIDGETS
    return ENLARGE_WIDGETS


def doEnlargeAppWidgets(d):
    global ENLARGE_APP_WIDGETS
    ENLARGE_APP_WIDGETS = d

def getEnlargeAppWidgets():
    global ENLARGE_APP_WIDGETS
    return ENLARGE_APP_WIDGETS


def setEnlargeWidgetsThreshold(mult):
    global ENLARGE_WIDGETS_DIST
    if mult > 3.0:
        mult = 3.0
    ENLARGE_WIDGETS_DIST *= mult

def getEnlargeWidgetsThreshold():
    return ENLARGE_WIDGETS_DIST



# for quitting the whole application
global run
run = True
def exitApp():
    global run
    run = False
    getOverlayMgr().removeAllOverlays()

    if getLog():
        getLog().close()
    
def doRun():
    return run


#-----------------------------------------------------
#       MISCELLANEOUS STUFF
#-----------------------------------------------------



#---------------------   Logging  --------------------#

# log events
LOG_STATE_SAVE = "STATE SAVE"  
LOG_STATE_LOAD = "STATE LOAD"

LOG_WINDOW_CHANGE = "WINDOW CHANGE"
LOG_WINDOW_NEW = "WINDOW NEW"
LOG_WINDOW_REMOVE = "WINDOW REMOVE"
LOG_WINDOW_MAXIMIZE = "WINDOW MAXIMIZE"
LOG_WINDOW_MINIMIZE = "WINDOW MINIMIZE"
LOG_WINDOW_RESTORE = "WINDOW RESTORE"
LOG_WINDOW_Z_CHANGE = "WINDOW Z"

LOG_SECTION_NEW = "SECTION NEW"
LOG_SECTION_RESIZE = "SECTION RESIZE"
LOG_SECTION_REMOVE = "SECTION REMOVE"
LOG_SECTION_TILE = "SECTION TILE"
LOG_SECTION_MINIMIZE_ALL = "SECTION MINIMIZE ALL"

LOG_POINTER_NEW = "POINTER NEW"
LOG_POINTER_REMOVE = "POINTER REMOVE"
LOG_POINTER_MOVE = "POINTER MOVE"
LOG_POINTER_CLICK = "POINTER CLICK"
LOG_POINTER_RELEASE= "POINTER RELEASE"
LOG_POINTER_DCLICK = "POINTER DCLICK"

# ksy
LOG_POINTER_HIGHLIGHTT = "POINTER HIGHLIGHTT"
LOG_POINTER_PCLICK = "POINTER PCLICK"

LOG_SCREENSHOT_SAVE = "SAVE SCREENSHOT"

LOG_DIR = getUserPath("log")


# this should be the only way of using the logger...
def writeLog(*args):
    if logObj:
        logObj.write(*args)
        

class Log:
    def __init__(self):
        self.__filename = opj(LOG_DIR, "dim_log_"+time.strftime("%Y%m%d-%H%M%S", time.localtime())+".log")
        self.__logFile = open(self.__filename, "a")
        s = "==="*20
        self.__logFile.write("\n\n\n"+s+"\nLOG TIME: "+time.asctime()+"\n"+str(time.time())+"\n"+s+"\n\n")
        self.__linesWritten = 0
        self.__lock = RLock()  # in case multiple threads call it


    def getLogFilename(self):
        return self.__filename
        
        
    def write(self, *args):
        if self.__logFile.closed:
            return

        try:
            # first assemble the data into a string
            logLine = "[ "+str(time.time())+" ]  "
            for a in args:   
                logLine += " "+str(a)

            # write the data
            logLine += "\n"
            self.__lock.acquire()
            self.__logFile.write(logLine)
            self.__linesWritten += 1

            # flush the data every 20 lines just in case...
            if self.__linesWritten % 40 == 0:
                self.__logFile.flush()
                os.fsync(self.__logFile.fileno())
                self.__linesWritten = 0
            self.__lock.release()
                
        except:
            self.__lock.release()
            tb.print_exc()
        

    def close(self):
        if not self.__logFile.closed:
            self.__logFile.close()




class Color:
    """ rgba is in 0-255 range """
    def __init__(self, r, g, b):
        self.r = r
        self.g = g
        self.b = b

    def toInt(self):
        return (self.r<<16) + (self.g<<8) + self.b




class Bounds:
    """ used in event conversion """
    def __init__(self, left=0, right=0, top=0, bottom=0):
        self.left = left
        self.right = right
        self.top = top
        self.bottom = bottom
        self.setAspectRatio()


    def setAll(self, left, right, top, bottom):
        self.left = int(left)
        self.right = int(right)
        self.top = int(top)
        self.bottom = int(bottom)
        self.setAspectRatio()

    def getAll(self):
        return self.left, self.right, self.top, self.bottom

    def setAspectRatio(self):
        if self.getHeight() != 0:
            self.aspectRatio = self.getWidth() / float(self.getHeight())
        else:
            self.aspectRatio = 1.0

    def getAspectRatio(self):
        return self.aspectRatio

    def getCenterX(self):
        return int(self.right - (self.getWidth() / 2.0))

    def getCenterY(self):
        return int(self.top - (self.getHeight() / 2.0))

    def getWidth(self):
        return self.right - self.left

    def setWidth(self, w):
        self.right = self.left + w
        self.setAspectRatio()

    def getHeight(self):
        return self.top - self.bottom

    def setHeight(self, h):
        self.top = self.bottom + h
        self.setAspectRatio()

    def setSize(self, w, h):
        self.setWidth(w)
        self.setHeight(h)


    def getX(self):
        return self.left

    def getY(self):
        return self.bottom

    def setPos(self, x, y):
        self.setX(x)
        self.setY(y)
        
    def setX(self, x):
        w = self.getWidth()
        self.left = x
        self.right = x + w

    def setY(self, y):
        h = self.getHeight()
        self.bottom = y
        self.top = y + h


    def isIn(self, x, y):
        """ returns True if the (x,y) is in Bounds, False otherwise """
        if self.left <= x and self.right >= x and self.bottom <= y and self.top >= y:
            return True
        else:
            return False


    def getArea(self):
        return self.getWidth() * self.getHeight()
    

    def __str__(self):
        return "%s %s %s %s" % (self.left, self.right, self.top, self.bottom)


    def __eq__(self, other):
        if other == None:
            return False
        else:
            return self.left == other.left and self.right == other.right and \
                   self.top == other.top and self.bottom == other.bottom

        

class ObjPos:
    def __init__(self):
        self.xMargin = self.yMargin = 0
        self.x = self.y = 0
        self.xType = self.yType = NORMALIZED


class ObjSize:
    def __init__(self):
        self.w = self.h = 100
        self.wType = self.hType = ABSOLUTE
        


class XMLElement:
    def __init__(self, name):
        self.name = name
        self.attrs = {}  # key=attr name, value=attr value as string
        self.value = ""  # value of the element
        

# for figuring out the size of the string in pixels
def getTextSize(text, fontSize):

    if fontSize < 4:  fontSize=4
    elif fontSize > 200: fontSize=200

    if not pygame.font.get_init(): pygame.font.init()
    f = pygame.font.Font(DEFAULT_FONT, fontSize)
    return f.size(text)   # returns (w,h)


# distance between two points
def distance(x1,x2,y1,y2):
    return sqrt( (x2-x1)*(x2-x1) + (y2-y1)*(y2-y1) )



def muchGreater(val1, val2, factor=2.0):
    if val1 >= val2 * factor:
        return True
    else:
        return False




def showFile(fullPath, x=100, y=100):
    print "showFile: ", fullPath
    d = getSageData().getDisplayInfo(0)
    dispW, dispH = d.sageW, d.sageH

    path, filename = os.path.split(fullPath)

    fileInfo = getFileServer().GetFileInfo(filename, 0, path)
    if not fileInfo:   #file not supported
        print "\nFileType not supported:", filename 
        return
    (fileType, size, fullPath, appName, params, fileExists) = fileInfo
    if not fileExists:  #file doesnt exist
        print "\nFile doesn't seem to exist:", fullPath 
        return

    if fileType == "image":
        imageWidth = size[0]
        imageHeight = size[1]
        imageAspectRatio = float( imageWidth/imageHeight )

        # figure out if the image is going to fit, if not, reposition and resize it as necessary
        # first resize if necessary
        widthRatio = float(dispW / float(imageWidth))
        heightRatio = float(dispH / float(imageHeight))
        if widthRatio < 1 or heightRatio < 1:
            if widthRatio > heightRatio:   #we'll resize based on height
                resizeRatio = heightRatio
            else:
                resizeRatio = widthRatio   #we'll resize based on width
            imageWidth = int(imageWidth * resizeRatio)
            imageHeight = int(imageHeight * resizeRatio)         

        # now reposition
        cornerX = x  #x - int(imageWidth/2)
        cornerY = y  #y - int(imageHeight/2)

        res = getSageGate().executeApp(appName, pos=(cornerX, cornerY), optionalArgs = fullPath + " " + params)
            
    else:  #for other types
        res = getSageGate().executeApp(appName, pos=(x,y), optionalArgs=params + " " + fullPath)




def saveScreenshot( bounds=None, saveState=True, caller=None ):
    """ saves the screenshot from the SAGE wall... directly from sageDisplayManager
        - if bounds are passed in, it will only save that rectangle
        - button is the gui button to update while
        - caller is the object that called this method
    """

    # name of the state is based on the time
    stateName = time.strftime("%a_%b%d_%Y_%X", time.localtime())

    # are we saving a screenshot of the whole display (a state) or just a section?
    if saveState:
        getSageData().saveState(stateName)
        directory = SAVED_STATES_DIR
    else:
        directory = opj(getFileServer().GetLibraryPath(), "image", "screenshots")

    # save the actual screen captures from the display nodes
    d = getSageData().getDisplayInfo()
    getSageGate().saveScreenshot(directory, int(bounds==None), d.sageW, d.sageH)

    # the image path saved by this function
    screenshot = opj(directory, stateName+".jpg")
    

    # wait for the images and merge them in a thread
    numImages = d.cols * d.rows
    def mergeImages(stateName):
        waitFor = 10.0 # seconds
        startTime = time.time()
        images = []
            
        def getImageNames():
            l = []
            for f in os.listdir(directory):
                if f.startswith("screen") and f.endswith(".jpg"):
                    l.append(opj(directory, f))
            return l
            
        # wait for 10 secs and if images aren't there yet, quit
        time.sleep(1)
        images = getImageNames()
        while (time.time() - startTime) < waitFor:
            time.sleep(1)
            images = getImageNames()
            if (len(images) >= numImages):
                break
        else:
            return  # no images for whatever reason...oh well

        # now merge the images into one
        mergeCmd = "montage "
        for row in range(d.rows-1, -1, -1):
            for col in range(0, d.cols):
                mergeCmd += " "+opj(directory,"screen-%d-%d.jpg" % (col, row))
        mergeCmd += " -tile %dx%d" % (d.cols, d.rows)
        mergeCmd += " -geometry +0+0 " + screenshot
	if hasattr(sp, "check_call"):
		sp.check_call(mergeCmd.split())
	else:
		sp.call(mergeCmd.split())
        mergeCmd = "convert " + screenshot + " -geometry 2048 "+ screenshot
	if hasattr(sp, "check_call"):
		sp.check_call(mergeCmd.split())
	else:
		sp.call(mergeCmd.split())

        # delete individual images
        for f in images:
            os.remove(f)

        if saveState:
            print "State SAVED: ", stateName

        
        # at this point we have the image of the display so
        # grab only the portion we selected (if any)
        if bounds:
            writeLog(LOG_SCREENSHOT_SAVE, bounds)
            cropCmd = "convert "+ screenshot +" -crop "
            cropCmd+= "%dx%d" %(bounds.getWidth(), bounds.getHeight())
            cropCmd+= "+%d+%d " %(bounds.left, d.sageH - bounds.top)
            cropCmd+= screenshot
            if hasattr(sp, "check_call"):
		    sp.check_call(cropCmd.split())
	    else:
		    sp.call(cropCmd.split())
            

        from events import ScreenshotSavedEvent
        getEvtMgr().postEvent(ScreenshotSavedEvent(screenshot, stateName, saveState, bounds, caller))

            
    t = Thread(target=mergeImages, args=(stateName,))
    t.start()
        


#-----------------------------------------------------
#       SOUNDS
#-----------------------------------------------------

ENTERED_WINDOW = "sounds/click1.wav"
MENU_OPEN = "sounds/select1.wav"
MENU_CLOSE = "" #"sounds/select1.wav"
CLICK = "sounds/click2.wav"
MAXIMIZE_WINDOW = "sounds/menu1.wav"
RESTORE_WINDOW = "sounds/menu1.wav"
MENU_ITEM_HIGHLIGHT = "sounds/click1.wav"


# check whether sound can be played at all
if CAN_PLAY_SOUND:
    try:
        pygame.mixer.init()

        # load all the sounds
        sounds = {}
        for snd in [ENTERED_WINDOW, MENU_OPEN, MENU_CLOSE, \
                        CLICK, MAXIMIZE_WINDOW, RESTORE_WINDOW, MENU_ITEM_HIGHLIGHT]:
            sounds[snd] = pygame.mixer.Sound(snd)

    except:
        CAN_PLAY_SOUND = False

def playSound(soundFile):
    if soundFile and CAN_PLAY_SOUND:
        try:
            #s = sounds[soundFile]  #pygame.mixer.Sound(soundFile)
            #s.stop()
            s = pygame.mixer.Sound(soundFile)
            s.stop()
            s.play()
        except:
            pass

