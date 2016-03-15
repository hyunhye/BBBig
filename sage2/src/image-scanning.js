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
    //this.decisionTree = decisionTree;
   this.scanningResult="";

}

ImageScanning.prototype.process = function(anAsset) {

    var path = imageDir+anAsset.exif.FileName;

    // Recognize text of any language in any format
    tesseract.process(path,function(err, text) {
        if(err) {
            console.error(err);
        } else {
            // extract text from image using tessearct image scanner
         fs.unlink(path, function (err) {});
         this.scanningResult = text;
         this.scanningResult = this.scanningResult.replace(/(^\s*)|(\s*$)/gi, ""); 
		 console.log("text : "+text);
		 console.log("this.scanningResult : "+ this.scanningResult);
        }
    });
}

ImageScanning.prototype.setResult = function(anAsset) {
   anAsset.exif.ScanningResult = this.scanningResult; // this.scanningResult를 못가져옴
}

ImageScanning.prototype.getResult = function() {
    return this.scanningResult;
}
module.exports = ImageScanning;