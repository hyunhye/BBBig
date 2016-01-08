/**
 * Created by Minhaj on 6/20/15.
 *
 * Following steps done under this functions.
 *
 * 1. Uploads image under 'images' folder.
 * 2. Grab text from image using 'tesseract-ocr'.
 * 3. Return text in json format.
 *
 * @param req
 * @param res
 */
var tesseract = require('node-tesseract');
var multer  = require('multer');
var fs = require('fs');
var path = path = require('path');
var imageDir = 'C:/sage2/sage2/sage2/public_HTTPS/uploads/scanning/';

function ImageScanning(){
	this.scanningResult="";
}

ImageScanning.prototype.process = function(anAsset) {

    var path = imageDir+anAsset.exif.FileName;
    // Recognize text of any language in any format
    tesseract.process(path,function(err, text) {
        if(err) {
            console.error(err);
			//return "";
        } else {
			fs.unlink(path, function (err) {});
			this.scanningResult = text;
			//console.log("scanningResult: "+this.scanningResult);
			anAsset.exif.Text = this.scanningResult;
			//return this.scanningResult;
        }
    });
}

module.exports = ImageScanning;
