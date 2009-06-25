(function () {
	if (!window.luv) window.luv = function () {};
	var luv = window.luv;

	luv.pagesNav = function (pages, page, func)
	{
		if (pages == 1) return '';
		var htmlCodePages = '<div class="pages">';
		for (var i = 1; i < pages; ++i)
		{
			if (i == page)
				htmlCodePages += '<span>'+i+'</span>';
			else
				htmlCodePages += '<a href="javascript:void(0)" onclick="'+func+'('+i+')">'+i+'</a>';
		}
		htmlCodePages += '</div>';
		return htmlCodePages;
	}
	jQuery.cookie = function (name, value, expiresSeconds)
	{
		if (value)
		{
			var expires;
			if (expiresSeconds) {
				var date = new Date();
				date.setTime(date.getTime()+(expiresSeconds*1000));
				expires = "; expires="+date.toGMTString();
			}
			else
				expires = "";
			document.cookie = name+"="+value+expires+"; path=/";
		}
		else
		{
			var nameEQ = name + "=";
			var ca = document.cookie.split(';');
			for(var i=0;i < ca.length;i++) {
				var c = ca[i];
				while (c.charAt(0)==' ') c = c.substring(1,c.length);
				if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
			}
			return null;
		}
	}
	luv.fromJSON = function (str) { return eval('(' + str + ')'); }
})();
