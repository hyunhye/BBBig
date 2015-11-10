##########################################################################
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
# Author: Hyejung Hur
#        
############################################################################

from globals import *

class DynamicSpaceManager:
    def __init__(self, parent, bound):
        self.section = parent
        self.bound = bound
        self.fullSpaceList = []
        self.appList = []
        self.largestEmptySpaceList = []
        self.largestEmptySpaceList.append(bound)
        self.totalArea = self.bound.getWidth() * self.bound.getHeight()	

    def updateBound(self, bound):  
        self.bound = bound

    # -----------------------------------
    # free type -> find space 
    def createFullRectangle(self, app):  
        #print "CREATE FULL RECTANGLE... ... ... sail_id=" + str(app.getId())
        #print "app -> " + str(app.left) + " " + str(app.right) + " " + str(app.bottom) + " " + str(app.top)

        aspectRatio = app.aspectRatio

        left = right = top = bottom = 0
        max_area = 0
        found = False

        # because we are looking for best fit. largest area does not guarantee optimal choice
        for space in self.largestEmptySpaceList :
            # ratio = x / y 
            space_width = space.getWidth()
            space_height = space.getHeight()
            app_height = int(space_width / aspectRatio)
            app_width = space_width 
            if app_height > space_height : 
                app_height = space_height
                app_width =  int(space_height * aspectRatio)

            area = app_height * app_width
            if area > max_area : 
                max_area = area

                #left = space.left + int((space_width - app_width)/2.0)
                #bottom = space.bottom + int((space_height - app_height)/2.0)
                left = space.left
                bottom = space.bottom
                # todo? 
                # put into center? - need policy adjustment

                if (app_width < app.getWidth()) or (app_height < app.getHeight()) : 
                    right = left + app_width 
                    top = bottom + app_height
                else :
                    right = left + app.getWidth()
                    top = bottom + app.getHeight()
                found = True 
                break

        if found == True :

            # ???? strange stereo 3D.... it is from sageBaseGate...
            if (top % 2) == 1 :
                top = top - 1
                bottom = bottom - 1

            app.left = left
            app.right = right
            app.top = top 
            app.bottom = bottom 

            app.resizeWindow(app.left, app.right, app.bottom, app.top)

            # sailID???
            self.__addFullRectangle(app.getId(), Bounds(app.left, app.right, app.top, app.bottom))


    def searchExpandRectangle(self, app):
        #print "search expand rectangle.... " 
        #print "before-", len(self.largestEmptySpaceList)
        # delete the rectangle with current app
        self.deleteFullRectangle(app)

        #print "after-delete", len(self.largestEmptySpaceList)
        #print "(", app.left, app.right, app.bottom, app.top, ")"
        #for space in self.largestEmptySpaceList :
        #    print space.left, space.right, space.bottom, space.top

        aspectRatio = app.aspectRatio
        left = right = top = bottom = 0
        max_area = 0
        found = False

        # because we are looking for best fit. largest area does not guarantee optimal choice
        for space in self.largestEmptySpaceList :
            if not (space.left <= app.left and app.right <= space.right and space.bottom <= app.bottom and app.top <= space.top) :
                continue

            space_width = space.getWidth()
            space_height = space.getHeight()
            print "space--- searching... ", space_width, space_height

            # ratio = x / y 
            app_height = int(space_width / aspectRatio)
            app_width = space_width 
            if app_height > space_height : 
                app_height = space_height
                app_width =  int(space_height * aspectRatio)

            area = app_height * app_width
            if area > max_area : 
                max_area = area

                left = space.left + int((space_width - app_width)/2.0)
                bottom = space.bottom + int((space_height - app_height)/2.0)
                # todo? 
                # put into center? - need policy adjustment

                right = left + app_width 
                top = bottom + app_height
                found = True 

        if found == True :
            # ???? strange stereo 3D.... it is from sageBaseGate...
            if (top % 2) == 1 :
                top = top - 1
                bottom = bottom - 1

            app.left = left
            app.right = right
            app.top = top 
            app.bottom = bottom 
            diff = top - bottom  

            app.resizeWindow(app.left, app.right, app.bottom, app.top)
            self.__addFullRectangle(app.getId(), Bounds(app.left, app.right, app.top, app.bottom))


    def addRectangle(self, app):
            self.__addFullRectangle(app.getId(), Bounds(app.left, app.right, app.top, app.bottom))

    def updateFullRectangle(self, app):
        #print "UPDATE FULL RECTANGLE... ... ... sail_id=" + str(app.getId())
        #print "app -> " + str(app.left) + " " + str(app.right) + " " + str(app.bottom) + " " + str(app.top)

        # delete first
        index = 0
        for app_space in self.fullSpaceList : 
            if app.getId() == app_space[0] :
                space = app_space[1]
                if space.left == app.left and space.right == app.right and space.top == app.top and space.bottom == app.bottom : 
                    # later, depth is also needed to be consider
                    #print "same"
                    return

                self.fullSpaceList.pop(index)
                #print "pop and apply previous bounds: " + str(space.left) + " " + str(space.right) + " " + str(space.bottom) + " " + str(space.top)

                if len(self.fullSpaceList) == 0 : 
                    self.largestEmptySpaceList = []
                    self.largestEmptySpaceList.append(self.bound)
                else :
                    self.__removeFullRectangle(Bounds(space.left, space.right, space.top, space.bottom))
                del app_space 
                break		  	
            index += 1
        self.__addFullRectangle(app.getId(), Bounds(app.left, app.right, app.top, app.bottom))


    def deleteFullRectangle(self, app):
        #print "DELETE FULL RECTANGLE... ... ... sail_id=" + str(app.getId())
        #print "app -> " + str(app.left) + " " + str(app.right) + " " + str(app.bottom) + " " + str(app.top)

        index = 0
        for app_space in self.fullSpaceList : 
            if app.getId() == app_space[0] :
                self.fullSpaceList.pop(index)
                del app_space 
                #print "pop"
                break		  	
            index += 1

        window_count = len(self.fullSpaceList)
        if window_count == 0 : 
            self.largestEmptySpaceList = []
            self.largestEmptySpaceList.append(self.bound)
        else :
            self.__removeFullRectangle(Bounds(app.left, app.right, app.top, app.bottom))

        return window_count 

    def clearRectangles(self):
        # clear empty and full space list space
        del self.largestEmptySpaceList
        self.largestEmptySpaceList = []
        self.largestEmptySpaceList.append(self.bound)
        del self.fullSpaceList
        self.fullSpaceList = []

    # -----------------------------------
    # dynamic type -> find space 
    # currently, care about size
    def adjustFullRectangle(self, app, numApp=0, updateFlag=True):
        # consider preference position, size
        # ratio = x / y
        aspectRatio = app.aspectRatio
        max_width = self.bound.getWidth() * app.sizeDesire
        max_height = max_width / aspectRatio
        max_area = max_width * max_height 
        if max_area == 0 :
            return

        expected_area = self.totalArea * app.sizeDesire
        #print "*** expected_area = " + str(expected_area) + " area = " + str(max_area)
        if expected_area < max_area : 
            # need to modify agian
            max_height = self.bound.getHeight() * app.sizeDesire
            max_width = max_height * aspectRatio
            max_area = max_width * max_height 
            #print "*** re-adjusted... expected_area = " + str(expected_area) + " area = " + str(max_area)

        a = sqrt(expected_area / max_area)
        max_width = int(max_width * a)
        max_height = int(max_width / aspectRatio)
        #print "*** a=" + str(a) + " width=" + str(max_width) + " height=" + str(max_height)

        left = right = top = bottom = 0
        max_area = 0
        found = False
        center_x = 0 
        center_y = 0 

        # because we are looking for best fit. largest area does not guarantee optimal choice
        for space in self.largestEmptySpaceList :
            space_width = space.getWidth()
            space_height = space.getHeight()

            if space_width >= max_width and space_height >= max_height :
                # case-1, max_width and max_height does fit in the space
                app_width = max_width
                app_height = max_height
            else :
                if space_width < max_width : 
                    # case-2, max_width is greater than space
                    app_height = int(space_width / aspectRatio)
                    app_width = space_width
                    if app_height > space_height : 
                        # case-2.1, ...
                        app_height = space_height
                        app_width =  int(space_height * aspectRatio)
                else :
                    # case-3,
                    app_width =  int(space_height * aspectRatio)
                    app_height = space_height
                    if app_width > space_width : 
                        # case-3.1, ...
                        app_height = int(space_width / aspectRatio)
                        app_width = space_width

            area = app_height * app_width
            if area > max_area : 
                max_area = area

                left = space.left
                bottom = space.bottom

                #if numApp == 1 : 
                # hyejung
                #left += int((space_width - app_width)/2.0)
                #bottom += int((space_height - app_height)/2.0)
                
                # todo? 
                # put into center? - need policy adjustment
                center_x = space.getCenterX() 
                center_y = space.getCenterY() 

                right = left + app_width 
                top = bottom + app_height
                found = True 

        if found == True :
            # ???? strange stereo 3D.... it is from sageBaseGate...
            if (top % 2) == 1 :
                top = top - 1
                bottom = bottom - 1

            if updateFlag == True :
                app.left = left
                app.right = right
                app.top = top 
                app.bottom = bottom 

                # test mode
                if self.section.dynamicMode == 2 : 
                    if self.section.outSec != None and self.section.inType == USERINPUT_TYPE : 
                        width = right - left
                        height = top - bottom
                        app.left = center_x  - int(width / 2.0)
                        app.right = app.left + width
                        app.bottom = center_y - int(height / 2.0)
                        app.top = app.bottom + height
                else : 
                    app.resizeWindow(app.left, app.right, app.bottom, app.top)

            # sailID???
            self.__addFullRectangle(app.getId(), Bounds(left, right, top, bottom))

    def checkAvailableSpace(self):
        height = 0 
        width = 0 
        for space in self.largestEmptySpaceList :
            if space.left == self.bound.left and space.right == self.bound.right : 
                # check it is in bottom or top 
                if space.bottom == self.bound.bottom or space.top == self.bound.top : 
                    height += (space.top - space.bottom)  
            elif space.bottom == self.bound.bottom and space.top == self.bound.top : 
                if space.left == self.bound.left or space.right == self.bound.right : 
                    width += (space.right - space.left)  
        if width > 0 : 
            width = int(width / 2.0)
        if height > 0 : 
            height = int(height / 2.0)
        return width, height

    # -----------------------------------
    # dynamic mode, but manually moved. 
    def createStaticRectangle(self, app):
        #print "CREATE STATIC RECTANGLE... ... ... sail_id=" + str(app.getId())
        self.__addFullRectangle(app.getId(), Bounds(app.left, app.right, app.top, app.bottom))

    # -----------------------------------
    # MAIN PART : ADD FULL RECTANGLE
    def __addFullRectangle(self, appId, app):
        #print "ADD FULL RECTANGLE... ... ..."

        # validate space
        app = self.__refine(app)

        new_app = [appId, app]
        self.fullSpaceList.append(new_app)

        # have list existing rectangles in largestEmptySpaceList that intersect or are adjacent to current app
        cList = []
        index = 0
        removeList = []
        for space in self.largestEmptySpaceList :
            if not (space.right < app.left or space.left > app.right or space.top < app.bottom or space.bottom > app.top) : 
                cList.append(space)
                removeList.append(index)
            index += 1

        # hj
        # ????? really really need this? or not???
        #index = 0
        #for i in removeList : 
        #    self.largestEmptySpaceList.pop(i-index)
        #    index += 1

        adjacentLESList_left = []
        adjacentLESList_right = []
        adjacentLESList_bottom = []
        adjacentLESList_top = []
        possibleLESList_left = []
        possibleLESList_right = []
        possibleLESList_bottom = []
        possibleLESList_top = []
        for O in cList : 
            # current app : app  = F
            # if O adjacent to any side e of F and external to F
            # ?????? correct or not????
            if app.left == O.right : 
                adjacentLESList_left.append(O)
            elif app.right == O.left : 
                adjacentLESList_right.append(O)
            elif app.top == O.bottom : 
                adjacentLESList_top.append(O)
            elif app.bottom == O.top : 
                adjacentLESList_bottom.append(O)
            else : 
                self.largestEmptySpaceList.remove(O)
                # class Bounds - > left, right, top, bottom
                if O.left < app.left :      # top left
                    possibleLESList_left.append(Bounds(O.left, app.left, O.top, O.bottom))
                if O.right > app.right :    # bottom right
                    possibleLESList_right.append(Bounds(app.right, O.right, O.top, O.bottom))
                if O.bottom < app.bottom :  # bottom left 
                    possibleLESList_bottom.append(Bounds(O.left, O.right, app.bottom, O.bottom))
                if O.top > app.top :        # top right 
                    possibleLESList_top.append(Bounds(O.left, O.right, O.top, app.top))

        index = 0 
        possibleLESList = []
        for P in possibleLESList_left : 
            # P not enclosed by any space in adjacentLESList[D] or any other space in possible LESList[D]
            if self.__isNotInClosed(P, index, possibleLESList_left, adjacentLESList_left) == True :
                possibleLESList.append(P)
            index += 1 
        index = 0 
        for P in possibleLESList_right : 
            if self.__isNotInClosed(P, index, possibleLESList_right, adjacentLESList_right) == True :
                possibleLESList.append(P)
            index += 1 
        index = 0 
        for P in possibleLESList_top : 
            if self.__isNotInClosed(P, index, possibleLESList_top, adjacentLESList_top) == True :
                possibleLESList.append(P)
            index += 1 
        index = 0 
        for P in possibleLESList_bottom : 
            if self.__isNotInClosed(P, index, possibleLESList_bottom, adjacentLESList_bottom) == True :
                possibleLESList.append(P)
            index += 1 

        index = 0
        for P in possibleLESList : 
            #if self.__isNotInClosed(P, index, possibleLESList, None): 
            #    if self.__validate(P) :
            self.largestEmptySpaceList.append(P)
            #print "append..." + str(P.left) + " " + str(P.right) + " " + str(P.bottom)  + " " + str(P.top)
            index += 1

        # debug
        #'''
        #print "1-(add full rectangle)--------------------------------------- full space (index, width, hegith, area)"
        index = 0	
        for app_space in self.fullSpaceList :
            space = app_space[1]		  	
            #print "(" + str(index) + ") " + str(space.left) + " " + str(space.right) + " " + str(space.bottom) + " " + str(space.top)
            index += 1 	
        #print "1-(add full rectangle)--------------------------------------- empty space (index, width, hegith, area)"
        index = 0	
        for space in self.largestEmptySpaceList :
            area = space.getWidth() * space.getHeight()
            #print "(" + str(index) + ") " + str(space.left) + " " + str(space.right) + " " + str(space.bottom) + " " + str(space.top) + " : area=" + str(area)
            index += 1 	
        #print "--------------------------------------- end"
        #'''

        del possibleLESList
        del possibleLESList_left
        del possibleLESList_right
        del possibleLESList_bottom
        del possibleLESList_top
        del adjacentLESList_left
        del adjacentLESList_right
        del adjacentLESList_bottom
        del adjacentLESList_top
        del removeList
        del cList 


    def __removeFullRectangle(self, app):
        #print "REMOVE FULL RECTANGLE... ... ..."

        # validate space
        app = self.__refine(app)

        # (step-1) create new space manager S to represent area of F 
        S = DynamicSpaceManager(None, Bounds(app.left, app.right, app.top, app.bottom))
        # get all full-space rectangles that intersect F and add them to S   
        for app_space in self.fullSpaceList : 
            space = app_space[1]		  	
            if not (space.right <= app.left  or app.right <= space.left or space.top <= app.bottom or app.top <= space.bottom) : 	 
                S.__addFullRectangle(-1, Bounds(space.left, space.right, space.top, space.bottom))
                #print "space(intersect) -> " + str(space.left) + " " + str(space.right) + " " + str(space.bottom) + " " + str(space.top)

        # (step-2) adjacentEmptySpaceList = all largest empty-space rectangles adjacent to and external F
        adjacentEmptySpaceList = []
        for O in self.largestEmptySpaceList :
            if app.left == O.right or app.right == O.left or app.top == O.bottom or app.bottom == O.top :  
                adjacentEmptySpaceList.append(O)
        # there are the only largest empty spaces external to F that need to be processed in this algorith. 
        #print "adjacentEmptySpaceList length = " + str(len(adjacentEmptySpaceList))

        # (step-3) ?? edge ?? : for each edge e in left, right,  bottom, top
        # adjList = spaces in possibleLESList adjacent to edge e of F
        # possibleLESList is temporary list of empty spaces that could possibly be largest empty spaces; initialize it to the empty space in S
        possibleLESList = S.largestEmptySpaceList
        #print "possibleLESList length = " + str(len(possibleLESList))
        adjList_left = []
        # left
        for O in possibleLESList :
            if O.right == app.left :  # modified
                adjList_left.append(O)
        #print "<left> ... " + str(len(adjList_left))
        for R in adjList_left :
            #print "R = " + str(R.left) + " " + str(R.right) + " " + str(R.bottom) + " " + str(R.top)
            for P in adjacentEmptySpaceList :
                #print "P = " + str(P.left) + " " + str(P.right) + " " + str(P.bottom) + " " + str(P.top)
                # if P adjacent to edge e of R and edge e of F : 
                if P.right == R.left and P.right == app.left: # modified
                    possibleLESList.append(self.__combineSpaces(R,P))					 
            #if any rectangle in possibleLESList encloses R : 
            if self.__isInClosed(R, possibleLESList) : 
                possibleLESList.remove(R)
        del adjList_left

        # right 
        adjList_right = []
        for O in possibleLESList :
            if O.left == app.right : # modified
                adjList_right.append(O)
        #print "<right> ... " + str(len(adjList))
        for R in adjList_right :
            #print "R = " + str(R.left) + " " + str(R.right) + " " + str(R.bottom) + " " + str(R.top)
            for P in adjacentEmptySpaceList :
                #print "P = " + str(P.left) + " " + str(P.right) + " " + str(P.bottom) + " " + str(P.top)
                # if P adjacent to edge e of R and edge e of F : 
                if P.left == R.right and P.left == app.right : # modified
                    possibleLESList.append(self.__combineSpaces(R,P))					 
            if self.__isInClosed(R, possibleLESList) : 
                possibleLESList.remove(R)
        del adjList_right

        # top
        adjList_top = []
        for O in possibleLESList :
            if O.bottom == app.top :
                adjList_top.append(O)
        #print "<top> ... " + str(len(adjList))
        for R in adjList_top :
            #print "R = " + str(R.left) + " " + str(R.right) + " " + str(R.bottom) + " " + str(R.top)
            for P in adjacentEmptySpaceList :
                #print "P = " + str(P.left) + " " + str(P.right) + " " + str(P.bottom) + " " + str(P.top)
                # if P adjacent to edge e of R and edge e of F : 
                if P.bottom == R.top and P.bottom == app.top :
                    possibleLESList.append(self.__combineSpaces(R,P))					 
            if self.__isInClosed(R, possibleLESList) : 
                possibleLESList.remove(R)
        del adjList_top

        # bottom 
        adjList_bottom = []
        for O in possibleLESList :
            if O.top == app.bottom :
                adjList_bottom.append(O)
        #print "<bottom> ... " + str(len(adjList))
        for R in adjList_bottom :
            #print "R = " + str(R.left) + " " + str(R.right) + " " + str(R.bottom) + " " + str(R.top)
            for P in adjacentEmptySpaceList :
                #print "P = " + str(P.left) + " " + str(P.right) + " " + str(P.bottom) + " " + str(P.top)
                # if P adjacent to edge e of R and edge e of F : 
                if P.top == R.bottom and P.top == app.bottom :
                    possibleLESList.append(self.__combineSpaces(R,P))					 
            if self.__isInClosed(R, possibleLESList) : 
                possibleLESList.remove(R)
        del adjList_bottom

        # (step-4) 
        #print "<step 4> merge...."
        for R in adjacentEmptySpaceList : 
            if self.__isInClosed(R, possibleLESList) :
                # need to check - is properly removed or not 
                self.largestEmptySpaceList.remove(R)
                #print "remove..." + str(R.left) + " " + str(R.right) + " " + str(R.bottom)  + " " + str(R.top)
        index = 0
        for R in possibleLESList : 
            if self.__isNotInClosed(R, index, possibleLESList, None): 
                if self.__validate(R) :
                    self.largestEmptySpaceList.append(R)
                    #print "append..." + str(R.left) + " " + str(R.right) + " " + str(R.bottom)  + " " + str(R.top)
            index += 1

        # debug
        '''
        print "(remove full rectangle)--------------------------------------- full space (index, width, hegith, area)"
        index = 0	
        for app_space in self.fullSpaceList :
            space = app_space[1]		  	
            print "(" + str(index) + ") " + str(space.left) + " " + str(space.right) + " " + str(space.bottom) + " " + str(space.top)
            index += 1 	
        print "(remove full rectangle)--------------------------------------- empty space (index, width, hegith, area)"
        index = 0	
        for space in self.largestEmptySpaceList :
            area = space.getWidth() * space.getHeight()
            print "(" + str(index) + ") " + str(space.left) + " " + str(space.right) + " " + str(space.bottom) + " " + str(space.top) + " : area=" + str(area)
            index += 1 	
        print "--------------------------------------- end"
        '''

        # ?????
        del possibleLESList 
        del adjacentEmptySpaceList 
        del S


    def __isInClosed(self, P, possibleLESList):
        for possible in possibleLESList : 
            if possible.left == P.left and P.right == possible.right and possible.bottom == P.bottom and P.top == possible.top :
                continue
            elif possible.left <= P.left and P.right <= possible.right and possible.bottom <= P.bottom and P.top <= possible.top :
                return True 
        return False 

    def __isNotInClosed(self, P, i, possibleLESList, adjacentLESList):
        #print "not in closed.... " + str(len(possibleLESList)) 
        j = 0 
        for possible in possibleLESList : 
            if i != j : 
                #print P.left, P.right, P.bottom, P.top
                #print possible.left, possible.right, possible.bottom, possible.top
                if possible.left <= P.left and P.right <= possible.right and possible.bottom <= P.bottom and P.top <= possible.top :
                    return False					
            j += 1
        if adjacentLESList != None :		
            for adjacent in adjacentLESList : 
                if adjacent.left <= P.left and P.right <= adjacent.right and adjacent.bottom <= P.bottom and P.top <= adjacent.top :
                    return False					
        return True

    def __refine(self, space):
        if self.bound.left > space.left :
            space.left = self.bound.left
        if self.bound.right < space.right :
            space.right = self.bound.right
        if self.bound.bottom > space.bottom :
            space.bottom = self.bound.bottom
        if self.bound.top < space.top :
            space.top = self.bound.top
        return space

    def __validate(self, space):
        if space.getHeight() <= 1 : 
            return False
        if space.left < 0 or space.right < 0 or space.bottom < 0 or space.top < 0 :
            return False
        return True

    def __min(self, a, b):
        if a < b :
            return a
        return b

    def __max(self, a, b):
        if a > b :
            return a
        return b

    def __combineSpaces(self, rec1, rec2):  
        if rec1.left == rec2.right or rec1.right == rec2.left :
            #tmp = Bounds(self.__min(rec1.left, rec2.left), self.__max(rec1.right, rec2.right), self.__min(rec1.top, rec2.top), self.__max(rec1.bottom, rec2.bottom)) 
            #print "combine space 1:" + str(tmp.left) + " " + str(tmp.right) + " " + str(tmp.bottom) + " " + str(tmp.top)

            return Bounds(self.__min(rec1.left, rec2.left), self.__max(rec1.right, rec2.right), self.__min(rec1.top, rec2.top), self.__max(rec1.bottom, rec2.bottom)) 
        elif rec1.bottom == rec2.top or rec1.top == rec2.bottom :
            #tmp = Bounds(self.__max(rec1.left, rec2.left), self.__min(rec1.right, rec2.right), self.__max(rec1.top, rec2.top), self.__min(rec1.bottom, rec2.bottom)) 
            #print "combine space 2:" + str(tmp.left) + " " + str(tmp.right) + " " + str(tmp.bottom) + " " + str(tmp.top)

            return Bounds(self.__max(rec1.left, rec2.left), self.__min(rec1.right, rec2.right), self.__max(rec1.top, rec2.top), self.__min(rec1.bottom, rec2.bottom)) 
        return None


    def getApp(self, app, windows, Dir):
        minW = app.right - app.left
        minH = app.top - app.bottom
        for space in windows :
            width = space.right - space.left
            height = space.top - space.bottom
            if minW > width : 
                minW = width 
            if minH > height :
                minH = height

        index_range_list = []
        for space in windows :
            if space == app : continue 
            i_begin = space.left / minW  
            i_end = space.right / minW  
            j_begin = space.bottom / minH  
            j_end = space.top / minH  
            l = [space.getId(), i_begin, i_end, j_begin, j_end]
            index_range_list.append(l)

        i_begin = app.left / minW  
        i_end = app.right / minW  
        j_begin = app.bottom / minH  
        j_end = app.top / minH  
        # right... 
        app_list = [] 
        if Dir == LEFT : 
            idx = 0
            for app_space in index_range_list :
                # find app on right
                if (app_space[3] >= j_begin and app_space[3] <= j_end) or (app_space[4] >= j_begin and app_space[4] >= j_end) :
                    if app_space[2] <= i_begin :  
                        temp_index = 0
                        added = False 
                        for i in app_list : 
                            temp_app = index_range_list[i] 
                            if temp_app[2] < app_space[2] :    
                                app_list.insert(temp_index, idx)
                                added = True 
                                break
                            temp_index += 1 
                        if added == False :
                            app_list.append(idx)
                idx += 1 
        elif Dir == RIGHT : 
            idx = 0
            for app_space in index_range_list :
                # find app on right
                if (app_space[3] >= j_begin and app_space[3] <= j_end) or (app_space[4] >= j_begin and app_space[4] >= j_end) :
                    if app_space[1] >= i_end :  
                        temp_index = 0
                        added = False 
                        for i in app_list : 
                            temp_app = index_range_list[i] 
                            if temp_app[1] > app_space[1] :    
                                app_list.insert(temp_index, idx)
                                added = True 
                                break
                            temp_index += 1 
                        if added == False :
                            app_list.append(idx)
                idx += 1 
        elif Dir == TOP : 
            idx = 0
            for app_space in index_range_list :
                # find app on right
                if (app_space[1] >= i_begin and app_space[1] <= i_end) or (app_space[2] >= i_begin and app_space[2] >= i_end) :
                    if app_space[3] >= j_end :  
                        temp_index = 0
                        added = False 
                        for i in app_list : 
                            temp_app = index_range_list[i] 
                            if temp_app[3] > app_space[3] :    
                                app_list.insert(temp_index, idx)
                                added = True 
                                break
                            temp_index += 1 
                        if added == False :
                            app_list.append(idx)
                idx += 1 
        else :  # BOTTOM
            idx = 0
            for app_space in index_range_list :
                # find app on right
                if (app_space[1] >= i_begin and app_space[1] <= i_end) or (app_space[2] >= i_begin and app_space[2] >= i_end) :
                    if app_space[4] <= j_begin :  
                        temp_index = 0
                        added = False 
                        for i in app_list : 
                            temp_app = index_range_list[i] 
                            if temp_app[4] < app_space[4] :    
                                app_list.insert(temp_index, idx)
                                added = True 
                                break
                            temp_index += 1 
                        if added == False :
                            app_list.append(idx)
                idx += 1 

        if len(app_list) > 0 : 
            idx = app_list[0]
            app_space =  index_range_list[idx]
            print app_space 
            return app_space[0]
            
        del index_range_list
        del app_list
        return None

    def shove(self, app, windows):
        minW = app.right - app.left
        minH = app.top - app.bottom
        for space in windows :
            width = space.right - space.left
            height = space.top - space.bottom
            if minW > width : 
                minW = width 
            if minH > height :
                minH = height

        index_range_list = []
        maxRows = 0
        maxCols = 0 
        for space in windows :
            i_begin = space.left / minW  
            i_end = space.right / minW  
            j_begin = space.bottom / minH  
            j_end = space.top / minH  
            if i_end > maxCols :  
                maxCols = i_end
            if j_end > maxRows :  
                maxRows = j_end
            l = [space.getId(), i_begin, i_end, j_begin, j_end]
            #space.setDynamicIndex(i_begin, j_begin)
            index_range_list.append(l)

        # sorting
        index_list = []
        for app_space in index_range_list :
            app_idx = app_space[1] * maxCols + app_space[3] 
            added = False
            idx = 0 
            for w in index_list : 
                if w[0] > app_idx :
                    l = [app_idx, app_space[0], app_space[1], app_space[2], app_space[3], app_space[4]]
                    index_list.insert(idx, l)
                    added = True 
                    break
                idx += 1 
            if added == False:
                l = [app_idx, app_space[0], app_space[1], app_space[2], app_space[3], app_space[4]]
                index_list.append(l)
     
        for app_space in index_range_list :
            del app_space
        del index_range_list 
             
        print "sorted ... result"
        for app_space in index_list :
            print app_space

        app_i_begin = app.left / minW  
        app_i_end = app.right / minW  
        app_j_begin = app.bottom / minH  
        app_j_end = app.top / minH  
        wId = app.getId()
        left_list = [] 
        right_list = [] 
        top_list = [] 
        bottom_list = [] 
        for app_space in index_list :
            if app_space[1] == wId :
                continue
            if app_j_begin >= app_space[5] : # dowm
                bottom_list.append(app_space)
            elif app_j_end <= app_space[4] : # up
                top_list.append(app_space)
            else : 
                if app_i_begin >= app_space[3] : # left
                    # sorting... 
                    idx = 0
                    i = app_space[2]
                    print app_space
                    added = False
                    for ileft in left_list : 
                        if ileft[2] > i : 
                            left_list.insert(idx, app_space) 
                            added = True
                            break
                        idx += 1 
                    if added == False :
                        left_list.append(app_space)
                else :
                    idx = 0
                    i = app_space[3]
                    added = False
                    print app_space
                    for iright in right_list : 
                        if iright[3] < i : 
                            right_list.insert(idx, app_space) 
                            added = True
                            break
                        idx += 1 
                    if added == False :
                        right_list.append(app_space)

        print "left:"
        for app_space in left_list :
            print app_space
        print "right:"
        for app_space in right_list :
            print app_space
        print "bottom:"
        for app_space in bottom_list :
            print app_space
        print "top:"
        for app_space in top_list :
            print app_space

        self.clearRectangles()
        # run for the bottom 
        for app_space in bottom_list :
            wId = app_space[1]
            w = self.__getWindow(wId, windows)
            space = self.__getBottomSpace(w)
            if space : 
                height = w.top - w.bottom
                w.bottom = space.bottom
                w.top = w.bottom + height 
                w.resizeWindow(w.left, w.right, w.bottom, w.top)
            self.__addFullRectangle(w.getId(), Bounds(w.left, w.right, w.top, w.bottom))

        # run for the top 
        max = len(top_list)
        idx = max -1
        for i in range(max) : 
            app_space = top_list[idx] 
            wId = app_space[1]
            w = self.__getWindow(wId, windows)
            space = self.__getTopSpace(w)
            if space : 
                height = w.top - w.bottom
                w.top = space.top
                w.bottom = w.top - height
                w.resizeWindow(w.left, w.right, w.bottom, w.top)
            self.__addFullRectangle(w.getId(), Bounds(w.left, w.right, w.top, w.bottom))
            idx -= 1

        # run for the left 
        for app_space in left_list :
            wId = app_space[1]
            w = self.__getWindow(wId, windows)
            space = self.__getLeftSpace(w)
            if space : 
                width = w.right - w.left
                w.left = space.left
                w.right = w.left + width 
                w.resizeWindow(w.left, w.right, w.bottom, w.top)
            self.__addFullRectangle(w.getId(), Bounds(w.left, w.right, w.top, w.bottom))

        # run for the right 
        for app_space in right_list :
            wId = app_space[1]
            w = self.__getWindow(wId, windows)
            space = self.__getRightSpace(w)
            if space : 
                width = w.right - w.left
                w.right = space.right
                w.left = w.right - width 
                w.resizeWindow(w.left, w.right, w.bottom, w.top)
            self.__addFullRectangle(w.getId(), Bounds(w.left, w.right, w.top, w.bottom))

        del top_list
        del bottom_list
        del left_list
        del right_list
        del index_list

        self.searchExpandRectangle(app)  

    def runSort(self, windows, moveObj):
        minW = 999999
        minH = 999999
        for space in windows :
            width = space.right - space.left
            height = space.top - space.bottom
            if minW > width : 
                minW = width 
            if minH > height :
                minH = height

        index_range_list = []
        maxRows = 0
        maxCols = 0 
        for space in windows :
            if space == moveObj : continue
            i_begin = space.left / minW  
            i_end = space.right / minW  
            j_begin = space.bottom / minH  
            j_end = space.top / minH  
            if i_end > maxCols :  
                maxCols = i_end
            if j_end > maxRows :  
                maxRows = j_end
            l = [space.getId(), i_begin, i_end, j_begin, j_end]
            #space.setDynamicIndex(i_begin, j_begin)
            index_range_list.append(l)

        # sorting
        index_list = []
        for app_space in index_range_list :
            app_idx = app_space[1] * maxCols + app_space[3] 
            added = False
            idx = 0 
            for w in index_list : 
                if w[0] > app_idx :
                    l = [app_idx, app_space[0], app_space[1], app_space[2], app_space[3], app_space[4]]
                    index_list.insert(idx, l)
                    added = True 
                    break
                idx += 1 
            if added == False:
                l = [app_idx, app_space[0], app_space[1], app_space[2], app_space[3], app_space[4]]
                index_list.append(l)
     
        for app_space in index_range_list :
            del app_space
        del index_range_list 
             
        if len(index_list) > 0 : 
            app_space = index_list[0]
            return app_space[1] 

        del index_list 
        return -1


    def __getBottomSpace(self, app) :
        # find space, it includes me, and lowest one
        low_y = app.bottom 
        retObj = None
        for space in self.largestEmptySpaceList :
            if not (space.left <= app.left and app.right <= space.right and space.bottom <= app.bottom and app.top <= space.top) :
                continue
            if low_y > space.bottom : 
                low_y = space.bottom 
                retObj = space 
        if retObj == None :
            for space in self.largestEmptySpaceList :
                if not (space.bottom < app.bottom and app.top < space.top) :
                    continue
                if low_y > space.bottom : 
                    low_y = space.bottom 
                    retObj = space 
        return retObj

    def __getTopSpace(self, app) :
        # find space, it includes me, and lowest one
        top_y = app.top
        retObj = None
        for space in self.largestEmptySpaceList :
            if not (space.left <= app.left and app.right <= space.right and space.bottom <= app.bottom and app.top <= space.top) :
                continue
            if top_y < space.top : 
                top_y = space.top 
                retObj = space 
        if retObj == None :
            for space in self.largestEmptySpaceList :
                if not (space.bottom < app.bottom and app.top < space.top) :
                    continue
                if top_y < space.top: 
                    top_y = space.top
                    retObj = space 
        return retObj

    def __getLeftSpace(self, app):
        # find space, it includes me, and lowest one
        left_x = app.left
        retObj = None
        for space in self.largestEmptySpaceList :
            if not (space.left <= app.left and app.right <= space.right and space.bottom <= app.bottom and app.top <= space.top) :
                continue
            if left_x > space.left : 
                left_x = space.left 
                retObj = space 
        if retObj == None :
            for space in self.largestEmptySpaceList :
                if not (space.left < app.left and app.right < space.right):
                    continue
                if left_x > space.left: 
                    left_x = space.left
                    retObj = space 
        return retObj

    def __getRightSpace(self, app):
        # find space, it includes me, and lowest one
        right_x = app.right
        retObj = None
        for space in self.largestEmptySpaceList :
            if not (space.left <= app.left and app.right <= space.right and space.bottom <= app.bottom and app.top <= space.top) :
                continue
            if right_x < space.right : 
                right_x = space.right 
                retObj = space 
        if retObj == None :
            for space in self.largestEmptySpaceList :
               if not (space.left < app.left and app.right < space.right):
                   continue
               if right_x > space.right: 
                   right_x = space.right
                   retObj = space 
        return retObj


    def __getWindow(self, wId, windows):
        for w in windows : 
            if wId == w.getId() : 
                return w    
        return None

