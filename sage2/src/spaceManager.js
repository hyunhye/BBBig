var loadConfiguration = require('../server')
var Bounds = require('../src/globals');

function DynamicSpaceManager() {
	this.id;
	this.left;
	this.right;
	this.up;
	this.bottom;
	this.width;
	this.height;
    this.bound;
    this.fullSpaceList = [];
    this.largestEmptySpaceList = [];
}

// hyunhye : largest empty-space 초기화
DynamicSpaceManager.prototype.initializeEmptySpace = function(x,width,y,height){

	// largestEmptySpaceList에 넣기
	var bound = new Bounds(x,width,y,height);
	this.largestEmptySpaceList.push(bound);
	
}


DynamicSpaceManager.prototype.updateBound = function (bound) {
    this.bound = bound;
}

// -----------------------------------
// free type -> find space 
DynamicSpaceManager.prototype.createFullRectangle = function (app) {
    //print "CREATE FULL RECTANGLE... ... ... sail_id=" + str(app.getId())
    //print "app -> " + str(app.left) + " " + str(app.right) + " " + str(app.bottom) + " " + str(app.up)
	var item;
    var aspectRatio = app.width/app.height;
   
    var left = right = up = bottom = 0;
    var max_area = 0;
	var center_x = 0;
    var center_y = 0;
    var found = false;
   
	var space, a;
   
	var pos = 0;
   
    // because we are looking for best fit. largest area does not guarantee optimal choice
	if(this.largestEmptySpaceList.length == 0){
		
	}
    for(var i=0; i < this.largestEmptySpaceList.length; i++){ 
		// ratio = x / y    
		space = this.largestEmptySpaceList[i];

        // 윈도우 크기 => 비율에 맞춰 줄이기
        app_height = Math.ceil(space.width / aspectRatio);
        app_width = space.width;
      
        if (app_height > space.height) {  // 만약 윈도우 크기가 더 크면..
            app_height = space.height; // 윈도우 높이를 공간 높이로 바꾸고 
            app_width = Math.ceil(space.height * aspectRatio); // 윈도우 너비를 비율에 맞춰 바꾼다.
        }else if(app_width > space.width){
            app_width = space.width; 
            app_height = Math.ceil(space.width / aspectRatio); 
		}
		
      
        // 면적 = 윈도우 높이 * 윈도우 너비
        a = app_height * app_width;
        if (a > max_area) {// 만약 면적이 최대 면적보다 크면
            max_area = a; // 최대 면적을 현재 면적으로 늘린다.
			pos = i; // 현재 largestEmptySpaceList 체크
         
			center_x =space.right - Math.ceil(space.width/2); 
            center_y =space.bottom - Math.ceil(space.height/2);
			//center_x = space.width/2;
			//center_y = space.height/2;
			
            left = space.left;
            up = space.up;
			right = left + app_width;
            bottom = up + app_height;
        }
    }
   
    app.left = left;
    app.right = right ;
    app.up = up;
    app.bottom = bottom;
	
	var width = right - left;
	var height = bottom - up;
	
	app.left = center_x - Math.ceil(width / 2);
	app.right = center_x + Math.ceil(width/2);
	app.bottom = center_y + Math.ceil(height / 2);
	app.up = center_y - Math.ceil(height/2);
	if(app.left < 0) app.left = 0;
	if(app.up < 0) app.up = 0;
	
	this.bound = new Bounds(app.left,app.right,app.up,app.bottom);
    this.addFullRectangle(this.bound, pos);

   
	item = {id: app.id,left: app.left, up: app.up, bottom : app.bottom,right:app.right,width: app.right-app.left, height:app.bottom-app.up};
	return item;
}

// -----------------------------------
// MAIN PART : ADD FULL RECTANGLE
// hyunhye_addFullRectangle
DynamicSpaceManager.prototype.addFullRectangle = function (app, pos) {
	
	// 1. add fullSpaceList
    this.fullSpaceList.push(app);
	
    // 2. CList = have list existing rectangles in largestEmptySpaceList 
	//         		that intersect or are adjacent to current app
    var cList = [];
    var index = 0;
	
	for(var i=0, space; space=this.largestEmptySpaceList[i]; i++){	
	// !((space.right < app.left) && (space.left > app.right) && (space.up < app.bottom) && (space.bottom > app.up))	
	// if not (space.right < app.left or space.left > app.right or space.top < app.bottom or space.bottom > app.top)
		if((space.right < app.left || space.left > app.right || space.up > app.bottom || space.bottom < app.up) == false) {
			cList.push(space);
        }
        index += 1;
    }
    
    var adjacentLESList_left = [];
    var adjacentLESList_right = []
    var adjacentLESList_bottom = [];
    var adjacentLESList_up = [];
    var possibleLESList_left = [];
    var possibleLESList_right = [];
    var possibleLESList_bottom = [];
    var possibleLESList_up = [];
	
	for(var i=0, O; O=cList[i]; i++){
        // current app : app  = F
        // if O adjacent to any side e of F and external to F
        // ?????? correct or not????
        if (app.left == O.right){
            adjacentLESList_left.push(O);
		}
        else if (app.right ==  O.left){
            adjacentLESList_right.push(O);
		}
        else if (app.up == O.bottom){
            adjacentLESList_up.push(O);
		}
        else if (app.bottom == O.up){
			adjacentLESList_bottom.push(O);
		}
        else {
            // class Bounds - > left, right, up, bottom
            if (O.left < app.left){     // up left	
				if(app.left - O.left > 100){
					var bound = new Bounds(O.left, app.left, O.up, O.bottom);
					possibleLESList_left.push(bound);
				}
			}
            if (O.right > app.right){    
				if(O.right - app.right > 100){
					var bound = new Bounds(app.right, O.right, O.up, O.bottom);
					possibleLESList_right.push(bound);
				}
			}
            if (O.bottom > app.bottom){  // bottom left 
				if(O.bottom - app.bottom > 100){
					var bound = new Bounds(O.left, O.right, app.bottom, O.bottom);
					possibleLESList_bottom.push(bound);
				}
			}
            if (O.up < app.up) {        // up right 
				if( app.up - O.up > 100){
					var bound = new Bounds(O.left, O.right,O.up, app.up); // hyunhye : app.up, O.up순서 바꿈
					possibleLESList_up.push(bound);
				}
			
			}
			
			for(var j = 0; j < this.largestEmptySpaceList.length ; j++){
				if(j === pos){
					this.largestEmptySpaceList.splice(pos,1);
					break;
				}
			}
        }
    }
	
	// 3. P not enclosed by any space in adjacentLESList[D] or any other space in possibleLESList[D]
    index = 0;
    var possibleLESList = [];
	for(var i=0, P; P=possibleLESList_left[i]; i++){      
        if (this.isNotInClosed(P, index, possibleLESList_left, adjacentLESList_left) == true)
            possibleLESList.push(P);
        index += 1;
    }
	
    index = 0;
	for(var i=0, P; P=possibleLESList_right[i]; i++){
        if (this.isNotInClosed(P, index, possibleLESList_right, adjacentLESList_right) == true)
            possibleLESList.push(P);
        index += 1;
    }
	
    index = 0;
	for(var i=0, P; P=possibleLESList_up[i]; i++){
        if (this.isNotInClosed(P, index, possibleLESList_up, adjacentLESList_up) == true)
            possibleLESList.push(P)
        index += 1;
    }
	
    index = 0;
	for(var i=0, P; P=possibleLESList_bottom[i]; i++){
        if (this.isNotInClosed(P, index, possibleLESList_bottom, adjacentLESList_bottom) == true)
            possibleLESList.push(P)
        index += 1;
    }
	
	for(var i=0, P; P=possibleLESList[i]; i++){
		// load config file - looks for user defined file, then file that matches hostname, then uses default
		if(P.width < 200 || P.height < 200) continue; // if width, height is shorter than 100, continue
		this.largestEmptySpaceList.push(P);     
    }
}

DynamicSpaceManager.prototype.isInClosed = function (P, possibleLESList) {
    for (possible in possibleLESList)
        if (possible.left == P.left && P.right == possible.right && possible.bottom == P.bottom && P.up == possible.up)
            continue;
        else if (possible.left <= P.left && P.right <= possible.right && possible.bottom <= P.bottom && P.up <= possible.up)
            return true;
    return false;
}

DynamicSpaceManager.prototype.isNotInClosed = function (P, i, possibleLESList, adjacentLESList) {
    var j = 0;
	
	for(var n=0, possible; possible=possibleLESList[n]; n++){
        if (i != j) {
            if (possible.left <= P.left && P.right <= possible.right && possible.bottom <= P.bottom && P.up <= possible.up)
                return false;
        }
        j += 1;
    }
    if (adjacentLESList.length != 0) {
	   for(var n=0, adjacent; adjacent=adjacentLESList[n]; n++)
            if (adjacent.left <= P.left && P.right <= adjacent.right && adjacent.bottom <= P.bottom && P.up <= adjacent.up)
                return false;
    }
    return true;
}

// ******************** get Space ******************** //
DynamicSpaceManager.prototype.getBottomSpace = function (app) {
    // find space, it includes me, && lowest one
    var low_y = app.bottom;
    var retObj = null;
    for (space in this.largestEmptySpaceList) {
        if (!(space.left <= app.left && app.right <= space.right && space.bottom <= app.bottom && app.up <= space.up)) {
            continue;
        }
        if (low_y > space.bottom) {
            low_y = space.bottom;
            retObj = space;
        }
    }
    if (retObj == null) {
        for (space in this.largestEmptySpaceList) {
            if (!(space.bottom < app.bottom && app.up < space.up)) {
                continue;
            }
            if (low_y > space.bottom) {
                low_y = space.bottom;
                retObj = space;
            }
        }
    }
    return retObj;
}
DynamicSpaceManager.prototype.getupSpace = function (app) {
    // find space, it includes me, && lowest one
    var up_y = app.up;
    var retObj = null;
    for (space in this.largestEmptySpaceList) {
        if (!(space.left <= app.left && app.right <= space.right && space.bottom <= app.bottom && app.up <= space.up)) {
            continue;
        }
        if (up_y < space.up) {
            up_y = space.up;
            retObj = space;
        }
    }
    if (retObj == null) {
        for (space in this.largestEmptySpaceList) {
            if (!(space.bottom < app.bottom && app.up < space.up)) {
                continue;
            }
            if (up_y > space.up) {
                up_y = space.up;
                retObj = space;
            }
        }
    }
    return retObj;
}
DynamicSpaceManager.prototype.getLeftSpace = function (app) {
    // find space, it includes me, && lowest one
    var left_x = app.left;
    var retObj = null;
    for (space in this.largestEmptySpaceList) {
        if (!(space.left <= app.left && app.right <= space.right && space.bottom <= app.bottom && app.up <= space.up)) {
            continue;
        }
        if (left_x > space.left) {
            left_x = space.left;
            retObj = space;
        }
    }
    if (retObj == null) {
        for (space in this.largestEmptySpaceList) {
            if (!(space.left < app.left && app.right < space.right)) {
                continue;
            }
            if (left_x > space.left) {
                left_x = space.left;
                retObj = space;
            }
        }
    }
    return retObj;
}

DynamicSpaceManager.prototype.getRightSpace = function (app) {
    // find space, it includes me, && lowest one
    var right_x = app.right;
    var retObj = null;
    for (space in this.largestEmptySpaceList) {
        if (!(space.left <= app.left && app.right <= space.right && space.bottom <= app.bottom && app.up <= space.up)) {
            continue;
        }
        if (right_x < space.right) {
            right_x = space.right;
            retObj = space;
        }
    }
    if (retObj == null) {
        for (space in this.largestEmptySpaceList) {
            if (!(space.left < app.left && app.right < space.right)) {
                continue;
            }
            if (right_x > space.right) {
                right_x = space.right;
                retObj = space;
            }
        }
    }
    return retObj;
}

DynamicSpaceManager.prototype.getWindow = function (wId, windows) {
    for (w in windows) {
        if (wId == w.id) // hyunhye : w.getId()
            return w;
    }
    return null;
}

module.exports = DynamicSpaceManager;
