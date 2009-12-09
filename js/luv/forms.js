(function () {
	if (!window.luv) window.luv = function () {};
	var luv = window.luv;

	jQuery.fn.fieldRawVal = function (value)
	{
		if (value)
			return this.val(value);
		if (this.is(":checkbox"))
			return this.attr("checked")? this.val() : null;
		else
			return this.val();
	};
	jQuery.fn.showErrors = function (errors)
	{
		this.addClass("error");
		$.each(errors, function (i, error) { alert(error); });
	};
	jQuery.fn.fieldVal = function (value)
	{
		if (value)
			return this.val(value);
		if (this.is("select"))
			return this.find("option:selected").text();
		else
			return this.val();
	};
	jQuery.fn.ajaxField = function (url, id, field, callback)
	{
		var self = this;
		this.addClass("ajax");
		function commitChanges () {
			var currentValue = self.fieldRawVal();
			if (currentValue != self.data("lastValue"))
			{
				jQuery.ajax({cache: false, data: {value: currentValue, id: id, field: field, set: "Set"}, dataType: "json", type: "post", url: url,
				success: function (data, textStatus) {
					if (data.status == "error")
					{
						self.showErrors(data.errors);
						if (!self.fieldVal())
							self.fieldVal(self.data("lastValue")).focus().select();
					}
					else
					{
						self.data("lastValue", currentValue);
						self.removeClass("error");
						if (callback)
							callback(self, field, currentValue);
					}
				},
				error: function (request, textStatus, errorThrown) {
					self.addClass("error", 500);
				}});
			}
			else
			{
				self.removeClass("error");
				if (callback)
					callback(self, field, currentValue);
			}
		}
		this.data("lastValue", this.fieldRawVal());
		if (this.is(":checkbox"))
			this.change(commitChanges).change();
		else if (this.hasClass("hasDatepicker"))
			this.change(commitChanges).addClass("ajax");
		else
			this.blur(commitChanges).keypress(function (e) {
				if (e.which == 13)
					commitChanges();
			}).blur();
		return this;
	};
	jQuery.fn.inlineEditAjaxField = function (url, id, field, callback)
	{
		function setValue (self, val)
		{
			self.text(val);
			if (val)
				self.removeClass("emptyInlineEditValue");
			else
				self.addClass("emptyInlineEditValue");
		}
		var value = jQuery("#"+this.attr("id")+"Value").addClass("inlineEditValue");
		var self = this;
		var newCallback = function (self, field, currentValue) {
			if (!callback || callback(self, field, currentValue))
			{
				self.hide();
				setValue(value, self.fieldVal());
				value.show();
			}
		}
		this.ajaxField(url, id, field, newCallback);
		setValue(value, self.fieldVal());
		value.click(function () {
			value.hide();
			self.show().focus().select();
		});
		this.hide();
	};
	jQuery.fn.hideError = function ()
	{
		this.removeClass("error");
	};
	jQuery.fn.showError = function (err)
	{
		this.addClass("error").focus();
		alert(err);
	};

	luv.inArray = function (value, array)
	{
		for (var val in array)
			if (value == array[val])
				return true;
		return false;
	}
	luv.equalArrays = function (arr1, arr2)
	{
		if (!arr1) arr1 = [];
		if (!arr2) arr2 = [];
		if (!arr1 && !arr2) return true;
		if (arr1.length != arr2.length) return false;
		for (var el in arr1)
			if (!luv.inArray(arr1[el], arr2))
				return false;
		return true;
	}
	luv.clearForm = function (id)
	{
		var form = $('#'+id);
		form.find('input[type!="submit"][type!="button"][type!="checkbox"][name!="signature"]').val('');
		form.find('textarea').val('');
		form.find('input[type="checkbox"]').removeAttr('checked');
		form.find('select option').removeAttr('selected');
		form.find('select').val(''); // Dumbas IE
	}
	luv.isFormFilled = function (form, exclude) {
		if (!exclude) exclude = [];
		exclude.push('signature');
		var len = $('#'+form+' input[name][type!="checkbox"][type!="submit"][type!="button"], #'+form+' textarea[name]').filter(function () {
			return !luv.inArray($(this).attr('name'), exclude) && $(this).val();
		}).length;
		len += $('#'+form+' input[name][type="checkbox"][checked]').filter(function () {
			alert($(this).attr('name'));
			return !luv.inArray($(this).attr('name'), exclude);
		}).length;
		return len != 0;
	}
	luv.isEqualValues = function (field, value)
	{
		var fieldVal = field.val();
		var valueOrigin = value;
		if (field.attr('type') == 'checkbox') fieldVal = field.attr('checked')? '1' : '0';
		if (typeof value == 'number') value = value+'';
		if (fieldVal == '') fieldVal = null;
		if (value == '') value = null;
		if (fieldVal == value)
			return true;
		if (typeof fieldVal == 'object' && typeof value == 'object')
			return luv.equalArrays(fieldVal, value);
		else if (typeof fieldVal == 'string' && (fieldVal.replace(/\n/g, "\r\n") == value))
			return true;
		return false;
	}
	luv.isFormChanged = function (form, values)
	{
		var result = $('#'+form+' input[name][name!="signature"][type!="submit"][type!="button"]').filter(function (index) {
			return !luv.isEqualValues($(this), values[$(this).attr('name')]);
		}).length != 0
		|| $('#'+form+' textarea[name]').filter(function (index) {
			return !luv.isEqualValues($(this), values[$(this).attr('name')]);
		}).length != 0
		|| $('#'+form+' select[name]').filter(function (index) {
			return !luv.isEqualValues($(this), values[$(this).attr('name').replace(/\[\]$/, '')]);
		}).length != 0;
		return result;
	}
	luv.fillForm = function (form, values)
	{
		luv.clearForm(form);
		$.each(values, function (key, value) {
			if (value && typeof value == 'object' && $('#'+form+' select[name="'+key+'"]'))
			{
				$('#'+form+' select[name="'+key+'"] option[value]').each(function (){
					if (luv.inArray($(this).val(), value))
						$(this).attr('selected', 'selected');
					else
						$(this).removeAttr('selected');
				});
			}
			else
			{
				//  BUG! if (value && typeof value == 'object')
				//	value = value.id;
				var el = $('#'+form+' [name="'+key+'"]');
				if (el.attr('type') == 'checkbox')
				{
					if (value && value != 0)
						el.attr('checked', 'checked');
					else
						el.removeAttr('checked');
				}
				else
				{
					//if (!value) value = '';
					el.val(value);
				}
			}
		});
	}
	luv.ajaxFieldValues = [];
	luv.ajaxFieldShowForm = function (id)
	{
		$('#'+id+'_value').hide();
		$('#'+id+'_form').show();
		$('#'+id+'_field').focus();
	}
	luv.getFieldValue = function (id)
	{
		var el = $('#'+id);
		var tag = el.get(0).tagName;
		if (tag == 'SELECT')
			return el.find("[selected]").text();
		else if (tag == 'INPUT' && el.attr('type') == 'checkbox')
			return el.attr('checked');
		return el.val();
	}
	luv.getFieldRawValue = function (id)
	{
		var el = $('#'+id);
		if (el.get(0))
		{
			var tag = el.get(0).tagName;
			if (tag == 'INPUT' && el.attr('type') == 'checkbox')
				return el.attr('checked');
		}
		return el.val();
	}
	luv.setFieldValue = function (id, value)
	{
		var el = $('#'+id);
		var tag = el.get(0).tagName;
		if (tag == 'SELECT')
		{
			el.find().removeAttr('selected');
			el.find('[value="'+value+'"]').attr('selected', 'selected');
		}
		else if (tag == 'INPUT' || tag == 'TEXTAREA')
			el.val(value);
	}
	luv.setFieldRawValue = function (id, value)
	{
		$('#'+id).val(value);
	}
	luv.ajaxFieldShowValue = function (id, action)
	{
		// If user change data, then query UPDATE
		var val = luv.getFieldRawValue(id+'_field');
		if (luv.ajaxFieldValues[id] != val)
		{
			$.post(action, { 'value': val }, function (data) {
				if (data)
					return showErrors(data);
				$('#'+id+'_form').hide();
				luv.setFieldRawValue(id+'_field', val);
				luv.ajaxFieldValues[id] = val;
				var value = luv.getFieldValue(id+'_field');
				if (value)
					$('#'+id+'_value').html(value).show();
				else
					$('#'+id+'_value').html('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;').show();
			});
		}
		else // Not changed data
		{
			hideErrors();
			$('#'+id+'_form').hide();
			var value = luv.getFieldValue(id+'_field');
			if (value)
			{
				$('#'+id+'_value').html(value).show();
			}
			else
				$('#'+id+'_value').html('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;').show();
		}
	}
	luv.enableFormFields = function (id)
	{
		$('#'+id+' input, #'+id+' textarea, #'+id+' select').removeAttr('disabled');
	}
	luv.disableFormFields = function (id)
	{
		$('#'+id+' input, #'+id+' textarea, #'+id+' select').attr('disabled', 'disabled');
	}
	luv.clearMultipleCheckboxes = function (id)
	{
		$('#'+id).find('input').removeAttr('checked');
	}
	luv.checkMultipleCheckboxes = function (id)
	{
		$('#'+id).find('input').attr('checked', 'checked');
	}
	luv.clearMultipleCheckboxesByName = function (name)
	{
		$('input[name="' + name + '"]').removeAttr('checked');
	}
	luv.checkMultipleCheckboxesByName = function (name)
	{
		$('input[name="' + name + '"]').attr('checked', 'checked');
	}
	luv.getFormValues = function (formId)
	{
		var result = {};
		var form = $('#'+formId);
		form.find('input[type!="button"][type!="submit"][type!="checkbox"], textarea, select[multiple!="multiple"]')
		.each(function(){ result[$(this).attr('name')] = $(this).val(); });
		form.find('select[multiple]').each(function(){ result[$(this).attr('name')] = $(this).val(); });
		form.find('input[type="checkbox"]:checked').each(function() {
			var name = $(this).attr('name');
			if (!result[name])
				result[name] = [];
			result[name].push($(this).val());
		});
		return result;
	}
	luv.sendForm = function (formId, buttonId, callback)
	{
		$('#' + formId + ' input[type="button"]').attr('disabled', 'disabled');
		$('#' + formId + ' input[type="submit"]').attr('disabled', 'disabled');
		var values = luv.getFormValues(formId);
		if (buttonId)
			values[$('#' + buttonId).attr('name')] = $('#' + buttonId).val();
		$.post(
			$('#' + formId).attr('action'),
			values,
			function (data, textStatus)
			{
				$('#' + formId + ' input[type="button"]').removeAttr('disabled');
				$('#' + formId + ' input[type="submit"]').removeAttr('disabled');
				(callback)(data, textStatus);
			}
		);
	}
	luv.testAndSendForm = function (formId, buttonId, callback)
	{
		var testFunc = 'isValid_' + formId;
		if (window[testFunc]())
			luv.sendForm(formId, buttonId, callback);
		return false;
	}
	// NestedSetSelect field widget
	luv.nestedSetFilter = function (fieldId, filter)
	{
		var html = '<option value=""></option>';
		$.each(nestedSetData[fieldId].data, function (key, value)
		{
			if (filter(key, value))
				html += '<option value="' + value.value + '">' + value.label + '</option>';
		});
		$('#' + fieldId).html(html);
	}
	luv.nestedSetGetParentFor = function (fieldId, id)
	{
		var val = nestedSetData[fieldId].data[id];
		var parentKey;
		$.each(nestedSetData[fieldId].data, function (key, value)
		{
			if (value.level == val.level-1 && value.left < val.left && value.right > val.right)
			{
				parentKey = key;
				return false;
			}
		});
		return parentKey;
	}
	luv.nestedSetSelect = function (fieldId, id)
	{
		if (id)
		{
			var val = nestedSetData[fieldId].data[id];
			if (!val.hasChildren)
				return;
			luv.nestedSetFilter(fieldId, function (key, value) { return value.left > val.left && value.right < val.right && value.level == val.level + 1; });
			var parentId = luv.nestedSetGetParentFor(fieldId, id);
			if (parentId)
				$('#' + fieldId + 'Back').html('<a href="#" onclick="luv.nestedSetSelect(\'' + fieldId + '\', \'' + parentId + '\'); return false;">&laquo; Назад</a>');
			else
				$('#' + fieldId + 'Back').html('<a href="#" onclick="luv.nestedSetSelect(\'' + fieldId + '\'); return false;">&laquo; Назад</a>');
		}
		else
		{
			luv.nestedSetFilter(fieldId, function (key, value) { return value.level == nestedSetData[fieldId].minLevel; });
			$('#' + fieldId + 'Back').html('');
		}
	}
})();
