/**
 * Created by Minhaj on 6/20/15.
 */

module.exports = function(){
	var express = require('express')
		,app = express();

	app.use(express.static('public'));

	// logs every request
	app.use(function(req, res, next){
		// output every request in the array
		console.log({method:req.method, url: req.url, device: req.device});

		// goes onto the next function in line
		next();
	});
	require('./routes')(app);
};
