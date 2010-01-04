(function () {
	jQuery.fn.validFilled = function ()
	{
		this.hideError();
		if (this.fieldRawVal()) return true;
		return false;
	};
	jQuery.fn.validInt = function ()
	{
		this.hideError();
		if (!this.fieldRawVal() || /^\-?[0-9]+$/.test(this.fieldRawVal()))
			return true;
		return false;
	};
	jQuery.fn.validNonNegative = function ()
	{
		this.hideError();
		if (!this.fieldRawVal() || /^[0-9]+$/.test(this.fieldRawVal()))
			return true;
		return false;
	};
	jQuery.fn.validLength = function (minLen, maxLen)
	{
		this.hideError();
		var val = this.fieldRawVal();
		if ((!maxLen || !val || val.length <= maxLen)
		&& (!minLen || !val || val.length >= minLen))
			return true;
		return false;
	};
	jQuery.fn.validIntValueRange = function (minVal, maxVal)
	{
		// TODO
		return true;
	};
	jQuery.fn.validRegexp = function (regexp)
	{
		// TODO
		return true;
	};
})();
