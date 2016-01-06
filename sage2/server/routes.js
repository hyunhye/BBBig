
/**
 * Created by Minhaj on 6/20/15.
 */

var tesseract = require('node-tesseract');
var multer  = require('multer');
var fs = require('fs');
var path = path = require('path');
var imageDir = 'C:/Users/Administrator/Documents/BBBig/sage2/public_HTTPS/uploads/assets/';


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
            // console.log(files[i])
            // imageLists += '<li><a href="/?image=' + files[i] + '">' + files[i] + '</li>';
        }
       
    });


   /* fs.readFile('image.jpg', function (err, data) {
        if (err) throw err;
        process1()
    });*/


    app.post("/api/ocr", process);

};

//get the list of jpg files in the image dir
function getImages(imageDir, callback) {
    var fileType = '.jpg',
        files = [], i;

    fs.readdir(imageDir, function (err, list) {

        for(i=0; i<list.length; i++) {
            if(path.extname(list[i]) === fileType) {
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
                if (err){
                    res.json(500, "Error while scanning image");
                }
                console.log('successfully deleted %s', path);
            });

            console.log(text)
        }
    });
};

/**
 * Following steps done under this functions.
 *
 * 1. Uploads image under '.tmp' folder.
 * 2. Grab text from image using 'tesseract-ocr'.
 * 3. Delete image from hardisk.
 * 4. Return text in json format.
 *
 * @param req
 * @param res
 */
var process = function(req, res) {

    var path = req.files.file.path;

    // Recognize text of any language in any format
    tesseract.process(path,function(err, text) {
        if(err) {
            console.error(err);
        } else {
            fs.unlink(path, function (err) {
                if (err){
                    res.json(500, "Error while scanning image");
                }
                console.log('successfully deleted %s', path);
            });

            res.json(200, text);
        }
    });
};