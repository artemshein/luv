(function () {
	if (!window.luv) window.luv = function () {};
	var luv = window.luv;

	luv.importScript = function(uri){
		document.write('<script src="' + uri +'" type="text/javascript"></script>\n');
	}

	luv.importScript('/js/luv/jquery-1.3.2.min.js');
	luv.importScript('/js/luv/data.js');
	luv.importScript('/js/luv/forms.js');
	luv.importScript('/js/luv/validators.js');
	luv.importScript('/js/luv/browsers.js');
	luv.importScript('/js/luv/jquery-ui-1.7.2.custom.min.js');
})();
