
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
var imageDir = 'C:/Users/Administrator/Documents/BBBig/sage2/public_HTTPS/uploads/scanning/';


module.exports = function(app) {
    app.use(multer(
        {
            dest: 'C:/Users/Administrator/Documents/BBBig',
            inMemory: false
        }
    ));

    getImages(imageDir, function (err, files) {

        for (var i=0; i<files.length; i++) {
            var result = process1(files[i]);
        }  
    });

};

//get the list of jpg files in the image dir
function getImages(imageDir, callback) {
    var JPG = '.jpg',PNG = '.png',GIF='.gif',JPEG='.jpeg',
        files = [], i;

    fs.readdir(imageDir, function (err, list) {

        for(i=0; i<list.length; i++) {
            if(path.extname(list[i]) === JPG) {
                files.push(list[i]); //store the file name into the array files
            }else if(path.extname(list[i]) === PNG){
				files.push(list[i]); //store the file name into the array files
			}else if(path.extname(list[i]) === GIF){
				files.push(list[i]); //store the file name into the array files
			}else if(path.extname(list[i]) === JPEG){
				files.push(list[i]); //store the file name into the array files
			}
        }
        callback(err, files);
    });
}

var process1 = function(req) {

    var path = imageDir+req;

    // Recognize text of any language in any format
    tesseract.process(path,function(err, text) {
        if(err) {
            console.error(err);
        } else {
			fs.unlink(path, function (err) {
                console.log('successfully deleted %s', path);
            });
            console.log(text)
        }
    });
};

var process = function(req, res) {

    var path = req.files.file.path;

    // Recognize text of any language in any format
    tesseract.process(path,function(err, text) {
        if(err) {
            console.error(err);
        } else {
			
            res.json(200, text);
        }
    });
};