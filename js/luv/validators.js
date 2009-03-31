(function () {
	if (!window.luv) window.luv = function () {};
	var luv = window.luv;

	luv.valErrorMsg = function (id, msg)
	{
		var field = $('#'+id);
		alert('Поле "'+$('label[for='+id+']').text()+'" '+msg);
		field.addClass('error');
		field.focus();
		return false;
	}

	luv.filledVal = function (id)
	{
		field = $('#'+id);
		if (field.get(0).tagName == 'DIV') // Multiple checkboxes
		{
			field.children('input').removeClass('error');
			if (field.children('input[checked]').length) return true;
			alert('Поле "'+$('label[for='+id+']').text()+'" должно быть заполнено!');
			field.children('input').addClass('error');
		}
		else // Other
		{
			field.removeClass('error');
			if (field.val() && field.val().length != 0) return true;
			alert('Поле "'+$('label[for='+id+']').text()+'" должно быть заполнено!');
			field.addClass('error');
			field.focus();
		}
		return false;
	}

	luv.lengthVal = function (id, maxlen, minlen)
	{
		id = $('#'+id);
		id.removeClass('error');
		if (!maxlen  || (!id.val() || id.val().length <= maxlen))
		{
			if (!minlen || (!id.val() || id.val().length >= minlen)) return true;
		}
		id.focus();
		id.addClass('error');
		alert('Значение поля "'+$('label[for="'+id.attr('id')+'"]').text()+'" не может превышать '+maxlen+' символов'+(minlen? (' или быть короче '+minlen+' символов') : '')+'!');
		return false;
	}

	luv.valueVal = function (id, value)
	{
		id = $('#'+id).removeClass('error');
		if (typeof value == 'object')
		{
			for(var i = 0; i < value.length; i++)
			{
				if (id.val() == value[i]) return true;
			}
		}
		else
		{
			if (id.val() && id.val() == value) return true;
		}
		id.focus().addClass('error');
		if (typeof value == 'object')
		{
			var values = '';
			for(var i = 0; i < value.length; i++)
			{
				if (i!=0) values += ', ';
				values += value[i];
			}
			alert('Значение поля "'+$('label[for="'+id.attr('id')+'"]').text()+'" должно быть одним из: '+values+', а не '+id.val()+'!');
		}
		else
		{
			alert('Значение поля "'+$('label[for="'+id.attr('id')+'"]').text()+'" должно быть "'+value+'", а не '+id.val()+'!');
		}
		return false;
	}

	luv.regexpVal = function (id, regexp)
	{
		id = $('#'+id).removeClass('error');
		if (regexp.test(id.val())) return true;
		alert('Значение поля "'+$('label[for="'+id.attr('id')+'"]').text()+'" не соответствует требованиям!');
		id.focus().addClass('error');
		return false;
	}

	luv.ipVal = function (id)
	{
		alert('ipVal not implemented yet!');
		return false;
	}

	luv.urlVal = function (id)
	{
		var val = luv.getFieldRawValue(id);
		if (!val || /^((https?|ftp|gopher|telnet|file|notes|ms-help):((\/\/)|(\\\\))+[\w\d:#@%\/;$()~_?\+-=\\\.&]*)$/.test(val))
			return true;
		return luv.valErrorMsg(id, " должно быть правильным адресом!");
	}

	luv.emailVal = function (id)
	{
		var val = luv.getFieldRawValue(id);
		if (!val || /^[A-Za-z0-9._%+-]+@[A-Za-z0-9\.-]+\.[A-Za-z]{2,4}$/.test(val))
			return true;
		return luv.valErrorMsg(id, " должно быть правильным почтовым ящиком!");
	}

	luv.booleanVal = function (id)
	{
		return true; // FIXME
	}

	luv.intVal = function (id)
	{
		var val = luv.getFieldRawValue(id);
		if (!val || /^\-?[0-9]+$/.test(val))
			return true;
		return luv.valErrorMsg(id, " должно быть целым числом!");
	}

	luv.floatVal = function (id)
	{
		var val = luv.getFieldRawValue(id);
		if (!val || /^\-?[1-9][0-9]*(\.[0-9]*[eE]\-?[1-9][0-9]*)?$/.test(val))
			return true;
		return luv.valErrorMsg(id, " должно быть вещественным числом!");
	}
})();
