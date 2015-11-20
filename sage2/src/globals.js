function Bounds(left,right,up,bottom){
    this.left = left;
    this.right = right;
    this.up = up;
    this.bottom = bottom;
	this.width = this.right - this.left;
	this.height = this.bottom - this.up;
}


Bounds.prototype.setAll = function(left, right, up, bottom){
        this.left = left;
        this.right = right;
        this.up = up;
        this.bottom = bottom;
        this.setAspectRatio();
    }
	
Bounds.prototype.getAll = function(){
        return this.left, this.right, this.up, this.bottom;
    }

Bounds.prototype.getBound = function(){
        return this;
}
	
Bounds.prototype.getLeft = function(){
        return this.left;
    }
	
Bounds.prototype.getRight = function(){
        return this.right;
    }
Bounds.prototype.getBottom = function(){
        return this.bottom;
    }
Bounds.prototype.getUp = function(){
        return this.up;
    }
	
Bounds.prototype.setAspectRatio = function(){
    if (getHeight() != 0){
        this.aspectRatio = this.getWidth() / this.getHeight();
    }
    else{
        this.aspectRatio = 1.0;
    }
}

	
Bounds.prototype.getAspectRatio = function(){
            return this.aspectRatio;
}
	
Bounds.prototype.getCenterX  = function(){
            return this.right - (this.getWidth() / 2.0);
}
	
Bounds.prototype.getCenterY = function(){
            return this.up - (this.getHeight() / 2.0);
        }
	
Bounds.prototype.getWidth = function(){
	return this.right - this.left
}
	
Bounds.prototype.setWidth = function(w){
            this.right = this.left + w;
            this.setAspectRatio();
        }
	
Bounds.prototype.getHeight = function(){
	return this.up - this.bottom;
}
	
Bounds.prototype.setHeight = function(h){
            this.up = this.bottom + h;
            this.setAspectRatio();
        }
	
Bounds.prototype.setSize = function(w, h){
            this.setWidth(w);
            this.setHeight(h);
        }
	

Bounds.prototype.getX = function(){
            return this.left;
        }
	
Bounds.prototype.getY = function(){
            return this.bottom;
        }
	
Bounds.prototype.setPos = function(x, y){
            this.setX(x);
            this.setY(y);
        }
	       
Bounds.prototype.setX = function(x){
            var w = this.getWidth()
            this.left = x;
            this.right = x + w;
        }
	
Bounds.prototype.setY = function(y){
            var h = this.getHeight();
            this.bottom = y;
            this.up = y + h;
        }
	

Bounds.prototype.isIn = function(x, y){
            console.log("returns True if the (x,y) is in Bounds, False otherwise");
            if (this.left <= x && this.right >= x && this.bottom <= y && this.up >= y){
                return true;
            }
            else{
                return false;
            }
        }
	

Bounds.prototype.getArea = function(){
            return this.getWidth() * this.getHeight();
        }
	    
Bounds.prototype.eq = function(other){
            if(other == null){
                return false;
            }
            else{
                return (this.left == other.left && this.right == other.right &&  this.up == other.up && this.bottom == other.bottom)
            }
}

module.exports = Bounds;
//exports.getWidth = getWidth;
//exports.getHeight = getHeight;