(function($) {
    var storage;
    storage = localStorage || {};
    return $.widget('ngn.inputHistory', {
        _create: function() {
            var s, _this = this;
            this.storageKey = 'inputHistory.' + this.element.attr('id');
            this.h0 = (s = storage[this.storageKey]) ? s.split('\n') : [];
            this.h = this.h0.concat(['']);
            this.i = this.h0.length;
            return this.element.keydown(function(e) {
				var key = e.which || e.keyCode; // keyCode detection
				var ctrl = e.ctrlKey ? e.ctrlKey : ((key === 17) ? true : false); // ctrl detection
                if (key == 13 && ctrl) {
                    return _this.ctrlenter();
                }else if (key == 13) {
                    return _this.enter();
                } else if (key == 38) {
                    return _this.up();
                } else if (key == 40) {
                    return _this.down();
			    }
            });
        },
        up: function() {
            if (this.i > 0) {
                this.h[this.i--] = this.element.val();
                this.element.val(this.h[this.i]);
            }
            this._trigger('up');
            return false;
        },
        down: function() {
            if (this.i < this.h0.length) {
                this.h[this.i++] = this.element.val();
                this.element.val(this.h[this.i]);
            }
            this._trigger('down');
            return false;
        },
        ctrlenter: function() {
            var v;
            v = this.element.val();
            if (v.length > 0 && v[0] != '{') {
				v = '{' + v;
			}
			if (v.length > 0 && v[v.length-1] != '}') {
				v += '}';
			}
			this.element.val(v);
			this._trigger('enter');
            return false;
        },
        enter: function() {
            var v;
            this._trigger('enter');
            if (this.i < this.h0.length) {
                this.h[this.i] = this.h0[this.i];
            }
            v = this.element.val();
            if (this.i >= 0 && this.i >= this.h0.length - 1 && this.h0[this.h0.length - 1] === v) {
                this.h[this.h0.length] = '';
            } else {
                this.h[this.h0.length] = v;
                this.h.push('');
                this.h0.push(v);
                storage[this.storageKey] = this.h0.join('\n');
            }
            this.i = this.h0.length;
        }
    });
}
)(jQuery);

$(document).ready(function() {
    $('input.maininput').focus();
    $('input.maininput').inputHistory();
    if (localStorage.length > 0) {
        $("#hdr tr").append("<td style='vertical-align:top'><img src='fhem/images/fhemSVG/checkbox_checked.svg' width='9' height='9' onclick='localStorage.removeItem(\"inputHistory.undefined\");$(this).hide()' style='cursor:pointer' alt='Historie l&ouml;schen' title='Historie l&ouml;schen'/></td>");
    }
});
